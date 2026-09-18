import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your family a name.');
      return;
    }
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
      // Saving moves the router on to the app.
      await ref.read(membershipProvider.notifier).save(membership);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              "Couldn't create the family. Check the connection and try "
              'again.\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Start a new family')),
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
                  decoration: const InputDecoration(
                    labelText: 'Family name',
                    hintText: 'The Carlstedts',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _create(),
                ),
                const SizedBox(height: 8),
                // Honest about the one thing the server does read (crypto doc
                // §8 and the architecture doc's list of what the server sees).
                Text(
                  'The family name is the one thing our server can read. '
                  'Everything else you add is encrypted on this phone.',
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
                      : const Text('Create family'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
