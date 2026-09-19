import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';
import '../today/today_screen.dart';
import 'recovery_kit_flow.dart';

/// After recovering (crypto doc §7.3 steps 4–5): the words may have been
/// seen, so every group moves on without the kit's device, and new words
/// replace them.
class RecoveredScreen extends ConsumerStatefulWidget {
  const RecoveredScreen({super.key, required this.kitDeviceId});

  static const path = '/recovered';

  static String pathFor(String kitDeviceId) =>
      Uri(path: path, queryParameters: {'kit': kitDeviceId}).toString();

  final String kitDeviceId;

  @override
  ConsumerState<RecoveredScreen> createState() => _RecoveredScreenState();
}

class _RecoveredScreenState extends ConsumerState<RecoveredScreen> {
  var _secured = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _secure();
  }

  Future<void> _secure() async {
    setState(() => _error = null);
    try {
      final prefs = await ref.read(devicePreferencesProvider.future);
      await prefs.write(retireKitPreference, widget.kitDeviceId);
      // Names and roles first: the new adults key must reach every parent.
      await ref.read(syncControllerProvider.notifier).syncNow();
      final membership = (await ref.read(membershipProvider.future))!;
      final updated = await ref
          .read(pairingServiceProvider)
          .removeDevices(
            membership: membership,
            device: await ref.read(deviceProvider.future),
            keyring: await ref.read(keyringProvider.future),
            deviceIds: {widget.kitDeviceId},
            members: await ref.read(membersProvider.future),
          );
      await ref.read(membershipProvider.notifier).save(updated);
      final store = await ref.read(familyStoreProvider.future);
      await store.rewrapToLatest();
      await ref.read(syncControllerProvider.notifier).syncNow();
      await prefs.write(retireKitPreference, '');
      if (mounted) setState(() => _secured = true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: _secured
            ? RecoveryKitFlow(
                intro: l10n.recoveredNewWords,
                onDone: () => context.go(TodayScreen.path),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error == null) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.securing),
                      ] else ...[
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _secure,
                          child: Text(l10n.tryAgain),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
