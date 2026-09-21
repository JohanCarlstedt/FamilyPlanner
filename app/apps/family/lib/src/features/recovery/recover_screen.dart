import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/server_address.dart';
import '../../common/l10n.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';
import '../../routing/router.dart';
import 'recovered_screen.dart';

/// Welcome > Recover with my twelve words (crypto doc §7.3 steps 1–3).
class RecoverScreen extends ConsumerStatefulWidget {
  const RecoverScreen({super.key});

  static const segment = 'recover';

  @override
  ConsumerState<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends ConsumerState<RecoverScreen> {
  final _words = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final container = ProviderScope.containerOf(context);
    try {
      final phone = await ref.read(deviceProvider.future);
      final (membership, kitDeviceId) = await ref
          .read(pairingServiceProvider)
          .recover(
            words: _words.text,
            phone: phone,
            // A client that signs as the words' device, for acting as it.
            kitApi: (kit) => FamilyApi(
              // The same server the rest of the app is talking to: a
              // family that self-hosts recovers from its own machine.
              ref.read(serverProvider),
              signer: (deviceId, method, target, timestamp, body) async =>
                  kit.signRequest(
                    deviceId: deviceId,
                    method: method,
                    pathAndQuery: target,
                    timestampMs: BigInt.from(timestamp),
                    body: body,
                  ),
            ),
          );
      await container.read(membershipProvider.notifier).save(membership);
      container.read(routerProvider).go(RecoveredScreen.pathFor(kitDeviceId));
    } on RecoveryNotFound {
      if (mounted) setState(() => _error = l10n.recoverNotFound);
    } on CryptoException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.kind == CryptoErrorKind.malformed
              ? l10n.recoverBadWords
              : l10n.recoverFailed(e.message),
        );
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = l10n.recoverFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoverTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.recoverHelp, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _words,
            enabled: !_busy,
            minLines: 3,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _recover,
            child: _busy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.recovering),
                    ],
                  )
                : Text(l10n.recover),
          ),
        ],
      ),
    );
  }
}
