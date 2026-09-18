import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/membership.dart';

/// Shown while this device's membership loads, or if it can't be read.
class StartingScreen extends ConsumerWidget {
  const StartingScreen({super.key});

  static const path = '/starting';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (membership) {
            AsyncError(:final error) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  "This device's family details couldn't be read.",
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Deliberately no "start over" button here: replacing a device
                // identity that exists but can't be read orphans the device
                // (crypto doc §2.1). That needs a person, not a tap.
                Text(
                  '$error',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(membershipProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
            _ => const CircularProgressIndicator(),
          },
        ),
      ),
    );
  }
}
