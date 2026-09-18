import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../membership/membership.dart';
import '../devices/add_device_screen.dart';
import '../kitchen/kitchen_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const path = '/more';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          if (membership?.isParent ?? false)
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('Add a device'),
              subtitle: const Text(
                "A child's tablet, the other parent's phone",
              ),
              onTap: () =>
                  context.go('${MoreScreen.path}/${AddDeviceScreen.segment}'),
            ),
          ListTile(
            leading: const Icon(Icons.kitchen_outlined),
            title: const Text('Kitchen display'),
            onTap: () => context.push(KitchenScreen.path),
          ),
          if (membership != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: const Text('Trusted devices'),
              subtitle: Text(
                '${membership.trusted.length} in this family, this one included',
              ),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Planner, celebrations, meals, actions, map and family settings '
              'will live here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
