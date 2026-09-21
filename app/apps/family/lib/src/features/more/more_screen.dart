import 'package:flutter/material.dart';

import '../recovery/recovery_kit_flow.dart';
import '../devices/trusted_devices_screen.dart';
import '../members/members_screen.dart';
import '../settings/family_settings_screen.dart';
import '../integrations/linked_calendars_screen.dart';
import '../integrations/phone_calendars_screen.dart';
import '../integrations/school_plans_screen.dart';
import '../actions/actions_screen.dart';
import '../away/away_screen.dart';
import '../custody/custody_screen.dart';
import '../map/map_screen.dart';
import '../passwords/passwords_screen.dart';
import '../homework/homework_screen.dart';
import '../people/celebrations_screen.dart';
import '../review/weekly_review_screen.dart';
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
              leading: const Icon(Icons.key_outlined),
              title: Text(l10n.recoveryKit),
              subtitle: Text(l10n.recoveryKitSubtitle),
              onTap: () =>
                  context.go('${MoreScreen.path}/${RecoveryKitScreen.segment}'),
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
            leading: const Icon(Icons.task_alt),
            title: Text(l10n.todos),
            subtitle: Text(l10n.todosSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${ActionsScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.passwords),
            subtitle: Text(l10n.passwordsSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${PasswordsScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.familyMap),
            subtitle: Text(l10n.familyMapSubtitle),
            onTap: () => context.go('${MoreScreen.path}/${MapScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: Text(l10n.custody),
            subtitle: Text(l10n.custodySubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${CustodyScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.luggage_outlined),
            title: Text(l10n.away),
            subtitle: Text(l10n.awaySubtitle),
            onTap: () => context.go('${MoreScreen.path}/${AwayScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(l10n.homework),
            subtitle: Text(l10n.homeworkSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${HomeworkScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: Text(l10n.celebrations),
            subtitle: Text(l10n.celebrationsSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${CelebrationsScreen.segment}'),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rtl),
            title: Text(l10n.weeklyReview),
            subtitle: Text(l10n.weeklyReviewSubtitle),
            onTap: () =>
                context.go('${MoreScreen.path}/${WeeklyReviewScreen.segment}'),
          ),
          if (membership?.isParent ?? false)
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: Text(l10n.linkedCalendars),
              subtitle: Text(l10n.linkedCalendarsSubtitle),
              onTap: () => context.go(
                '${MoreScreen.path}/${LinkedCalendarsScreen.segment}',
              ),
            ),
          if (membership?.isParent ?? false)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(l10n.schoolPlans),
              subtitle: Text(l10n.schoolPlansSubtitle),
              onTap: () => context.go(
                '${MoreScreen.path}/${SchoolPlansScreen.segment}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.phone_iphone),
            title: Text(l10n.phoneCalendars),
            subtitle: Text(l10n.phoneCalendarsSubtitle),
            onTap: () => context.go(
              '${MoreScreen.path}/${PhoneCalendarsScreen.segment}',
            ),
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
        ],
      ),
    );
  }
}
