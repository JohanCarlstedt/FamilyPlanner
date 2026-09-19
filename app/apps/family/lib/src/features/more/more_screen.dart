import 'package:flutter/material.dart';

import '../devices/trusted_devices_screen.dart';
import '../members/members_screen.dart';
import '../settings/family_settings_screen.dart';
import '../places/places_screen.dart';
import 'recently_deleted_screen.dart';
import '../../common/l10n.dart';

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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        children: [
          if (membership?.isParent ?? false)
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: Text(l10n.addDevice),
              subtitle: Text(l10n.addDeviceSubtitle),
              onTap: () =>
                  context.go('${MoreScreen.path}/${AddDeviceScreen.segment}'),
            ),
          if (membership?.isParent ?? false)
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.familySettings),
              subtitle: Text(l10n.familySettingsSubtitle),
              onTap: () => context.go(
                '${MoreScreen.path}/${FamilySettingsScreen.segment}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l10n.members),
            subtitle: Text(l10n.membersSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${MembersScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.places),
            subtitle: Text(l10n.placesSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${PlacesScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: Text(l10n.recentlyDeleted),
            subtitle: Text(l10n.recentlyDeletedSubtitle),
            onTap: () => context.go(
              '${MoreScreen.path}/${RecentlyDeletedScreen.segment}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.kitchen_outlined),
            title: Text(l10n.kitchenDisplay),
            onTap: () => context.push(KitchenScreen.path),
          ),
          if (membership != null) ...[
            const Divider(),
            ListTile(
              onTap: () => context.go(
                '${MoreScreen.path}/${TrustedDevicesScreen.segment}',
              ),
              leading: const Icon(Icons.devices_outlined),
              title: Text(l10n.trustedDevices),
              subtitle: Text(
                l10n.trustedDevicesCount(membership.trusted.length),
              ),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.moreComingSoon,
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
