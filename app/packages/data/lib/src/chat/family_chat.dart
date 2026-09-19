import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/family_api.dart';
import '../payload/payload.dart';
import '../store/databases.dart';

/// What a message in a thread is.
enum ChatMessageKind {
  text,

  /// Who can read the thread from here on (spec §6: supervision starting or
  /// ending is announced in the thread, never silent).
  readers,
}

/// One chat message, decrypted.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.group,
    required this.sender,
    required this.sentAt,
    required this.text,
    required this.mine,
    this.kind = ChatMessageKind.text,
    this.members = const [],
  });

  final String id;

  /// The conversation's group, as the delivery service knows it.
  final String group;

  /// The sending device's id.
  final String sender;
  final DateTime sentAt;
  final String text;
  final bool mine;
  final ChatMessageKind kind;

  /// For [ChatMessageKind.readers]: the members reading without talking.
  final List<String> members;
}

/// Spec §6 `conversation.scope`.
enum ConversationScope { family, direct, group }

/// A thread this device is in.
class Conversation {
  const Conversation({
    required this.group,
    required this.scope,
    required this.participants,
    this.title,
    this.last,
    this.unread = 0,
  });

  final String group;
  final ConversationScope scope;

  /// Member ids of the people talking; empty for the family thread, which
  /// is everyone.
  final List<String> participants;

  /// A group's name; null for the family and direct threads.
  final String? title;
  final ChatMessage? last;
  final int unread;
}

/// The family's chat (spec §6, crypto doc §7.2): the family thread, one MLS
/// group holding every device in the family, and direct and group
/// conversations, each its own MLS group. This device's side of them: key
/// packages, following the delivery service in order, keeping each group's
/// members in step, and sending.
///
/// A conversation's name and participants travel inside its group as a
/// `meta` message, so the server never learns them; whoever adds a device
/// sends it again, since a new member reads nothing from before it joined.
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
  /// a thread must be one of them.
  final List<TrustedDevice> Function() _trusted;

  static const _stateKey = 'mls.state';
  static const _cursorKey = 'mls.cursor';
  static const _readPrefix = 'chat.read.';
  static const _namespace = '1c3c4f3e-58a4-5b8e-9d8e-2f9f3d1f6a51';

  /// Keep at least this many key packages on the server, so this device can
  /// be added while it's offline.
  static const _minKeyPackages = 5;

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _bytes(String hex) => Uint8List.fromList([
    for (var i = 0; i + 1 < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);

  /// The family thread's group.
  String get familyGroup => _hex(utf8.encode('family:$familyId'));

  /// The one direct conversation between two members (spec §6: keyed on
  /// the sorted pair). Hashed, so the id doesn't spell out who's in it.
  String directGroup(String a, String b) => _hex(
    utf8.encode(
      'dm:${const Uuid().v5(_namespace, '$familyId/${directKey(a, b)}')}',
    ),
  );

  /// A member's location group (spec §7): their devices and whoever they
  /// share with. Hashed like a direct thread.
  String locationGroup(String memberId) => _hex(
    utf8.encode('loc:${const Uuid().v5(_namespace, '$familyId/$memberId')}'),
  );

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

  Future<String?> _state(String key) async {
    final row = await (_db.select(
      _db.deviceState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row == null ? null : utf8.decode(row.value);
  }

  Future<void> _setState(String key, String value) => _db
      .into(_db.deviceState)
      .insertOnConflictUpdate(
        DeviceStateEntry(
          key: key,
          value: Uint8List.fromList(utf8.encode(value)),
        ),
      );

  /// Messages in a thread, the family's by default, oldest first.
  Stream<List<ChatMessage>> watch([String? group]) {
    final g = group ?? familyGroup;
    return (_db.select(_db.chatMessages)
          ..where((m) => m.groupId.equals(g))
          ..orderBy([(m) => OrderingTerm.asc(m.sentAt)]))
        .watch()
        .map((rows) => [for (final r in rows) ?_decode(r)]);
  }

  /// Every thread this device has heard of, the family's first, then the
  /// most recent.
  Stream<List<Conversation>> watchConversations() => _db
      .customSelect('SELECT 1', readsFrom: {_db.chatMessages, _db.deviceState})
      .watch()
      .asyncMap((_) => conversations());

  Future<List<Conversation>> conversations() async {
    final rows = await (_db.select(
      _db.chatMessages,
    )..orderBy([(m) => OrderingTerm.asc(m.sentAt)])).get();
    final reads = {
      for (final s in await (_db.select(
        _db.deviceState,
      )..where((s) => s.key.like('$_readPrefix%'))).get())
        s.key.substring(_readPrefix.length): DateTime.tryParse(
          utf8.decode(s.value),
        ),
    };
    final meta = <String, Payload>{};
    final last = <String, ChatMessage>{};
    final unread = <String, int>{};
    for (final r in rows) {
      final Payload p;
      try {
        p = Payload.decode(r.payload);
      } on FormatException {
        continue;
      }
      if (p.text('type') == 'meta') {
        if (_validMeta(r.groupId, p)) meta[r.groupId] = p;
        continue;
      }
      final m = _decode(r);
      if (m == null) continue;
      last[r.groupId] = m;
      final read = reads[r.groupId];
      if (!m.mine &&
          m.kind == ChatMessageKind.text &&
          (read == null || m.sentAt.isAfter(read))) {
        unread[r.groupId] = (unread[r.groupId] ?? 0) + 1;
      }
    }
    final others =
        [
          for (final MapEntry(key: group, value: p) in meta.entries)
            Conversation(
              group: group,
              scope: p.text('scope') == 'direct'
                  ? ConversationScope.direct
                  : ConversationScope.group,
              participants: p.texts('participants') ?? const [],
              title: p.text('title'),
              last: last[group],
              unread: unread[group] ?? 0,
            ),
        ]..sort(
          (a, b) => (b.last?.sentAt ?? DateTime(0)).compareTo(
            a.last?.sentAt ?? DateTime(0),
          ),
        );
    return [
      Conversation(
        group: familyGroup,
        scope: ConversationScope.family,
        participants: const [],
        last: last[familyGroup],
        unread: unread[familyGroup] ?? 0,
      ),
      ...others,
    ];
  }

  /// A direct conversation's meta must name the pair its group is keyed
  /// on: a member can't relabel a thread into someone else's.
  bool _validMeta(String group, Payload p) {
    final people = p.texts('participants') ?? const [];
    return switch (p.text('scope')) {
      'direct' =>
        people.length == 2 && directGroup(people[0], people[1]) == group,
      'group' => people.isNotEmpty,
      _ => false,
    };
  }

  /// Marks a thread read up to now.
  Future<void> markRead(String group) =>
      _setState('$_readPrefix$group', DateTime.now().toUtc().toIso8601String());

  ChatMessage? _decode(ChatMessageRow r) {
    try {
      final p = Payload.decode(r.payload);
      final kind = switch (p.text('type')) {
        null || 'text' => ChatMessageKind.text,
        'readers' => ChatMessageKind.readers,
        _ => null,
      };
      if (kind == null) return null;
      return ChatMessage(
        id: r.id,
        group: r.groupId,
        sender: r.sender,
        sentAt: r.sentAt,
        text: p.text('text') ?? '',
        mine: r.sender == deviceId,
        kind: kind,
        members: p.texts('members') ?? const [],
      );
    } on FormatException {
      return null;
    }
  }

  /// Whether this device is in [group] now: removed, it may still hold the
  /// group's old state.
  bool _isIn(Mls mls, Uint8List group) {
    if (!mls.hasGroup(groupId: group)) return false;
    try {
      return mls.members(groupId: group).contains(deviceId);
    } on CryptoException {
      return false;
    }
  }

  /// Keeps key packages on the server, then follows the delivery service:
  /// joins from welcomes, applies commits, decrypts messages. Returns the
  /// messages other devices sent since the last sync.
  Future<List<ChatMessage>> sync() => _serial((mls) async {
    await _topUpKeyPackages(mls);
    return _follow(mls);
  });

  Future<List<ChatMessage>> _follow(Mls mls) async {
    final fresh = <ChatMessage>[];
    var cursor = int.parse(await _state(_cursorKey) ?? '0');
    while (true) {
      final page = await _api.mlsMessages(asDevice: deviceId, since: cursor);
      for (final m in page.messages) {
        if (await _apply(mls, m) case final message?) fresh.add(message);
      }
      cursor = page.cursor;
      await _save(mls);
      await _setState(_cursorKey, '$cursor');
      if (!page.hasMore) return fresh;
    }
  }

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
    final group = _bytes(m.groupId);
    final member = _isIn(mls, group);
    try {
      switch (m.kind) {
        case 'welcome' when !member:
          // Asked back in after being taken out: the old state is useless.
          if (mls.hasGroup(groupId: group)) mls.forgetGroup(groupId: group);
          mls.join(welcome: m.body, trusted: _trusted());
        case 'commit' when member && m.sender != deviceId:
          // Commits from before this device joined, or already applied.
          if (m.epoch < mls.epoch(groupId: group).toInt()) return null;
          mls.process(groupId: group, message: m.body, trusted: _trusted());
        case 'application' when member && m.sender != deviceId:
          final incoming = mls.process(
            groupId: group,
            message: m.body,
            trusted: _trusted(),
          );
          if (incoming.kind != MlsIncomingKind.application) return null;
          return await _store(
            id: 'seq:${m.seq}',
            group: m.groupId,
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
    required String group,
    required String sender,
    required Uint8List payload,
  }) async {
    final Payload p;
    try {
      p = Payload.decode(payload);
    } on FormatException {
      return null;
    }
    // Latest only (spec §7): a position replaces the last one here too.
    final row = ChatMessageRow(
      id: p.text('type') == 'position' ? 'position:$group' : id,
      groupId: group,
      sender: sender,
      sentAt:
          DateTime.tryParse(p.text('at') ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      payload: payload,
    );
    await _db.into(_db.chatMessages).insertOnConflictUpdate(row);
    return _decode(row);
  }

  /// Brings a thread's members, the family's by default, in step with
  /// [devices] (this device included): adds the trusted ones missing,
  /// removes the ones gone, never this device. Any device in the thread can
  /// do it; a lost race is discarded and tried again on the next call.
  /// Starts the thread if this device has none and [mayStart].
  ///
  /// Returns whether anything changed.
  Future<bool> reconcile({
    String? group,
    required Set<String> devices,
    bool mayStart = false,
  }) => _serial(
    (mls) => _reconcile(mls, group ?? familyGroup, devices, mayStart),
  );

  Future<bool> _reconcile(
    Mls mls,
    String groupHex,
    Set<String> devices,
    bool mayStart,
  ) async {
    final group = _bytes(groupHex);
    if (!_isIn(mls, group)) {
      if (!mayStart) return false;
      if (mls.hasGroup(groupId: group)) mls.forgetGroup(groupId: group);
      mls.createGroup(device: _device, deviceId: deviceId, groupId: group);
    }
    final current = mls.members(groupId: group).toSet();
    // Only devices this one trusts are ever asked in: a device list from
    // anywhere else can't add a stranger, and one that tries doesn't stop the
    // rest from joining.
    final trustedIds = {for (final t in _trusted()) t.deviceId};
    final missing = devices
        .intersection(trustedIds)
        .difference(current)
        .toList();
    final gone = current.difference(devices)..remove(deviceId);
    var changed = false;

    if (missing.isNotEmpty) {
      final keyPackages = await _api.claimKeyPackages(
        asDevice: deviceId,
        deviceIds: missing,
      );
      if (keyPackages.isNotEmpty) {
        final pending = mls.addMembers(
          device: _device,
          groupId: group,
          keyPackages: keyPackages.values.toList(),
          trusted: _trusted(),
        );
        changed |= await _commit(
          mls,
          groupHex,
          pending,
          welcomeTo: keyPackages.keys.toList(),
        );
        // The newcomers can't read anything from before.
        if (changed && groupHex != familyGroup) {
          await _catchUp(mls, groupHex);
        }
      }
    }
    if (gone.isNotEmpty && _isIn(mls, group)) {
      final pending = mls.removeMembers(
        device: _device,
        groupId: group,
        deviceIds: gone.toList(),
      );
      changed |= await _commit(mls, groupHex, pending, welcomeTo: const []);
    }
    return changed;
  }

  Future<bool> _commit(
    Mls mls,
    String groupHex,
    MlsCommit pending, {
    required List<String> welcomeTo,
  }) async {
    final group = _bytes(groupHex);
    final epoch = mls.epoch(groupId: group).toInt();
    try {
      await _api.commitMls(
        asDevice: deviceId,
        groupId: groupHex,
        epoch: epoch,
        commit: pending.commit,
        welcome: pending.welcome,
        welcomeTo: welcomeTo,
      );
      mls.mergePending(groupId: group);
      return true;
    } on MlsEpochConflict {
      mls.discardPending(groupId: group);
      // Lost the race to start the thread: another device's is the one, and
      // it will welcome this device in.
      if (epoch == 0) mls.forgetGroup(groupId: group);
      return false;
    }
  }

  /// Tells newcomers what they couldn't read: a conversation's name and
  /// participants, or this device's latest position.
  Future<void> _catchUp(Mls mls, String group) async {
    final rows =
        await (_db.select(_db.chatMessages)
              ..where((m) => m.groupId.equals(group))
              ..orderBy([(m) => OrderingTerm.desc(m.sentAt)]))
            .get();
    for (final r in rows) {
      switch (_tryDecode(r.payload)?.text('type')) {
        case 'meta':
          await _send(mls, group, r.payload);
          return;
        case 'position' when r.sender == deviceId:
          await _send(mls, group, r.payload, slot: 'position');
          return;
      }
    }
  }

  /// Starts a direct or group conversation with [participants] (member
  /// ids, this device's member included), reaching [devices]. A direct one
  /// that exists already is simply returned. Returns its group.
  ///
  /// Throws a [StateError] when none of the others can be reached yet.
  Future<String> start({
    required ConversationScope scope,
    required List<String> participants,
    required Set<String> devices,
    String? title,
  }) => _serial((mls) async {
    assert(scope != ConversationScope.family);
    final group = scope == ConversationScope.direct
        ? directGroup(participants[0], participants[1])
        : _hex(utf8.encode('group:${const Uuid().v4()}'));
    if (_isIn(mls, _bytes(group)) &&
        mls.members(groupId: _bytes(group)).length > 1) {
      return group;
    }
    final meta =
        (Payload.create(1)
              ..setText('type', 'meta')
              ..setText(
                'scope',
                scope == ConversationScope.direct ? 'direct' : 'group',
              )
              ..setText('title', title)
              ..setTexts('participants', participants)
              ..setText('at', DateTime.now().toUtc().toIso8601String()))
            .encode();
    await _reconcile(mls, group, devices, true);
    if (!_isIn(mls, _bytes(group))) return group; // Another device's won.
    if (mls.members(groupId: _bytes(group)).length < 2) {
      mls.forgetGroup(groupId: _bytes(group));
      throw StateError('no one to talk to yet');
    }
    await _send(mls, group, meta);
    return group;
  });

  /// Tells a thread who reads it without talking (spec §6: the transition
  /// is announced). An empty [members] says nobody does any more.
  Future<void> announceReaders(String group, List<String> members) => _serial(
    (mls) => _send(
      mls,
      group,
      (Payload.create(1)
            ..setText('type', 'readers')
            ..setTexts('members', members)
            ..setText('at', DateTime.now().toUtc().toIso8601String()))
          .encode(),
    ),
  );

  /// Encrypts and sends [text] to a thread, the family's by default.
  Future<ChatMessage> send(String text, {String? group}) => _serial(
    (mls) async => (await _send(
      mls,
      group ?? familyGroup,
      (Payload.create(1)
            ..setText('text', text)
            ..setText('at', DateTime.now().toUtc().toIso8601String()))
          .encode(),
    ))!,
  );

  Future<ChatMessage?> _send(
    Mls mls,
    String group,
    Uint8List payload, {
    bool retry = true,
    String? slot,
  }) async {
    final bytes = _bytes(group);
    final message = mls.encrypt(
      device: _device,
      groupId: bytes,
      content: payload,
    );
    // The ratchet has moved: saved before anything can fail.
    await _save(mls);
    final int seq;
    try {
      seq = await _api.sendMlsMessage(
        asDevice: deviceId,
        groupId: group,
        epoch: mls.epoch(groupId: bytes).toInt(),
        message: message,
        slot: slot,
      );
    } on MlsEpochConflict {
      // Someone was added or taken out since: catch up, then say it again
      // to whoever is in it now.
      if (!retry) rethrow;
      await _follow(mls);
      if (!_isIn(mls, bytes)) throw StateError('no longer in this thread');
      return _send(mls, group, payload, retry: false, slot: slot);
    }
    return _store(
      id: 'seq:$seq',
      group: group,
      sender: deviceId,
      payload: payload,
    );
  }

  /// Shares [memberId]'s position (or that they paused or stopped) with
  /// their location group, starting it if needed and keeping it to
  /// [viewers], the devices allowed to see plus the member's own. The
  /// server keeps only the latest.
  Future<void> sharePosition(
    String memberId,
    Uint8List payload, {
    required Set<String> viewers,
  }) => _serial((mls) async {
    final group = locationGroup(memberId);
    await _reconcile(mls, group, viewers, true);
    if (!_isIn(mls, _bytes(group))) return; // Another device's won; next time.
    if (mls.members(groupId: _bytes(group)).length < 2) {
      // Nobody to tell: keep it here, send nothing.
      await _store(
        id: 'local',
        group: group,
        sender: deviceId,
        payload: payload,
      );
      return;
    }
    await _send(mls, group, payload, slot: 'position');
  });

  /// Every member's latest position this device can read, by location
  /// group, with the device that sent it.
  Stream<Map<String, (String, Payload)>> watchPositions() =>
      (_db.select(
        _db.chatMessages,
      )..where((m) => m.id.like('position:%'))).watch().map(
        (rows) => {
          for (final r in rows)
            if (_tryDecode(r.payload) case final p?) r.groupId: (r.sender, p),
        },
      );

  static Payload? _tryDecode(Uint8List bytes) {
    try {
      return Payload.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  /// Keeps a location group this device is in to [devices]; for viewers'
  /// devices, where supervision or a changed choice moves who may see.
  Future<bool> reconcileLocation(String memberId, Set<String> devices) =>
      reconcile(group: locationGroup(memberId), devices: devices);

  /// Whether this device is in [memberId]'s location group.
  bool seesLocationOf(String memberId) => _isInGroup(locationGroup(memberId));

  bool get hasThread => _isInGroup(familyGroup);

  bool _isInGroup(String group) {
    final mls = _mls;
    return mls != null && _isIn(mls, _bytes(group));
  }

  /// Whether anyone else is in the family thread yet: until then the
  /// delivery service doesn't know it, and there's no one to hear.
  bool get canTalk => canTalkIn(familyGroup);

  /// Whether this device is in [group] with someone else.
  bool canTalkIn(String group) {
    final mls = _mls;
    if (mls == null || !_isIn(mls, _bytes(group))) return false;
    return mls.members(groupId: _bytes(group)).length > 1;
  }

  /// The devices that can read [group], this one included: the key list is
  /// the reader list (spec §6).
  Set<String> readersOf(String group) {
    final mls = _mls;
    if (mls == null || !_isIn(mls, _bytes(group))) return const {};
    return mls.members(groupId: _bytes(group)).toSet();
  }

  /// The direct and group threads this device is in, for keeping their
  /// members in step.
  Future<List<Conversation>> joined() async {
    await _serial((_) async {});
    return [
      for (final c in await conversations())
        if (c.scope != ConversationScope.family && _isInGroup(c.group)) c,
    ];
  }
}
