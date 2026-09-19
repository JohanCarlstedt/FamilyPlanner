import 'package:flutter/material.dart';

import '../reminders/push.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/l10n.dart';
import '../data/store_providers.dart';

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
    // Re-tapping the current tab returns to the root of its stack.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reminders and push run while the app is in a family.
    ref.watch(pushProvider);
    // Watching keeps the controller, and its timer, alive.
    ref.watch(syncControllerProvider);
    final size = WindowSize.of(context);

    if (size == WindowSize.compact) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label(context.l10n),
              ),
          ],
        ),
      );
    }

    return Scaffold(
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
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label(context.l10n)),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
