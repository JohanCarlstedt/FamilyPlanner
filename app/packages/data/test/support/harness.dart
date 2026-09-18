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
