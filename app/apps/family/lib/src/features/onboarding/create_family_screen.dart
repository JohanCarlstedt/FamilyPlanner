import 'package:domain/domain.dart';

import '../../common/l10n.dart';

import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/member_style.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';

/// Founds a family on this device, which becomes its first parent device.
class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  static const segment = 'create';

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _name = TextEditingController();
  final _yourName = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _yourName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final yourName = _yourName.text.trim();
    if (name.isEmpty || yourName.isEmpty) {
      setState(() => _error = context.l10n.namesRequired);
      return;
    }
    // Saving the membership moves the router on and disposes this screen, so
    // the profile is written through the app's container, not this widget.
    final container = ProviderScope.containerOf(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await ref.read(deviceProvider.future);
      final (membership, _) = await ref
          .read(pairingServiceProvider)
          .createFamily(
            device: device,
            name: name,
            // The family's zone drives recurrence; Swedish families first.
            timeZone: 'Europe/Stockholm',
          );
      await container.read(membershipProvider.notifier).save(membership);
      final store = await container.read(familyStoreProvider.future);
      await store.saveProfile(
        membership.memberId,
        MemberProfile.write(
          displayName: yourName,
          role: MemberRole.parent,
          color: MemberStyle.palette.first,
        ),
      );
      await container.read(syncControllerProvider.notifier).syncNow();
    } catch (e, stack) {
      // After the membership is saved this screen is gone; don't lose the error.
      debugPrint('Creating the family failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.createFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.startFamily)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.familyName,
                    hintText: l10n.familyNameHint,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _yourName,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.yourName,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _create(),
                ),
                const SizedBox(height: 8),
                // Honest about the one thing the server does read (crypto doc
                // §8 and the architecture doc's list of what the server sees).
                Text(
                  l10n.serverCanReadFamilyName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.createFamily),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
