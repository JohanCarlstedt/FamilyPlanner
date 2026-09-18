import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

// Order matches the shell branches in routing/router.dart.
const _destinations = [
  _Destination('Today', Icons.today_outlined, Icons.today),
  _Destination(
    'Week',
    Icons.calendar_view_week_outlined,
    Icons.calendar_view_week,
  ),
  _Destination('Chat', Icons.chat_bubble_outline, Icons.chat_bubble),
  _Destination('Shopping', Icons.shopping_cart_outlined, Icons.shopping_cart),
  _Destination('More', Icons.menu, Icons.menu_open),
];

/// Bottom navigation on phones, a navigation rail on tablets.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) {
    // Re-tapping the current tab returns to the root of its stack.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
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
                label: d.label,
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
                  label: Text(d.label),
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
