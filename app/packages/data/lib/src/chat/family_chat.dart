import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/foundation.dart';

import '../api/family_api.dart';
import '../payload/payload.dart';
import '../store/databases.dart';

/// One chat message, decrypted.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.sentAt,
    required this.text,
    required this.mine,
  });

  final String id;

  /// The sending device's id.
  final String sender;
  final DateTime sentAt;
  final String text;
  final bool mine;
}

/// The family thread (spec §6, crypto doc §7.2): one MLS group holding every
/// device in the family. This device's side of it: key packages, following
/// the delivery service in order, keeping the group's members in step with
/// the family's devices, and sending.
class FamilyChat {
  FamilyChat({
    required this._db,
    required this._api,
    required this.familyId,
    required this.deviceId,
    required this._device,
    required this._trusted,
  });

  final QueueDatabase _db;
  final FamilyApi _api;
  final String familyId;
  final String deviceId;
  final Device _device;

  /// The devices this one trusts, with their pinned keys: every member of
  /// the thread must be one of them.
  final List<TrustedDevice> Function() _trusted;

  static const _stateKey = 'mls.state';
  static const _cursorKey = 'mls.cursor';

  /// Keep at least this many key packages on the server, so this device can
  /// be added while it's offline.
  static const _minKeyPackages = 5;

  Uint8List get _groupId => Uint8List.fromList(utf8.encode('family:$familyId'));

  /// The group id as the delivery service knows it.
  String get groupHex =>
      _groupId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Mls? _mls;
  var _lock = Future<void>.value();

  /// Runs [work] alone: MLS state must never be used from two places at
  /// once, and every change is saved before the next begins.
  Future<T> _serial<T>(Future<T> Function(Mls mls) work) {
    final done = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final mls = _mls ??= await _load();
        final result = await work(mls);
        await _save(mls);
        done.complete(result);
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  Future<Mls> _load() async {
    final row = await (_db.select(
      _db.deviceState,
    )..where((s) => s.key.equals(_stateKey))).getSingleOrNull();
    return row == null ? Mls() : Mls.restore(state: row.value);
  }

  Future<void> _save(Mls mls) => _db
      .into(_db.deviceState)
      .insertOnConflictUpdate(
        DeviceStateEntry(key: _stateKey, value: mls.exportState()),
      );

  Future<int> _cursor() async {
    final row = await (_db.select(
      _db.deviceState,
    )..where((s) => s.key.equals(_cursorKey))).getSingleOrNull();
    return row == null ? 0 : int.parse(utf8.decode(row.value));
  }

  Future<void> _setCursor(int cursor) => _db
      .into(_db.deviceState)
      .insertOnConflictUpdate(
        DeviceStateEntry(
          key: _cursorKey,
          value: Uint8List.fromList(utf8.encode('$cursor')),
        ),
      );

  /// Messages in the thread, oldest first.
  Stream<List<ChatMessage>> watch() =>
      (_db.select(_db.chatMessages)
            ..where((m) => m.groupId.equals(groupHex))
            ..orderBy([(m) => OrderingTerm.asc(m.sentAt)]))
          .watch()
          .map((rows) => [for (final r in rows) ?_decode(r)]);

  ChatMessage? _decode(ChatMessageRow r) {
    try {
      final p = Payload.decode(r.payload);
      return ChatMessage(
        id: r.id,
        sender: r.sender,
        sentAt: r.sentAt,
        text: p.text('text') ?? '',
        mine: r.sender == deviceId,
      );
    } on FormatException {
      return null;
    }
  }

  /// Keeps key packages on the server, then follows the delivery service:
  /// joins from a welcome, applies commits, decrypts messages. Returns the
  /// messages other devices sent since the last sync.
  Future<List<ChatMessage>> sync() => _serial((mls) async {
    await _topUpKeyPackages(mls);
    final fresh = <ChatMessage>[];
    var cursor = await _cursor();
    while (true) {
      final page = await _api.mlsMessages(asDevice: deviceId, since: cursor);
      for (final m in page.messages) {
        if (m.groupId != groupHex) continue;
        if (await _apply(mls, m) case final message?) fresh.add(message);
      }
      cursor = page.cursor;
      await _save(mls);
      await _setCursor(cursor);
      if (!page.hasMore) return fresh;
    }
  });

  Future<void> _topUpKeyPackages(Mls mls) async {
    final unclaimed = await _api.unclaimedKeyPackages(asDevice: deviceId);
    if (unclaimed >= _minKeyPackages) return;
    await _api.publishKeyPackages(
      asDevice: deviceId,
      keyPackages: mls.keyPackages(
        device: _device,
        deviceId: deviceId,
        count: 10,
      ),
    );
  }

  Future<ChatMessage?> _apply(Mls mls, MlsRelayed m) async {
    final member = mls.hasGroup(groupId: _groupId);
    try {
      switch (m.kind) {
        case 'welcome' when !member:
          mls.join(welcome: m.body, trusted: _trusted());
        case 'commit' when member && m.sender != deviceId:
          // Commits from before this device joined, or already applied.
          if (m.epoch < mls.epoch(groupId: _groupId).toInt()) return null;
          mls.process(groupId: _groupId, message: m.body, trusted: _trusted());
        case 'application' when member && m.sender != deviceId:
          final incoming = mls.process(
            groupId: _groupId,
            message: m.body,
            trusted: _trusted(),
          );
          if (incoming.kind != MlsIncomingKind.application) return null;
          return await _store(
            id: 'seq:${m.seq}',
            sender: incoming.sender!,
            payload: incoming.content!,
          );
      }
    } on CryptoException catch (e) {
      // One bad message, or one from before this device joined, must not
      // stop the rest.
      debugPrint('Skipping chat message ${m.seq}: ${e.kind.name}');
    }
    return null;
  }

  Future<ChatMessage?> _store({
    required String id,
    required String sender,
    required Uint8List payload,
  }) async {
    final Payload p;
    try {
      p = Payload.decode(payload);
    } on FormatException {
      return null;
    }
    final sentAt =
        DateTime.tryParse(p.text('at') ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    await _db
        .into(_db.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageRow(
            id: id,
            groupId: groupHex,
            sender: sender,
            sentAt: sentAt,
            payload: payload,
          ),
        );
    return _decode(
      ChatMessageRow(
        id: id,
        groupId: groupHex,
        sender: sender,
        sentAt: sentAt,
        payload: payload,
      ),
    );
  }

  /// Brings the thread's members in step with [familyDevices] (this device
  /// included): adds the ones missing, removes the ones gone. Any device can
  /// do it; a lost race is discarded and tried again on the next call.
  /// Starts the thread if this device has none and [mayStart].
  Future<void> reconcile({
    required Set<String> familyDevices,
    bool mayStart = false,
  }) => _serial((mls) async {
    if (!mls.hasGroup(groupId: _groupId)) {
      if (!mayStart) return;
      mls.createGroup(device: _device, deviceId: deviceId, groupId: _groupId);
    }
    final current = mls.members(groupId: _groupId).toSet();
    // Only devices this one trusts are ever asked in: a device list from
    // anywhere else can't add a stranger, and one that tries doesn't stop the
    // rest from joining.
    final trustedIds = {for (final t in _trusted()) t.deviceId};
    final missing = familyDevices
        .intersection(trustedIds)
        .difference(current)
        .toList();
    final gone = current.difference(familyDevices)..remove(deviceId);

    if (missing.isNotEmpty) {
      final keyPackages = await _api.claimKeyPackages(
        asDevice: deviceId,
        deviceIds: missing,
      );
      if (keyPackages.isNotEmpty) {
        final pending = mls.addMembers(
          device: _device,
          groupId: _groupId,
          keyPackages: keyPackages.values.toList(),
          trusted: _trusted(),
        );
        await _commit(mls, pending, welcomeTo: keyPackages.keys.toList());
      }
    }
    if (gone.isNotEmpty && mls.hasGroup(groupId: _groupId)) {
      final pending = mls.removeMembers(
        device: _device,
        groupId: _groupId,
        deviceIds: gone.toList(),
      );
      await _commit(mls, pending, welcomeTo: const []);
    }
  });

  Future<void> _commit(
    Mls mls,
    MlsCommit pending, {
    required List<String> welcomeTo,
  }) async {
    final epoch = mls.epoch(groupId: _groupId).toInt();
    try {
      await _api.commitMls(
        asDevice: deviceId,
        groupId: groupHex,
        epoch: epoch,
        commit: pending.commit,
        welcome: pending.welcome,
        welcomeTo: welcomeTo,
      );
      mls.mergePending(groupId: _groupId);
    } on MlsEpochConflict {
      mls.discardPending(groupId: _groupId);
      // Lost the race to start the thread: another device's is the one, and
      // it will welcome this device in.
      if (epoch == 0) mls.forgetGroup(groupId: _groupId);
    }
  }

  /// Encrypts and sends [text] to the family.
  Future<ChatMessage> send(String text) => _serial((mls) async {
    final now = DateTime.now().toUtc();
    final payload =
        (Payload.create(1)
              ..setText('text', text)
              ..setText('at', now.toIso8601String()))
            .encode();
    final message = mls.encrypt(
      device: _device,
      groupId: _groupId,
      content: payload,
    );
    // The ratchet has moved: saved before anything can fail.
    await _save(mls);
    final seq = await _api.sendMlsMessage(
      asDevice: deviceId,
      groupId: groupHex,
      epoch: mls.epoch(groupId: _groupId).toInt(),
      message: message,
    );
    return (await _store(id: 'seq:$seq', sender: deviceId, payload: payload))!;
  });

  bool get hasThread => _mls?.hasGroup(groupId: _groupId) ?? false;

  /// Whether anyone else is in the thread yet: until then the delivery
  /// service doesn't know it, and there's no one to hear.
  bool get canTalk {
    final mls = _mls;
    if (mls == null || !mls.hasGroup(groupId: _groupId)) return false;
    return mls.members(groupId: _groupId).length > 1;
  }
}
