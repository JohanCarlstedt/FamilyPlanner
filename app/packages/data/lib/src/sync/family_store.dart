import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:uuid/uuid.dart';

import '../api/family_api.dart';
import '../payload/calendar_link_payload.dart';
import '../payload/event_payload.dart';
import '../payload/helper_grant_payload.dart';
import '../payload/payload.dart';
import '../payload/place_payload.dart';
import '../payload/settings_payload.dart';
import '../store/databases.dart';

/// Audience groups created with the family (crypto doc §3).
const allGroup = 'all';
const adultsGroup = 'adults';

/// The epoch every group starts at (crypto doc §3). New content is sealed to
/// the newest epoch this device holds for each group; see [FamilyStore].
const currentEpoch = 0;

/// Queued locally for a rewrap after key rotation, sent as an ordinary
/// upsert. Unlike an edit it never wins a conflict: a newer write is newer
/// content, and resending the older one would undo it.
const _rewrapType = 'object.rewrap';

/// Namespace for [FamilyStore.importedEventId]: UUIDv5 of
/// `https://github.com/JohanCarlstedt/FamilyPlanner/imported-event` in the
/// URL namespace. Fixed forever.
const _importNamespace = 'bd9e2b3a-4b5b-5360-96d1-93615d6b6ea6';

/// Object kinds, mirroring the backend's append-only ObjectKind.
enum ObjectKind {
  event(1, 'event'),
  place(2, 'place'),
  settings(13, 'settings'),
  memberProfile(14, 'member_profile'),
  eventException(15, 'event_exception'),
  helperGrant(16, 'helper_grant'),
  calendarLink(17, 'calendar_link');

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
    this.memberId,
  });

  final CacheDatabase _cache;
  final QueueDatabase _queue;
  final FamilyApi _api;
  final Keyring Function() _keyring;
  final String familyId;
  final String deviceId;

  /// Who is editing on this device. Stamped into every payload written, so
  /// the family's other devices can tell who changed what without the
  /// server knowing (spec §8: never notify the person who made the edit).
  final String? memberId;

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

  Stream<List<(String, PlacePayload)>> watchPlaces() => _watchReadable(
    ObjectKind.place,
  ).map((rows) => [for (final (id, p) in rows) (id, PlacePayload.read(p))]);

  /// The family's settings; the defaults until someone changes one.
  Stream<FamilySettings> watchSettings() =>
      _watchReadable(ObjectKind.settings).map(
        (rows) =>
            [
              for (final (id, p) in rows)
                if (id == familyId) SettingsPayload.read(p).toDomain(),
            ].firstOrNull ??
            FamilySettings.defaults,
      );

  /// Saves the family's settings, keeping fields this client doesn't know.
  Future<void> saveSettings(FamilySettings settings) async {
    final existing = await payloadOf(familyId);
    await _put(
      ObjectKind.settings,
      familyId,
      SettingsPayload.write(existing: existing, settings: settings).payload,
      [allGroup],
    );
  }

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
  Future<String> saveEvent(EventPayload event, {String? id}) async =>
      _put(ObjectKind.event, id, event.payload, await _eventGroups(event));

  /// Cancels, moves or changes one occurrence; returns the exception's id.
  /// Sealed to the same audience as its event ([visibility]), so a
  /// parents-only event's exceptions stay parents-only too.
  Future<String> saveException(
    EventExceptionPayload exception, {
    required EventVisibility visibility,
  }) async => _put(
    ObjectKind.eventException,
    EventExceptionPayload.idFor(exception.eventId, exception.originalStart!),
    exception.payload,
    await _exceptionGroups(exception, fallback: visibility),
  );

  /// How long a deleted event can be restored (spec §11: a deleted season
  /// is the worst support case there is).
  static const restoreWindow = Duration(days: 30);

  /// Moves an event to the family's recently deleted list: hidden everywhere,
  /// restorable for [restoreWindow], exceptions kept for a restore.
  Future<void> softDeleteEvent(String id, {DateTime? now}) =>
      _markDeleted(id, now ?? DateTime.now().toUtc());

  Future<void> restoreEvent(String id) => _markDeleted(id, null);

  Future<void> _markDeleted(String id, DateTime? when) async {
    final payload = await payloadOf(id);
    if (payload == null) return;
    final event = EventPayload.read(payload)..setDeletedAt(when);
    await saveEvent(event, id: id);
  }

  /// Deletes for good every event deleted more than [restoreWindow] ago.
  /// Any device may do it; the second to try finds nothing left.
  Future<int> purgeDeleted({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(restoreWindow);
    var purged = 0;
    for (final (id, e) in await watchEvents().first) {
      if (e.deletedAt case final at? when at.isBefore(cutoff)) {
        await deleteEvent(id);
        purged++;
      }
    }
    return purged;
  }

  /// Deletes an event and every exception to it this device can read, so
  /// none are left behind pointing at nothing.
  Future<void> deleteEvent(String id) async {
    final exceptions = await watchExceptions().first;
    for (final (exceptionId, e) in exceptions) {
      if (e.eventId == id) await delete(ObjectKind.eventException, exceptionId);
    }
    await delete(ObjectKind.event, id);
  }

  /// Creates or edits a place; returns its id. Places are the whole family's,
  /// so they're sealed to `all`: a child's device needs to know where
  /// training is too.
  Future<String> savePlace(PlacePayload place, {String? id}) async => _put(
    ObjectKind.place,
    id,
    place.payload,
    [allGroup, ...await _helperGroups()],
  );

  /// Writes a member's profile, keyed by their member id. Helpers read the
  /// names too: a calendar of strangers is no calendar.
  Future<void> saveProfile(String memberId, MemberProfile profile) async =>
      _put(ObjectKind.memberProfile, memberId, profile.payload, [
        allGroup,
        ...await _helperGroups(),
      ]);

  /// Grants a helper access (sealed to `adults`); returns the grant's id.
  /// Rewrap afterwards so they aren't looking at an empty calendar.
  Future<String> saveHelperGrant(HelperGrantPayload grant, {String? id}) =>
      _put(ObjectKind.helperGrant, id, grant.payload, [adultsGroup]);

  Stream<List<(String, HelperGrantPayload)>> watchHelperGrants() =>
      _watchReadable(ObjectKind.helperGrant).map(
        (rows) => [
          for (final (id, p) in rows) (id, HelperGrantPayload.read(p)),
        ],
      );

  // ---- calendar feeds (docs/roadmap.md "Integrations") -----------------------

  Future<String> saveCalendarLink(CalendarLinkPayload link, {String? id}) =>
      _put(ObjectKind.calendarLink, id, link.payload, [adultsGroup]);

  Stream<List<(String, CalendarLinkPayload)>> watchCalendarLinks() =>
      _watchReadable(ObjectKind.calendarLink).map(
        (rows) => [
          for (final (id, p) in rows) (id, CalendarLinkPayload.read(p)),
        ],
      );

  /// Removes the link and the events it brought that haven't happened yet;
  /// past ones stay, as history.
  Future<void> unlinkFeed(String linkId, {DateTime? now}) async {
    final cutoff = now ?? DateTime.now().toUtc();
    for (final (id, e) in await watchEvents().first) {
      if (e.payload.nested('source')?.text('link') != linkId) continue;
      final start = e.localStart;
      if (start != null && !start.isBefore(cutoff)) await deleteEvent(id);
    }
    await delete(ObjectKind.calendarLink, linkId);
  }

  /// The event id for [uid] in feed [linkId]: the same on every fetch and
  /// every device, so a re-fetch updates rather than duplicates.
  static String importedEventId(String linkId, String uid) =>
      const Uuid().v5(_importNamespace, '$linkId/$uid');

  /// Brings the feed's events into the calendar for its member. What the
  /// feed owns (title, time, place, status, notes) follows the feed; what
  /// the family added (who drives, reminders, more people) stays. A future
  /// event gone from the feed is marked cancelled. Returns how many events
  /// it wrote.
  Future<int> importFeed({
    required String linkId,
    required String memberId,
    required String timeZone,
    required List<ImportedEvent> events,
    DateTime? now,
  }) async {
    final cutoff = now ?? DateTime.now().toUtc();
    var written = 0;
    final seen = <String>{};
    for (final e in events) {
      final id = importedEventId(linkId, e.uid);
      seen.add(id);
      final existing = await payloadOf(id);
      final before = existing == null ? null : EventPayload.read(existing);
      // Deleted here stays deleted: the family chose not to see it.
      if (before != null && before.isDeleted) continue;
      final source = existing?.nested('source');
      if (before != null &&
          (source?.integer('seq') ?? -1) >= e.sequence &&
          before.title == e.title &&
          before.localStart == e.localStart &&
          before.duration == e.duration &&
          before.location == e.location &&
          before.notes == e.description &&
          (before.status == EventStatus.cancelled) == e.cancelled) {
        continue;
      }
      final payload = EventPayload.write(
        existing: existing,
        title: e.title,
        kind: before?.kind ?? EventKind.activity,
        localStart: e.localStart,
        duration: e.duration,
        timeZone: timeZone,
        status: e.cancelled ? EventStatus.cancelled : EventStatus.confirmed,
        visibility: before?.visibility ?? EventVisibility.family,
        rule: e.rule,
        participantIds: before?.participantIds ?? [memberId],
        responsibleMemberId: before?.responsibleMemberId,
        location: e.location,
        placeId: before?.placeId,
        notes: e.description,
        reminders: before?.reminders ?? const [],
      );
      payload.payload.setNested(
        'source',
        Payload.map()
          ..setText('link', linkId)
          ..setText('uid', e.uid)
          ..setInteger('seq', e.sequence),
      );
      await saveEvent(payload, id: id);
      written++;
    }
    // Gone from the feed: cancelled, if it hadn't happened yet.
    for (final (id, e) in await watchEvents().first) {
      if (seen.contains(id) ||
          e.payload.nested('source')?.text('link') != linkId) {
        continue;
      }
      final start = e.localStart;
      if (start == null ||
          start.isBefore(cutoff) ||
          e.isDeleted ||
          e.status == EventStatus.cancelled) {
        continue;
      }
      final copy = Payload.decode(e.payload.encode())
        ..setText('status', EventStatus.cancelled.name);
      await saveEvent(EventPayload.read(copy), id: id);
      written++;
    }
    return written;
  }

  // ---- audiences (crypto doc §6) ---------------------------------------------

  /// Helpers whose access is live and whose key this device holds: only a
  /// parent's device writes helper wraps.
  Future<List<HelperGrantPayload>> _activeHelpers() async {
    final now = DateTime.now().toUtc();
    final keyring = _keyring();
    return [
      for (final (_, g) in await watchHelperGrants().first)
        if (g.activeAt(now) && keyring.latestEpoch(group: g.group) != null) g,
    ];
  }

  Future<List<String>> _helperGroups({List<String>? participants}) async => [
    for (final g in await _activeHelpers())
      // An event for the whole family involves their children too.
      if (participants == null ||
          participants.isEmpty ||
          participants.any(g.childIds.contains))
        g.group,
  ];

  /// Parents-only events reach `adults` alone; the rest reach everyone, and
  /// any helper covering a child it involves.
  Future<List<String>> _eventGroups(EventPayload event) async =>
      event.visibility == EventVisibility.parentsOnly
      ? [adultsGroup]
      : [allGroup, ...await _helperGroups(participants: event.participantIds)];

  /// The same audience as the exception's event.
  Future<List<String>> _exceptionGroups(
    EventExceptionPayload exception, {
    EventVisibility? fallback,
  }) async {
    final event = await payloadOf(exception.eventId);
    if (event != null) return _eventGroups(EventPayload.read(event));
    return [fallback == EventVisibility.parentsOnly ? adultsGroup : allGroup];
  }

  /// Who an object should reach, by kind; null for a kind this client
  /// doesn't know, whose audience it leaves alone.
  Future<List<String>?> _groupsFor(ObjectKind kind, Payload payload) async =>
      switch (kind) {
        ObjectKind.event => _eventGroups(EventPayload.read(payload)),
        ObjectKind.eventException => _exceptionGroups(
          EventExceptionPayload.read(payload),
        ),
        ObjectKind.memberProfile ||
        ObjectKind.place => [allGroup, ...await _helperGroups()],
        ObjectKind.settings => [allGroup],
        ObjectKind.helperGrant || ObjectKind.calendarLink => [adultsGroup],
      };

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
    if (memberId case final me?) {
      // Who made it, once: "own" events (spec §2) are the ones a member made.
      if (!payload.has('createdBy')) payload.setText('createdBy', me);
      payload
        ..setText('editedBy', me)
        ..setText('editedAt', DateTime.now().toUtc().toIso8601String());
    }
    final bytes = payload.encode();
    final envelope = seal(
      payload: bytes,
      object: ObjectSlot(
        objectType: kind.slotType,
        id: objectId,
        familyId: familyId,
      ),
      audiences: _latest(groups),
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

  /// [groups] at the newest epoch this device holds for each: after a
  /// rotation, new writes reach only the devices still in the group.
  List<Audience> _latest(Iterable<String> groups) {
    final keyring = _keyring();
    return [
      for (final g in groups)
        Audience(
          group: g,
          epoch: keyring.latestEpoch(group: g) ?? currentEpoch,
        ),
    ];
  }

  /// Moves up to [limit] readable objects, newest first, to the audiences
  /// they should have now, at the newest epochs, without re-encrypting their
  /// content. Run after a rotation (crypto doc §9: rewrap recent objects
  /// eagerly, and a removed device reads nothing written from here on) and
  /// after granting a helper (so they aren't looking at an empty calendar).
  /// Only groups this device holds keys for are wrapped to. Returns how many
  /// it rewrapped.
  Future<int> rewrapToLatest({int limit = 500}) async {
    final rows =
        await (_cache.select(_cache.cachedObjects)
              ..where(
                (o) =>
                    o.deleted.equals(false) &
                    o.payload.isNotNull() &
                    o.envelope.isNotNull(),
              )
              ..orderBy([(o) => OrderingTerm.desc(o.version)])
              ..limit(limit))
            .get();
    final keyring = _keyring();
    var count = 0;
    for (final row in rows) {
      final kind = ObjectKind.fromWire(row.kind);
      final payload = _tryDecode(row.payload!);
      if (kind == null || payload == null) continue;
      final EnvelopeHeader header;
      try {
        header = inspect(envelope: row.envelope!);
      } on CryptoException {
        continue;
      }
      final groups = [
        for (final g
            in await _groupsFor(kind, payload) ??
                [for (final a in header.audiences) a.group])
          if (keyring.latestEpoch(group: g) != null) g,
      ];
      if (groups.isEmpty) continue;
      final target = _latest(groups);
      final wanted = {for (final a in target) '${a.group}@${a.epoch}'};
      final current = {
        for (final a in header.audiences) '${a.group}@${a.epoch}',
      };
      if (wanted.length == current.length && wanted.containsAll(current)) {
        continue;
      }
      final Uint8List envelope;
      try {
        envelope = rewrap(
          envelope: row.envelope!,
          audiences: target,
          keyring: keyring,
        );
      } on CryptoException {
        continue;
      }
      await _enqueue(
        type: _rewrapType,
        kind: kind,
        id: row.id,
        envelope: envelope,
      );
      await (_cache.update(_cache.cachedObjects)
            ..where((o) => o.id.equals(row.id)))
          .write(CachedObjectsCompanion(envelope: Value(envelope)));
      count++;
    }
    return count;
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
              type: c.type == _rewrapType ? 'object.upsert' : c.type,
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
          case 'conflict'
              when queued.any(
                (c) =>
                    c.clientCommandId == r.clientCommandId &&
                    c.type == _rewrapType,
              ):
            // Someone wrote since; their version stands. It moves to the new
            // epoch on its next write.
            await (_queue.delete(
              _queue.queuedCommands,
            )..where((c) => c.clientCommandId.equals(r.clientCommandId))).go();
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
      // Same content under new wraps: nothing to show that isn't shown.
      if (c.type == _rewrapType) continue;
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

  /// A setting for this device only, never synced: which calendar filter it
  /// shows, say (spec §5). Kept in the encrypted cache beside sync state.
  Future<String?> devicePreference(String name) => _state('pref.$name');

  Future<void> setDevicePreference(String name, String value) =>
      _setState('pref.$name', value);

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
