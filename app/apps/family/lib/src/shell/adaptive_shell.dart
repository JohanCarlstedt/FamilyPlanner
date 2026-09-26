import 'package:flutter/material.dart';

import '../reminders/push.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../chat/chat_providers.dart';
import '../common/l10n.dart';
import '../data/store_providers.dart';
import '../features/polls/open_polls.dart';
import '../features/shopping/share_import.dart';
import '../location/location_providers.dart';
import '../routing/tab_navigators.dart';
import '../common/whats_new.dart';

/// Window size classes from architecture doc §4 "Adaptive shells".
///
/// Driven by available width, never by device type, so split view on an iPad
/// gets the same layout as a phone of the same width.
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return WindowSize.compact;
    if (width < 840) return WindowSize.medium;
    return WindowSize.expanded;
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String Function(AppLocalizations) label;
  final IconData icon;
  final IconData selectedIcon;
}

// Order matches the shell branches in routing/router.dart.
const _destinations = [
  _Destination(_today, Icons.today_outlined, Icons.today),
  _Destination(
    _week,
    Icons.calendar_view_week_outlined,
    Icons.calendar_view_week,
  ),
  _Destination(_chat, Icons.chat_bubble_outline, Icons.chat_bubble),
  _Destination(_shopping, Icons.shopping_cart_outlined, Icons.shopping_cart),
  _Destination(_more, Icons.menu, Icons.menu_open),
];

/// A tab's icon with however many things are waiting on it, or plain when
/// there are none. A count rather than a dot: "three waiting" and
/// "something happened" are different amounts of reason to look.
Widget _badged(int index, Widget icon, Map<int, int> waiting) =>
    switch (waiting[index]) {
      null || 0 => icon,
      final n => Badge.count(count: n, child: icon),
    };

/// Which destination carries which count. Beside the list rather than a
/// number somewhere else, so reordering the tabs cannot silently put the
/// badge on the shopping trolley.
const _chatTab = 2;

/// Questions live under More, which is exactly why they need a number on
/// it: a poll that closes tonight is not something anyone will find by
/// opening a menu on the off-chance.
const _moreTab = 4;

String _today(AppLocalizations l) => l.tabToday;
String _week(AppLocalizations l) => l.tabWeek;
String _chat(AppLocalizations l) => l.tabChat;
String _shopping(AppLocalizations l) => l.tabShopping;
String _more(AppLocalizations l) => l.tabMore;

/// Bottom navigation on phones, a navigation rail on tablets. Keeps sync
/// running while the app is in a family.
class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) {
    // Re-tapping the current tab returns to the root of its stack: every
    // page and sheet opened on top is closed too, the easy way out of
    // whatever is open.
    if (index == shell.currentIndex) {
      tabNavigators[index].currentState?.popUntil((r) => r.isFirst);
    }
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reminders and push run while the app is in a family.
    ref.watch(pushProvider);
    // Watching keeps the controller, and its timer, alive.
    ref.watch(syncControllerProvider);
    // Shares this member's position while the app is open, if they chose to.
    ref.watch(locationReporterProvider);
    // Everything unread, across every conversation this device is in.
    final unread = ref
        .watch(conversationsProvider)
        .value
        ?.fold<int>(0, (sum, c) => sum + c.unread);
    final waiting = <int, int>{
      _chatTab: unread ?? 0,
      _moreTab: ref.watch(awaitingAnswerProvider).length,
    };
    final size = WindowSize.of(context);

    if (size == WindowSize.compact) {
      return WhatsNew(
        child: ShareImport(
          child: Scaffold(
            body: shell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final (i, d) in _destinations.indexed)
                  NavigationDestination(
                    icon: _badged(i, Icon(d.icon), waiting),
                    selectedIcon: _badged(i, Icon(d.selectedIcon), waiting),
                    label: d.label(context.l10n),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return WhatsNew(
      child: ShareImport(
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _select,
                extended: size == WindowSize.expanded,
                labelType: size == WindowSize.expanded
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final (i, d) in _destinations.indexed)
                    NavigationRailDestination(
                      icon: _badged(i, Icon(d.icon), waiting),
                      selectedIcon: _badged(i, Icon(d.selectedIcon), waiting),
                      label: Text(d.label(context.l10n)),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: shell),
            ],
          ),
        ),
      ),
    );
  }
}
