import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/family_api_provider.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';
import '../../pairing/unbind.dart';

/// Which member each of the family's devices belongs to, from the directory.
final deviceOwnersProvider = FutureProvider<Map<String, String>>((ref) async {
  final membership = await ref.watch(membershipProvider.future);
  if (membership == null) return const {};
  final directory = await ref
      .read(familyApiProvider)
      .directory(asDevice: membership.deviceId, familyId: membership.familyId);
  return {for (final d in directory) d.deviceId: d.memberId};
});

/// The devices this one trusts (crypto doc §2: pinned at pairing), and, for
/// a parent, removing one: it's revoked, and the family's keys move on
/// without it.
class TrustedDevicesScreen extends ConsumerStatefulWidget {
  const TrustedDevicesScreen({super.key});

  static const segment = 'devices';

  @override
  ConsumerState<TrustedDevicesScreen> createState() =>
      _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends ConsumerState<TrustedDevicesScreen> {
  String? _removing;

  Future<void> _remove(String deviceId, String label) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDeviceTitle(label)),
        content: Text(l10n.removeDeviceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = deviceId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final membership = (await ref.read(membershipProvider.future))!;
      final updated = await ref
          .read(pairingServiceProvider)
          .removeDevice(
            membership: membership,
            device: await ref.read(deviceProvider.future),
            keyring: await ref.read(keyringProvider.future),
            deviceId: deviceId,
            members: await ref.read(membersProvider.future),
          );
      await ref.read(membershipProvider.notifier).save(updated);
      // Recent content moves to the new keys now; the rest as it's written.
      final store = await ref.read(familyStoreProvider.future);
      await store.rewrapToLatest();
      await ref.read(syncControllerProvider.notifier).syncNow();
      ref.invalidate(deviceOwnersProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deviceRemoved)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.removeFailed('$e'))));
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  /// Leaving the family, from the phone doing the leaving. Asked plainly,
  /// because it cannot be undone from here: rejoining means pairing again
  /// from a device that is still in the family.
  Future<void> _unbindThisDevice() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unbindThisDevice),
        content: Text(l10n.unbindThisDeviceExplain),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.unbindConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = 'me');
    // Anything written here and not yet sent goes with it, so it is worth
    // one last attempt to hand it over before the keys are gone.
    try {
      await ref.read(syncControllerProvider.notifier).syncNow();
    } on Object {
      // Offline, or already refused: leaving anyway.
    }
    await ref.read(unbindProvider).thisDevice();
    if (mounted) setState(() => _removing = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    final owners = ref.watch(deviceOwnersProvider).value ?? const {};
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trustedDevices)),
      body: membership == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final d in membership.trusted)
                  () {
                    final me = d.deviceId == membership.deviceId;
                    final name = names[owners[d.deviceId]];
                    final label = name == null
                        ? l10n.someDevice
                        : l10n.deviceOf(name);
                    return ListTile(
                      leading: Icon(
                        me ? Icons.smartphone : Icons.devices_other_outlined,
                      ),
                      title: Text(label),
                      subtitle: Text(
                        me ? l10n.thisDevice : d.deviceId.substring(0, 8),
                      ),
                      trailing: me
                          // The device in your hand can leave on its own:
                          // given away, handed to someone else, or already
                          // removed by a parent and still holding a cache.
                          ? TextButton(
                              onPressed: _removing == null
                                  ? _unbindThisDevice
                                  : null,
                              child: Text(l10n.unbindThisDevice),
                            )
                          : !membership.isParent
                          ? null
                          : _removing == d.deviceId
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _removing == null
                                  ? () => _remove(d.deviceId, label)
                                  : null,
                              child: Text(l10n.removeDevice),
                            ),
                    );
                  }(),
              ],
            ),
    );
  }
}
