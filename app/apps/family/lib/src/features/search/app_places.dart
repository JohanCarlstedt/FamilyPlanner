import 'package:flutter/material.dart';

import '../../common/l10n.dart';
import '../actions/actions_screen.dart';
import '../away/away_screen.dart';
import '../billing/premium_screen.dart';
import '../custody/custody_screen.dart';
import '../devices/add_device_screen.dart';
import '../devices/trusted_devices_screen.dart';
import '../homework/homework_screen.dart';
import '../integrations/linked_calendars_screen.dart';
import '../integrations/phone_calendars_screen.dart';
import '../integrations/school_plans_screen.dart';
import '../map/map_screen.dart';
import '../members/members_screen.dart';
import '../more/more_screen.dart';
import '../more/recently_deleted_screen.dart';
import '../passwords/passwords_screen.dart';
import '../people/celebrations_screen.dart';
import '../people/wishlists_screen.dart';
import '../places/places_screen.dart';
import '../polls/polls_screen.dart';
import '../recovery/recovery_kit_flow.dart';
import '../review/weekly_review_screen.dart';
import '../settings/family_settings_screen.dart';

/// A place in the app a search can take someone straight to: a screen,
/// or the settings screen by any setting on it.
class AppPlace {
  const AppPlace({
    required this.icon,
    required this.title,
    required this.path,
    this.subtitle,
    this.words = const [],
    this.parentsOnly = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// What else finds it: the settings on it, and the everyday words for
  /// them ("el", "ström" for the electricity price), in the reader's
  /// language.
  final List<String> words;
  final String path;

  /// Shown only to a parent: a child cannot open it, so offering it is a
  /// dead end.
  final bool parentsOnly;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return false;
    return [title, ?subtitle, ...words].any((w) => w.toLowerCase().contains(q));
  }
}

List<String> _words(String list) => [
  for (final w in list.split(','))
    if (w.trim().isNotEmpty) w.trim(),
];

/// Everywhere More leads, in the reader's language.
List<AppPlace> appPlaces(AppLocalizations l10n) {
  String more(String segment) => '${MoreScreen.path}/$segment';
  return [
    AppPlace(
      icon: Icons.tune,
      title: l10n.familySettings,
      subtitle: l10n.familySettingsSubtitle,
      path: more(FamilySettingsScreen.segment),
      parentsOnly: true,
      words: [
        l10n.quietHours,
        l10n.morningDigest,
        l10n.gettingReady,
        l10n.messageSupervision,
        l10n.electricityShow,
        l10n.rewardsOn,
        l10n.jarSize,
        l10n.testReminder,
        ..._words(l10n.searchWordsSettings),
      ],
    ),
    AppPlace(
      icon: Icons.phone_iphone,
      title: l10n.phoneCalendars,
      subtitle: l10n.phoneCalendarsSubtitle,
      path: more(PhoneCalendarsScreen.segment),
      words: _words(l10n.searchWordsCalendars),
    ),
    AppPlace(
      icon: Icons.event_repeat_outlined,
      title: l10n.linkedCalendars,
      subtitle: l10n.linkedCalendarsSubtitle,
      path: more(LinkedCalendarsScreen.segment),
      parentsOnly: true,
      words: _words(l10n.searchWordsCalendars),
    ),
    AppPlace(
      icon: Icons.school_outlined,
      title: l10n.schoolPlans,
      subtitle: l10n.schoolPlansSubtitle,
      path: more(SchoolPlansScreen.segment),
      parentsOnly: true,
    ),
    AppPlace(
      icon: Icons.map_outlined,
      title: l10n.familyMap,
      subtitle: l10n.familyMapSubtitle,
      path: more(MapScreen.segment),
      words: _words(l10n.searchWordsMap),
    ),
    AppPlace(
      icon: Icons.place_outlined,
      title: l10n.places,
      subtitle: l10n.placesSubtitle,
      path: more(PlacesScreen.segment),
    ),
    AppPlace(
      icon: Icons.home_outlined,
      title: l10n.custody,
      subtitle: l10n.custodySubtitle,
      path: more(CustodyScreen.segment),
      words: _words(l10n.searchWordsCustody),
    ),
    AppPlace(
      icon: Icons.checklist_outlined,
      title: l10n.todos,
      subtitle: l10n.todosSubtitle,
      path: more(ActionsScreen.segment),
    ),
    AppPlace(
      icon: Icons.menu_book_outlined,
      title: l10n.homework,
      subtitle: l10n.homeworkSubtitle,
      path: more(HomeworkScreen.segment),
    ),
    AppPlace(
      icon: Icons.luggage_outlined,
      title: l10n.away,
      subtitle: l10n.awaySubtitle,
      path: more(AwayScreen.segment),
    ),
    AppPlace(
      icon: Icons.how_to_vote_outlined,
      title: l10n.polls,
      subtitle: l10n.pollsSubtitle,
      path: more(PollsScreen.segment),
    ),
    AppPlace(
      icon: Icons.insights_outlined,
      title: l10n.weeklyReview,
      subtitle: l10n.weeklyReviewSubtitle,
      path: more(WeeklyReviewScreen.segment),
    ),
    AppPlace(
      icon: Icons.people_outline,
      title: l10n.members,
      subtitle: l10n.membersSubtitle,
      path: more(MembersScreen.segment),
    ),
    AppPlace(
      icon: Icons.cake_outlined,
      title: l10n.celebrations,
      subtitle: l10n.celebrationsSubtitle,
      path: more(CelebrationsScreen.segment),
    ),
    AppPlace(
      icon: Icons.card_giftcard_outlined,
      title: l10n.wishlists,
      subtitle: l10n.wishlistsSubtitle,
      path: more(WishlistsScreen.segment),
    ),
    AppPlace(
      icon: Icons.add_to_home_screen,
      title: l10n.addDevice,
      subtitle: l10n.addDeviceSubtitle,
      path: more(AddDeviceScreen.segment),
      parentsOnly: true,
      words: _words(l10n.searchWordsDevices),
    ),
    AppPlace(
      icon: Icons.devices_outlined,
      title: l10n.trustedDevices,
      path: more(TrustedDevicesScreen.segment),
      words: _words(l10n.searchWordsDevices),
    ),
    AppPlace(
      icon: Icons.lock_outline,
      title: l10n.passwords,
      subtitle: l10n.passwordsSubtitle,
      path: more(PasswordsScreen.segment),
      words: _words(l10n.searchWordsPasswords),
    ),
    AppPlace(
      icon: Icons.key_outlined,
      title: l10n.recoveryKit,
      subtitle: l10n.recoveryKitSubtitle,
      path: more(RecoveryKitScreen.segment),
      parentsOnly: true,
    ),
    AppPlace(
      icon: Icons.workspace_premium_outlined,
      title: l10n.premium,
      subtitle: l10n.premiumSubtitle,
      path: more(PremiumScreen.segment),
      parentsOnly: true,
    ),
    AppPlace(
      icon: Icons.restore_from_trash_outlined,
      title: l10n.recentlyDeleted,
      subtitle: l10n.recentlyDeletedSubtitle,
      path: more(RecentlyDeletedScreen.segment),
    ),
  ];
}

/// The places [query] finds, for someone who is or is not a parent.
List<AppPlace> findPlaces(
  AppLocalizations l10n,
  String query, {
  required bool parent,
}) => [
  for (final p in appPlaces(l10n))
    if ((parent || !p.parentsOnly) && p.matches(query)) p,
];
