import 'dart:async';

import 'package:drift/drift.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:uuid/uuid.dart';

import '../api/family_api.dart';
import '../payload/event_payload.dart';
import '../payload/payload.dart';
import '../store/databases.dart';

/// Audience groups created with the family (crypto doc §3).
const allGroup = 'all';
const adultsGroup = 'adults';

/// Every group is at epoch 0 until key rotation exists (crypto doc §9).
const currentEpoch = 0;

/// Object kinds, mirroring the backend's append-only ObjectKind.
enum ObjectKind {
  event(1, 'event'),
  memberProfile(14, 'member_profile'),
  eventException(15, 'event_exception');

  const ObjectKind(this.wire, this.slotType);

  /// The backend's enum value.
  final int wire;

  /// The object type bound into each envelope's slot (crypto doc §4).
  final String slotType;

  static ObjectKind? fromWire(int wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// What one [FamilyStore.sync] did.
class SyncReport {
  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.rebased,
    required this.rejected,
  });

  final int pushed;
  final int pulled;

  /// Edits that lost a race and were resent on top of the newer version.
  final int rebased;

  /// Commands the server refused; kept in the queue for a person to see.
  final int rejected;
}

/// Local-first access to the family's content (architecture doc §7): reads
/// come from the encrypted cache, writes go to the command queue and show at
/// once, and [sync] exchanges both with the server.
class FamilyStore {
  FamilyStore({
    required this._cache,
    required this._queue,
    required this._api,
    required this.familyId,
    required this.deviceId,
    required this._keyring,
  });

  final CacheDatabase _cache;
  final QueueDatabase _queue;
  final FamilyApi _api;
  final Keyring Function() _keyring;
  final String familyId;
  final String deviceId;

  static const _uuid = Uuid();
  static const _cursorKey = 'cursor';

  String get _scope => 'family:$familyId';

  // ---- reads ----------------------------------------------------------------

  Stream<List<(String, EventPayload)>> watchEvents() => _watchReadable(
    ObjectKind.event,
  ).map((rows) => [for (final (id, p) in rows) (id, EventPayload.read(p))]);

  Stream<List<(String, EventExceptionPayload)>> watchExceptions() =>
      _watchReadable(ObjectKind.eventException).map(
        (rows) => [
          for (final (id, p) in rows) (id, EventExceptionPayload.read(p)),
        ],
      );

  Stream<List<(String, MemberProfile)>> watchProfiles() => _watchReadable(
    ObjectKind.memberProfile,
  ).map((rows) => [for (final (id, p) in rows) (id, MemberProfile.read(p))]);

  Stream<List<(String, Payload)>> _watchReadable(ObjectKind kind) {
    final query = _cache.select(_cache.cachedObjects)
      ..where(
        (o) =>
            o.kind.equals(kind.wire) &
            o.deleted.equals(false) &
            o.payload.isNotNull(),
      );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          if (_tryDecode(row.payload!) case final payload?) (row.id, payload),
      ],
    );
  }

  /// Objects this device holds but can't open, by reason. A non-zero
  /// `noAccess` count on a parent's device means a grant is missing.
  Future<Map<String, int>> unreadableCounts() async {
    final rows = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.unreadable.isNotNull())).get();
    final counts = <String, int>{};
    for (final r in rows) {
      counts.update(r.unreadable!, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  // ---- writes ---------------------------------------------------------------

  /// Creates or edits an event; returns its id. Parents-only events are sealed
  /// to `adults` alone, so child devices never receive a readable copy.
  Future<String> saveEvent(EventPayload event, {String? id}) {
    final audience = event.visibility == EventVisibility.parentsOnly
        ? adultsGroup
        : allGroup;
    return _put(ObjectKind.event, id, event.payload, [audience]);
  }

  /// Cancels, moves or changes one occurrence; returns the exception's id.
  /// Sealed to the same audience as its event ([visibility]), so a
  /// parents-only event's exceptions stay parents-only too.
  Future<String> saveException(
    EventExceptionPayload exception, {
    required EventVisibility visibility,
  }) => _put(
    ObjectKind.eventException,
    EventExceptionPayload.idFor(exception.eventId, exception.originalStart!),
    exception.payload,
    [visibility == EventVisibility.parentsOnly ? adultsGroup : allGroup],
  );

  /// Deletes an event and every exception to it this device can read, so
  /// none are left behind pointing at nothing.
  Future<void> deleteEvent(String id) async {
    final exceptions = await watchExceptions().first;
    for (final (exceptionId, e) in exceptions) {
      if (e.eventId == id) await delete(ObjectKind.eventException, exceptionId);
    }
    await delete(ObjectKind.event, id);
  }

  /// Writes a member's profile, keyed by their member id.
  Future<void> saveProfile(String memberId, MemberProfile profile) =>
      _put(ObjectKind.memberProfile, memberId, profile.payload, [allGroup]);

  /// The stored payload of an object, to edit it without losing fields this
  /// client doesn't know (crypto doc §5 rule 2).
  Future<Payload?> payloadOf(String id) async {
    final row = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    return row?.payload == null ? null : _tryDecode(row!.payload!);
  }

  Future<void> delete(ObjectKind kind, String id) async {
    await _enqueue(
      type: 'object.delete',
      kind: kind,
      id: id,
      envelope: Uint8List(0),
    );
    await (_cache.update(_cache.cachedObjects)..where((o) => o.id.equals(id)))
        .write(const CachedObjectsCompanion(deleted: Value(true)));
  }

  Future<String> _put(
    ObjectKind kind,
    String? id,
    Payload payload,
    List<String> groups,
  ) async {
    final objectId = id ?? _uuid.v4();
    final bytes = payload.encode();
    final envelope = seal(
      payload: bytes,
      object: ObjectSlot(
        objectType: kind.slotType,
        id: objectId,
        familyId: familyId,
      ),
      audiences: [
        for (final g in groups) Audience(group: g, epoch: currentEpoch),
      ],
      keyring: _keyring(),
    );

    await _enqueue(
      type: 'object.upsert',
      kind: kind,
      id: objectId,
      envelope: envelope,
    );
    // Shown at once: local-first.
    await _cache
        .into(_cache.cachedObjects)
        .insert(
          CachedObjectsCompanion.insert(
            id: objectId,
            kind: kind.wire,
            scope: _scope,
            version: 0,
            envelope: Value(envelope),
            payload: Value(bytes),
          ),
          onConflict: DoUpdate(
            (_) => CachedObjectsCompanion(
              envelope: Value(envelope),
              payload: Value(bytes),
              deleted: const Value(false),
              unreadable: const Value(null),
            ),
          ),
        );
    return objectId;
  }

  Future<void> _enqueue({
    required String type,
    required ObjectKind kind,
    required String id,
    required Uint8List envelope,
  }) async {
    await _queue.transaction(() async {
      await _queue
          .into(_queue.queuedCommands)
          .insert(
            QueuedCommandsCompanion.insert(
              clientCommandId: _uuid.v4(),
              type: type,
              targetId: id,
              targetKind: kind.wire,
              scope: _scope,
              envelope: envelope,
              expectedVersion: Value(await _expectedVersion(id)),
              issuedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  /// The version the server should hold when this write lands. Earlier writes
  /// to the same object still in the queue each add one, so a string of
  /// offline edits doesn't conflict with itself.
  Future<int?> _expectedVersion(String id) async {
    final row = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    final pending = await (_queue.select(
      _queue.queuedCommands,
    )..where((c) => c.targetId.equals(id) & c.state.equals('pending'))).get();
    final base = row?.version ?? 0;
    if (pending.isEmpty) return row == null || base == 0 ? null : base;
    return base + pending.length;
  }

  // ---- sync -----------------------------------------------------------------

  Future<SyncReport>? _syncing;

  /// Pushes queued writes, then pulls what changed. Concurrent calls share one
  /// run.
  Future<SyncReport> sync() {
    return _syncing ??= _sync(resendRebased: true)
        .whenComplete(() => _syncing = null);
  }

  Future<SyncReport> _sync({required bool resendRebased}) async {
    var pushed = 0;
    var rebased = 0;
    var rejected = 0;

    final queued =
        await (_queue.select(_queue.queuedCommands)
              ..where((c) => c.state.equals('pending'))
              ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
            .get();
    if (queued.isNotEmpty) {
      final results = await _api.submitCommands(
        asDevice: deviceId,
        commands: [
          for (final c in queued)
            OutgoingCommand(
              clientCommandId: c.clientCommandId,
              type: c.type,
              targetId: c.targetId,
              targetKind: c.targetKind,
              scope: c.scope,
              envelope: c.envelope,
              expectedVersion: c.expectedVersion,
              issuedAt: c.issuedAt,
            ),
        ],
      );
      for (final r in results) {
        final where = _queue.update(_queue.queuedCommands)
          ..where((c) => c.clientCommandId.equals(r.clientCommandId));
        switch (r.status) {
          case 'applied' || 'duplicate':
            await (_queue.delete(
              _queue.queuedCommands,
            )..where((c) => c.clientCommandId.equals(r.clientCommandId))).go();
            pushed++;
          case 'conflict':
            // Last writer wins, for now: whole-object upserts are rebased on
            // the server's version and resent. The server can't merge; a
            // field-level merge on the client can replace this later.
            await where.write(
              QueuedCommandsCompanion(
                expectedVersion: Value(r.sequence),
                attempts: const Value.absent(),
                lastError: Value('conflict at version ${r.sequence}'),
              ),
            );
            rebased++;
          default:
            await where.write(
              QueuedCommandsCompanion(
                state: const Value('rejected'),
                lastError: Value(r.reason ?? r.status),
              ),
            );
            rejected++;
        }
      }
    }

    final pulled = await _pull();
    await _overlayPending();
    if (rebased > 0 && resendRebased) {
      // Resend the rebased edits now rather than on the next sync. Once only:
      // if another device keeps winning, the next sync tries again.
      final again = await _sync(resendRebased: false);
      pushed += again.pushed;
    }
    return SyncReport(
      pushed: pushed,
      pulled: pulled,
      rebased: rebased,
      rejected: rejected,
    );
  }

  Future<int> _pull() async {
    var cursor = int.tryParse(await _state(_cursorKey) ?? '') ?? 0;
    var count = 0;
    while (true) {
      final page = await _api.pull(asDevice: deviceId, since: cursor);
      await _cache.transaction(() async {
        for (final change in page.changes) {
          await _store(change);
        }
        await _setState(_cursorKey, '${page.cursor}');
      });
      count += page.changes.length;
      cursor = page.cursor;
      if (!page.hasMore) return count;
    }
  }

  Future<void> _store(RemoteObject change) async {
    Uint8List? payload;
    String? unreadable;
    if (!change.deleted && change.envelope != null) {
      (payload, unreadable) = _open(change.envelope!, change.id, change.kind);
    }
    await _cache
        .into(_cache.cachedObjects)
        .insertOnConflictUpdate(
          CachedObjectsCompanion.insert(
            id: change.id,
            kind: change.kind,
            scope: change.scope,
            version: change.version,
            deleted: Value(change.deleted),
            envelope: Value(change.envelope),
            payload: Value(payload),
            unreadable: Value(unreadable),
          ),
        );
  }

  /// Decrypts an envelope the server says belongs to object [id] of [kind],
  /// checking the envelope agrees: its slot is authenticated, the server's
  /// claim is not. Without this check the server could serve one object's
  /// valid envelope under another's id.
  (Uint8List?, String?) _open(Uint8List envelope, String id, int kind) {
    try {
      final opened = open(envelope: envelope, keyring: _keyring());
      final slot = opened.header.object;
      final expected = ObjectKind.fromWire(kind);
      if (slot.id != id ||
          slot.familyId != familyId ||
          expected == null ||
          slot.objectType != expected.slotType) {
        return (null, 'damaged');
      }
      return (opened.payload, null);
    } on CryptoException catch (e) {
      return (
        null,
        e.kind == CryptoErrorKind.noAccess ? 'noAccess' : 'damaged',
      );
    }
  }

  /// Shows queued writes on top of the server state just pulled, so a pull
  /// never hides an edit that hasn't uploaded yet.
  Future<void> _overlayPending() async {
    final pending =
        await (_queue.select(_queue.queuedCommands)
              ..where((c) => c.state.equals('pending'))
              ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
            .get();
    for (final c in pending) {
      final companion = c.type == 'object.delete'
          ? const CachedObjectsCompanion(deleted: Value(true))
          : CachedObjectsCompanion(
              payload: Value(_open(c.envelope, c.targetId, c.targetKind).$1),
              envelope: Value(c.envelope),
              deleted: const Value(false),
            );
      await (_cache.update(
        _cache.cachedObjects,
      )..where((o) => o.id.equals(c.targetId))).write(companion);
    }
  }

  /// Tries again to open objects this device couldn't read, e.g. after a new
  /// grant arrived. Returns how many became readable.
  Future<int> reopenUnreadable() async {
    final rows = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.unreadable.isNotNull() & o.envelope.isNotNull())).get();
    var opened = 0;
    for (final row in rows) {
      final (payload, unreadable) = _open(row.envelope!, row.id, row.kind);
      if (payload != null) opened++;
      await (_cache.update(
        _cache.cachedObjects,
      )..where((o) => o.id.equals(row.id))).write(
        CachedObjectsCompanion(
          payload: Value(payload),
          unreadable: Value(unreadable),
        ),
      );
    }
    return opened;
  }

  /// Commands the server refused or that failed, for a person to see.
  Future<List<QueuedCommand>> stuckCommands() => (_queue.select(
    _queue.queuedCommands,
  )..where((c) => c.state.equals('rejected'))).get();

  Future<String?> _state(String key) async => (await (_cache.select(
    _cache.syncState,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setState(String key, String value) => _cache
      .into(_cache.syncState)
      .insertOnConflictUpdate(SyncStateEntry(key: key, value: value));

  static Payload? _tryDecode(Uint8List bytes) {
    try {
      return Payload.decode(bytes);
    } on FormatException {
      return null;
    }
  }
}
