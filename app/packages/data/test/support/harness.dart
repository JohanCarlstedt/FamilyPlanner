import 'dart:io';

import 'package:drift/native.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Loads the Rust core built for this machine (`cargo build` in
/// packages/crypto/rust), so host tests use real crypto.
Future<void> initRustForHost() async {
  final lib = File('../crypto/rust/target/debug/libfamily_crypto.dylib');
  if (!lib.existsSync()) {
    throw StateError(
      'Build the crypto core first: cd ../crypto/rust && cargo build',
    );
  }
  await RustLib.init(externalLibrary: ExternalLibrary.open(lib.path));
}

/// The backend's sync and command rules, in memory: versions, a monotonic
/// sequence, idempotency on client command ids, and conflicts on stale writes.
class FakeServer extends FamilyApi {
  FakeServer() : super(Uri.parse('http://fake'));

  final objects = <String, RemoteObject>{};
  final _sequences = <String, int>{};
  final _seen = <String>{};
  var _sequence = 0;

  /// Set to make the server misbehave on pull.
  RemoteObject Function(RemoteObject)? tamper;

  @override
  Future<List<CommandResult>> submitCommands({
    required String asDevice,
    required List<OutgoingCommand> commands,
  }) async {
    final results = <CommandResult>[];
    for (final c in commands) {
      if (!_seen.add('$asDevice/${c.clientCommandId}')) {
        results.add(
          CommandResult(
            clientCommandId: c.clientCommandId,
            status: 'duplicate',
          ),
        );
        continue;
      }
      final existing = objects[c.targetId];
      if (existing != null &&
          c.expectedVersion != null &&
          existing.version != c.expectedVersion) {
        _seen.remove('$asDevice/${c.clientCommandId}');
        results.add(
          CommandResult(
            clientCommandId: c.clientCommandId,
            status: 'conflict',
            sequence: existing.version,
          ),
        );
        continue;
      }
      final deleted = c.type == 'object.delete';
      objects[c.targetId] = RemoteObject(
        id: c.targetId,
        kind: c.targetKind,
        scope: c.scope,
        envelope: deleted ? null : c.envelope,
        version: (existing?.version ?? 0) + 1,
        deleted: deleted,
      );
      _sequences[c.targetId] = ++_sequence;
      results.add(
        CommandResult(
          clientCommandId: c.clientCommandId,
          status: 'applied',
          sequence: _sequence,
        ),
      );
    }
    return results;
  }

  // ---- blob store ------------------------------------------------------------

  final blobs = <String, Uint8List>{};

  @override
  Future<void> putBlob({
    required String asDevice,
    required String id,
    required Uint8List envelope,
  }) async => blobs.putIfAbsent(id, () => envelope);

  @override
  Future<Uint8List?> getBlob({
    required String asDevice,
    required String id,
  }) async => blobs[id];

  // ---- MLS delivery service, as the backend orders it ----------------------

  final keyPackages = <String, List<Uint8List>>{};
  final mlsEpochs = <String, int>{};
  final mlsLog = <(MlsRelayed, String?)>[];
  var _mlsSeq = 0;

  @override
  Future<int> unclaimedKeyPackages({required String asDevice}) async =>
      keyPackages[asDevice]?.length ?? 0;

  @override
  Future<int> publishKeyPackages({
    required String asDevice,
    required List<Uint8List> keyPackages,
  }) async => ((this.keyPackages[asDevice] ??= [])..addAll(keyPackages)).length;

  @override
  Future<Map<String, Uint8List>> claimKeyPackages({
    required String asDevice,
    required List<String> deviceIds,
  }) async => {
    for (final id in deviceIds)
      if (keyPackages[id]?.isNotEmpty ?? false)
        id: keyPackages[id]!.removeAt(0),
  };

  void _relay(
    String group,
    int epoch,
    String kind,
    String sender,
    Uint8List body, [
    String? to,
  ]) {
    mlsLog.add((
      MlsRelayed(
        seq: ++_mlsSeq,
        groupId: group,
        epoch: epoch,
        kind: kind,
        sender: sender,
        body: body,
      ),
      to,
    ));
  }

  @override
  Future<int> commitMls({
    required String asDevice,
    required String groupId,
    required int epoch,
    required Uint8List commit,
    Uint8List? welcome,
    List<String> welcomeTo = const [],
  }) async {
    final current = mlsEpochs[groupId] ?? 0;
    if (current != epoch) throw MlsEpochConflict(current);
    _relay(groupId, epoch, 'commit', asDevice, commit);
    if (welcome != null) {
      for (final to in welcomeTo) {
        _relay(groupId, epoch + 1, 'welcome', asDevice, welcome, to);
      }
    }
    return mlsEpochs[groupId] = epoch + 1;
  }

  @override
  Future<int> sendMlsMessage({
    required String asDevice,
    required String groupId,
    required int epoch,
    required Uint8List message,
  }) async {
    _relay(groupId, epoch, 'application', asDevice, message);
    return _mlsSeq;
  }

  @override
  Future<MlsPage> mlsMessages({
    required String asDevice,
    required int since,
  }) async {
    final visible = [
      for (final (m, to) in mlsLog)
        if (m.seq > since && (m.kind != 'welcome' || to == asDevice)) m,
    ];
    return MlsPage(
      messages: visible,
      cursor: visible.isEmpty ? since : visible.last.seq,
      hasMore: false,
    );
  }

  @override
  Future<SyncPage> pull({required String asDevice, required int since}) async {
    final changed = [
      for (final MapEntry(key: id, value: seq) in _sequences.entries)
        if (seq > since) (seq, objects[id]!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return SyncPage(
      changes: [for (final (_, o) in changed) tamper?.call(o) ?? o],
      cursor: changed.isEmpty ? since : changed.last.$1,
      hasMore: false,
    );
  }
}

/// One device's store, with its own encrypted databases in [dir].
class TestDevice {
  TestDevice._(this.store, this.cache, this.queue);

  static Future<TestDevice> open({
    required Directory dir,
    required String name,
    required FamilyApi api,
    required Keyring keyring,
    String familyId = 'fam-1',
  }) async {
    final key = Uint8List.fromList(
      List.generate(32, (i) => (i * 7 + name.length) & 0xff),
    );
    final cache = CacheDatabase(
      openEncrypted(File('${dir.path}/$name-cache.db'), key),
    );
    final queue = QueueDatabase(
      openEncrypted(File('${dir.path}/$name-queue.db'), key),
    );
    return TestDevice._(
      FamilyStore(
        cache: cache,
        queue: queue,
        api: api,
        familyId: familyId,
        deviceId: name,
        keyring: () => keyring,
        memberId: 'member-$name',
      ),
      cache,
      queue,
    );
  }

  final FamilyStore store;
  final CacheDatabase cache;
  final QueueDatabase queue;

  Future<void> close() async {
    await cache.close();
    await queue.close();
  }
}

/// An in-memory database, for tests that don't care about the file.
CacheDatabase memoryCache() => CacheDatabase(NativeDatabase.memory());
