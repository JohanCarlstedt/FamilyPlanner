import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../billing/premium_screen.dart';
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
import '../people/wishlists_screen.dart';
import '../polls/polls_screen.dart';
import '../rewards/rewards_providers.dart';
import '../rewards/world_screen.dart';
import '../review/weekly_review_screen.dart';
import '../places/places_screen.dart';
import 'recently_deleted_screen.dart';
import '../about/about_screen.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../membership/membership.dart';
import '../devices/add_device_screen.dart';
import '../kitchen/kitchen_screen.dart';

/// Everything that is not one of the four tabs.
///
/// Grouped rather than listed. It had grown to twenty entries in one flat
/// run, which is long enough that nothing is findable unless you already
/// know it is there — the gift lists were in it nowhere at all, reachable
/// only by typing a name into search, and the family reasonably concluded
/// the feature did not exist.
///
/// Headings are chosen by what someone is trying to do, not by what the
/// code calls things: "Settings" holds what is configured once, "The
/// week" holds what is touched constantly.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const path = '/more';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider).value;
    final parent = membership?.isParent ?? false;
    final l10n = context.l10n;

    ListTile go(
      IconData icon,
      String title,
      String? subtitle,
      String segment,
    ) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => context.go('${MoreScreen.path}/$segment'),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Heading(l10n.moreGroupWeek),
          go(
            Icons.checklist_outlined,
            l10n.todos,
            l10n.todosSubtitle,
            ActionsScreen.segment,
          ),
          go(
            Icons.menu_book_outlined,
            l10n.homework,
            l10n.homeworkSubtitle,
            HomeworkScreen.segment,
          ),
          go(
            Icons.luggage_outlined,
            l10n.away,
            l10n.awaySubtitle,
            AwayScreen.segment,
          ),
          go(
            Icons.how_to_vote_outlined,
            l10n.polls,
            l10n.pollsSubtitle,
            PollsScreen.segment,
          ),
          go(
            Icons.insights_outlined,
            l10n.weeklyReview,
            l10n.weeklyReviewSubtitle,
            WeeklyReviewScreen.segment,
          ),

          _Heading(l10n.moreGroupPeople),
          go(
            Icons.people_outline,
            l10n.members,
            l10n.membersSubtitle,
            MembersScreen.segment,
          ),
          go(
            Icons.cake_outlined,
            l10n.celebrations,
            l10n.celebrationsSubtitle,
            CelebrationsScreen.segment,
          ),
          // New here, and the reason this screen was regrouped: the lists
          // and their hidden claims already worked, and nothing pointed at
          // them.
          go(
            Icons.card_giftcard_outlined,
            l10n.wishlists,
            l10n.wishlistsSubtitle,
            WishlistsScreen.segment,
          ),
          go(
            Icons.home_outlined,
            l10n.custody,
            l10n.custodySubtitle,
            CustodyScreen.segment,
          ),
          // Spec section 3, "Contributions", and only when the family has
          // turned it on. A child gets their own world; a parent gets the
          // children, by name, and never their levels side by side.
          // A child, specifically: anyone who is not a parent also
          // includes a babysitter paired as a helper, who has no world.
          if (ref.watch(rewardsOnProvider) &&
              membership != null &&
              (parent || isChild(ref, membership.memberId)))
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(parent ? l10n.childrensWorlds : l10n.myWorld),
              subtitle: parent ? null : Text(l10n.myWorldSubtitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => parent
                      ? const ChildrensWorldsScreen()
                      : WorldScreen(memberId: membership.memberId),
                ),
              ),
            ),

          _Heading(l10n.moreGroupPlaces),
          go(
            Icons.map_outlined,
            l10n.familyMap,
            l10n.familyMapSubtitle,
            MapScreen.segment,
          ),
          go(
            Icons.place_outlined,
            l10n.places,
            l10n.placesSubtitle,
            PlacesScreen.segment,
          ),

          _Heading(l10n.moreGroupIntegrations),
          if (parent)
            go(
              Icons.event_repeat_outlined,
              l10n.linkedCalendars,
              l10n.linkedCalendarsSubtitle,
              LinkedCalendarsScreen.segment,
            ),
          if (parent)
            go(
              Icons.school_outlined,
              l10n.schoolPlans,
              l10n.schoolPlansSubtitle,
              SchoolPlansScreen.segment,
            ),
          go(
            Icons.phone_iphone,
            l10n.phoneCalendars,
            l10n.phoneCalendarsSubtitle,
            PhoneCalendarsScreen.segment,
          ),

          _Heading(l10n.moreGroupDevices),
          if (parent)
            go(
              Icons.add_to_home_screen,
              l10n.addDevice,
              l10n.addDeviceSubtitle,
              AddDeviceScreen.segment,
            ),
          if (membership != null)
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: Text(l10n.trustedDevices),
              subtitle: Text(
                l10n.trustedDevicesCount(membership.trusted.length),
              ),
              onTap: () => context.go(
                '${MoreScreen.path}/${TrustedDevicesScreen.segment}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.kitchen_outlined),
            title: Text(l10n.kitchenDisplay),
            onTap: () => context.push(KitchenScreen.path),
          ),

          _Heading(l10n.moreGroupSettings),
          if (parent)
            go(
              Icons.tune,
              l10n.familySettings,
              l10n.familySettingsSubtitle,
              FamilySettingsScreen.segment,
            ),
          go(
            Icons.lock_outline,
            l10n.passwords,
            l10n.passwordsSubtitle,
            PasswordsScreen.segment,
          ),
          if (parent)
            go(
              Icons.key_outlined,
              l10n.recoveryKit,
              l10n.recoveryKitSubtitle,
              RecoveryKitScreen.segment,
            ),
          if (parent)
            go(
              Icons.workspace_premium_outlined,
              l10n.premium,
              l10n.premiumSubtitle,
              PremiumScreen.segment,
            ),
          go(
            Icons.restore_from_trash_outlined,
            l10n.recentlyDeleted,
            l10n.recentlyDeletedSubtitle,
            RecentlyDeletedScreen.segment,
          ),
          // For everyone, children too: the version, what's new, and ideas
          // and bug reports for the developer.
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutTitle),
            subtitle: Text(l10n.aboutFeedback),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether [memberId] is one of the family's children.
bool isChild(WidgetRef ref, String memberId) =>
    (ref.watch(membersProvider).value ?? const <Member>[])
        .any((m) => m.id == memberId && m.isChild);

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
