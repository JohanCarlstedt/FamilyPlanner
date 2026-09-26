import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../api/family_api_provider.dart';
import '../api/server_address.dart';
import '../membership/membership.dart';

/// Takes this device out of the family it belongs to.
///
/// Three reasons a phone needs this: it is being given away or sold, it is
/// being handed to a different person in the family, or a parent has
/// already revoked it and it is still sitting there showing everything it
/// had cached.
///
/// What it does, in order, so a failure at any step still leaves the phone
/// safe rather than half in:
///
/// 1. Tells the server, if it can. A revoked device is refused everywhere,
///    and the family's keys move on without it.
/// 2. Forgets the identity. Without it the phone cannot claim to be that
///    device again, even if the files came back.
/// 3. Deletes the local databases — the decrypted cache and the queue of
///    unsent edits, which is the copy that actually matters on a phone
///    someone else is about to hold.
///
/// What it cannot do is unsee: whatever was read on this phone has been
/// read. Nor does it reach the family's other devices — their keys carry
/// on, which is the point.
///
/// **Unsent edits are lost.** The queue holds what this device wrote and
/// has not managed to sync, and a device on its way out of the family has
/// nowhere left to send it. Sync first if that matters.
class Unbind {
  const Unbind(this._ref);

  final Ref _ref;

  /// Removes this device from the family and wipes it.
  ///
  /// [alreadyRevoked] skips the server call, for the case where the server
  /// is the one that told us: a device the family removed cannot revoke
  /// itself, since every request it makes is refused.
  Future<void> thisDevice({bool alreadyRevoked = false}) async {
    final membership = _ref.read(membershipProvider).value;

    if (!alreadyRevoked && membership != null) {
      try {
        await _ref
            .read(familyApiProvider)
            .revokeDevice(
              asDevice: membership.deviceId,
              deviceId: membership.deviceId,
            );
      } on Object catch (e) {
        // A phone with no signal, or one the family already removed. It is
        // leaving either way: the local half is what protects the person
        // holding it, and it is the half we can always do.
        debugPrint('Could not tell the server this device is leaving: $e');
      }
    }

    await _ref.read(deviceVaultProvider).forget();
    await _ref.read(membershipStoreProvider).clear();
    // Released with the identity it belonged to: whoever sets this phone
    // up next may be joining a different family on a different server.
    await _ref.read(serverProvider.notifier).forget();
    await _wipeLocalData();

    // Rebuilt from nothing: the app is back where a fresh install starts.
    _ref.invalidate(membershipProvider);
  }

  /// The decrypted cache and the command queue. Deleted rather than
  /// emptied: a file that is gone cannot be recovered from, and the next
  /// start makes new ones.
  Future<void> _wipeLocalData() async {
    try {
      final dir = await getApplicationSupportDirectory();
      for (final name in const [
        'cache-v1.db',
        'queue-v1.db',
        // WAL mode's log and index beside each.
        'cache-v1.db-wal',
        'cache-v1.db-shm',
        'queue-v1.db-wal',
        'queue-v1.db-shm',
        // Set aside earlier by the key check; they belong to an identity
        // this device no longer has either.
        'cache-v1.db.unreadable',
        'queue-v1.db.unreadable',
      ]) {
        final file = File('${dir.path}/$name');
        if (file.existsSync()) await file.delete();
      }
    } on Object catch (e) {
      debugPrint('Local data not fully removed: $e');
    }
  }
}

final unbindProvider = Provider<Unbind>(Unbind.new);
