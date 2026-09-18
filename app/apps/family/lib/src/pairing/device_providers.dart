import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../membership/membership.dart';
import 'pairing_service.dart';

/// This install's identity, created on first use (crypto doc §2.1).
final deviceProvider = FutureProvider<Device>(
  (ref) => ref.watch(deviceVaultProvider).loadOrCreate(),
);

/// The group keys this device holds, rebuilt from its grants on the server.
final keyringProvider = FutureProvider<Keyring>((ref) async {
  final membership = await ref.watch(membershipProvider.future);
  if (membership == null) return Keyring();
  final device = await ref.watch(deviceProvider.future);
  return ref.watch(pairingServiceProvider).loadKeyring(membership, device);
});
