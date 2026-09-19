import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../api/family_api_provider.dart';
import 'family_repository.dart';
import '../chat/chat_providers.dart';
import '../integrations/calendar_feeds.dart';
import '../membership/membership.dart';
import '../pairing/device_providers.dart';
import '../pairing/pairing_service.dart';

/// The key both local databases are encrypted with: random, created once,
/// kept beside the device secret (crypto doc §2.1). Losing it loses nothing
/// the server doesn't hold, except unsynced edits.
Future<Uint8List> _databaseKey(SecretStore store) async {
  const name = 'database_key.v1';
  final existing = await store.read(name);
  if (existing != null) return existing;
  final random = Random.secure();
  final key = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
  await store.write(name, key);
  return key;
}

/// This device's two encrypted databases: the disposable cache, and the
/// precious one holding unsynced edits, chat state and chat history. Opened
/// once per family and device.
final localDatabasesProvider = FutureProvider<(CacheDatabase, QueueDatabase)>((
  ref,
) async {
  final ids = await ref.watch(
    membershipProvider.selectAsync(
      (m) => m == null ? null : (m.familyId, m.deviceId),
    ),
  );
  if (ids == null) throw StateError('no family on this device yet');
  final key = await _databaseKey(ref.read(secretStoreProvider));
  final dir = await getApplicationSupportDirectory();
  final cacheFile = File('${dir.path}/cache-v1.db');
  final queueFile = File('${dir.path}/queue-v1.db');
  // Files under another key belong to an identity this device no longer
  // holds (a new family, or keys lost with the keychain): nothing in them is
  // usable, and left there they'd stop the app opening. Set them aside.
  for (final file in [cacheFile, queueFile]) {
    if (!opensWith(file, key)) {
      debugPrint('Setting aside ${file.path}: written under another key');
      await file.rename('${file.path}.unreadable');
    }
  }
  final cache = CacheDatabase(openEncrypted(cacheFile, key));
  final queue = QueueDatabase(openEncrypted(queueFile, key));
  ref.onDispose(() {
    cache.close();
    queue.close();
  });
  return (cache, queue);
});

/// This device's local store. Opened once per family and device: the keyring
/// and trust list can change underneath without reopening the databases.
final familyStoreProvider = FutureProvider<FamilyStore>((ref) async {
  final ids = await ref.watch(
    membershipProvider.selectAsync(
      (m) => m == null ? null : (m.familyId, m.deviceId, m.memberId),
    ),
  );
  if (ids == null) throw StateError('no family on this device yet');
  final (familyId, deviceId, memberId) = ids;
  final (cache, queue) = await ref.watch(localDatabasesProvider.future);

  // The keyring reloads when trust changes; sealing must never see it
  // mid-load. Hold the latest loaded one and follow later reloads.
  var keyring = await ref.read(keyringProvider.future);
  ref.listen(keyringProvider, (_, next) {
    if (next.value case final loaded?) keyring = loaded;
  });

  return FamilyStore(
    cache: cache,
    queue: queue,
    api: ref.watch(familyApiProvider),
    familyId: familyId,
    deviceId: deviceId,
    keyring: () => keyring,
    memberId: memberId,
  );
});

/// Keeps the store in step with the server: at start, after local edits, and
/// every [interval] while the app runs. Also collects new grants and
/// endorsements, so keys and devices added elsewhere arrive on their own.
/// Settings for this device alone (spec §5: two parents shouldn't fight over
/// one view). Never synced.
abstract interface class DevicePreferences {
  Future<String?> read(String name);

  Future<void> write(String name, String value);
}

final devicePreferencesProvider = FutureProvider<DevicePreferences>(
  (ref) async => _StorePreferences(await ref.watch(familyStoreProvider.future)),
);

/// Kept in the encrypted cache, beside the content they filter.
class _StorePreferences implements DevicePreferences {
  _StorePreferences(this._store);

  final FamilyStore _store;

  @override
  Future<String?> read(String name) => _store.devicePreference(name);

  @override
  Future<void> write(String name, String value) =>
      _store.setDevicePreference(name, value);
}

/// For tests, and anywhere preferences needn't outlive the process.
class MemoryPreferences implements DevicePreferences {
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async => values[name] = value;
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncReport?>(SyncController.new);

class SyncController extends AsyncNotifier<SyncReport?> {
  static const interval = Duration(seconds: 30);

  Timer? _timer;

  @override
  Future<SyncReport?> build() async {
    ref.onDispose(() => _timer?.cancel());
    await ref.watch(keyringProvider.future);
    _timer = Timer.periodic(interval, (_) => syncNow());
    return _run();
  }

  /// Syncs now; safe to call often, runs coalesce in the store.
  Future<void> syncNow() async {
    state = await AsyncValue.guard(_run);
  }

  Future<SyncReport?> _run() async {
    final store = await ref.read(familyStoreProvider.future);
    final report = await store.sync();
    await _learnKeysAndDevices(store);
    // Past the restore window, a deleted event goes for good; the deletion
    // itself syncs on the next run.
    await store.purgeDeleted();
    await _windUpHelpers(store);
    await _syncChat();
    await _fetchFeeds(store);
    await _closeDuePolls(store);
    await _planActions(store);
    return report;
  }

  DateTime? _plannedAt;

  /// Actions from templates, a month ahead, on a parent's device at most
  /// hourly (spec §3: a rolling window, never the whole season).
  Future<void> _planActions(FamilyStore store) async {
    if (!((await ref.read(membershipProvider.future))?.isParent ?? false)) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (_plannedAt != null && now.difference(_plannedAt!).inMinutes < 60) {
      return;
    }
    _plannedAt = now;
    try {
      await store.planActionsAhead(await ref.read(eventsProvider.future));
    } catch (e) {
      debugPrint('Planning actions failed: $e');
    }
  }

  /// Meal polls whose time is up close on a parent's device, so the result
  /// lands on the menu without anyone remembering to close them.
  Future<void> _closeDuePolls(FamilyStore store) async {
    if (!((await ref.read(membershipProvider.future))?.isParent ?? false)) {
      return;
    }
    try {
      await store.closeDuePolls();
    } catch (e) {
      debugPrint('Closing polls failed: $e');
    }
  }

  /// Linked calendars, on a parent's device (only parents can read the
  /// links). What they bring syncs on the next run.
  Future<void> _fetchFeeds(FamilyStore store) async {
    try {
      await ref.read(calendarFeedsProvider).refresh(store);
    } catch (e) {
      debugPrint('Calendar feeds failed: $e');
    }
  }

  /// The family thread: follow it, and on a parent's device keep its members
  /// in step with the family's devices.
  Future<void> _syncChat() async {
    try {
      await syncFamilyChat(ref.read);
    } catch (e) {
      debugPrint('Chat sync failed: $e');
    }
  }

  /// A helper whose time is up loses access without anyone remembering to
  /// take it away (spec §2).
  Future<void> _windUpHelpers(FamilyStore store) async {
    final membership = await ref.read(membershipProvider.future);
    if (membership == null) return;
    try {
      await ref
          .read(pairingServiceProvider)
          .expireHelpers(membership: membership, store: store);
    } catch (e) {
      debugPrint('Winding up helpers failed: $e');
    }
  }

  Future<void> _learnKeysAndDevices(FamilyStore store) async {
    final membership = await ref.read(membershipProvider.future);
    if (membership == null) return;
    final pairing = ref.read(pairingServiceProvider);
    try {
      final updated = await pairing.refreshTrust(membership);
      if (updated.trusted.length != membership.trusted.length) {
        await ref.read(membershipProvider.notifier).save(updated);
      }
      final device = await ref.read(deviceProvider.future);
      final keyring = await ref.read(keyringProvider.future);
      final added = await pairing.acceptNewGrants(updated, device, keyring);
      if (added > 0) await store.reopenUnreadable();
    } catch (e) {
      // Background upkeep: the next run tries again.
      debugPrint('Key and device refresh failed: $e');
    }
  }
}
