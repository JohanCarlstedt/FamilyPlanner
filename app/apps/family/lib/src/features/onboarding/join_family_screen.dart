import 'dart:async';

import '../../common/l10n.dart';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';

/// The new device's side of pairing (crypto doc §7): show a code, wait for a
/// parent to scan it, then join from the admission.
class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  static const segment = 'join';

  /// How often to check the mailbox while the code is on screen.
  static const pollInterval = Duration(seconds: 2);

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  Device? _device;
  PairingSession? _session;
  Timer? _poll;
  bool _checking = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // The session holds the code's secret; it dies with this screen.
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final device = await ref.read(deviceProvider.future);
      if (!mounted) return;
      setState(() {
        _device = device;
        _session = PairingSession.start(device: device);
      });
      _poll = Timer.periodic(JoinFamilyScreen.pollInterval, (_) => _check());
    } catch (e) {
      if (mounted) {
        setState(() => _problem = context.l10n.keysFailed('$e'));
      }
    }
  }

  Future<void> _check() async {
    final session = _session;
    final device = _device;
    if (_checking || session == null || device == null) return;
    _checking = true;
    try {
      final membership = await ref
          .read(pairingServiceProvider)
          .checkMailbox(session, device);
      if (membership != null) {
        _poll?.cancel();
        // Saving moves the router on to the app.
        await ref.read(membershipProvider.notifier).save(membership);
        return;
      }
      if (_problem != null && mounted) setState(() => _problem = null);
    } catch (e) {
      // Keep polling: a phone on the move loses the connection now and then.
      if (mounted) {
        setState(() => _problem = context.l10n.serverUnreachable);
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinFamily)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.joinInstructions,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Center(
                  child: session == null
                      ? const SizedBox.square(
                          dimension: 280,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          // Always dark on light, whatever the theme: scanners
                          // read that most reliably.
                          color: Colors.white,
                          child: QrImageView(
                            data: session.code,
                            size: 280,
                            backgroundColor: Colors.white,
                            // Pairing codes use only QR alphanumeric characters.
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            semanticsLabel: l10n.pairingCode,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.waitingForScan,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (_problem != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _problem!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.codeWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
