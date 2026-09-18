import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_screen.dart';
import '../features/devices/add_device_screen.dart';
import '../features/events/new_event_screen.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/more/more_screen.dart';
import '../features/onboarding/create_family_screen.dart';
import '../features/onboarding/join_family_screen.dart';
import '../features/onboarding/starting_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/shopping/shopping_screen.dart';
import '../features/today/today_screen.dart';
import '../features/week/week_screen.dart';
import '../membership/membership.dart';
import '../shell/adaptive_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever membership changes: creating or joining a
  // family moves this device from onboarding into the app.
  final membershipChanged = ValueNotifier(0);
  ref.listen(membershipProvider, (_, _) => membershipChanged.value++);
  ref.onDispose(membershipChanged.dispose);

  final router = GoRouter(
    initialLocation: TodayScreen.path,
    refreshListenable: membershipChanged,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onboarding = location.startsWith(WelcomeScreen.path);
      return switch (ref.read(membershipProvider)) {
        // Not in a family yet: everything leads to onboarding.
        AsyncData(value: null) => onboarding ? null : WelcomeScreen.path,
        // In a family: onboarding is behind us.
        AsyncData() =>
          onboarding || location == StartingScreen.path
              ? TodayScreen.path
              : null,
        // Loading, or the stored identity can't be read.
        _ => location == StartingScreen.path ? null : StartingScreen.path,
      };
    },
    routes: [
      GoRoute(
        path: StartingScreen.path,
        builder: (context, state) => const StartingScreen(),
      ),
      GoRoute(
        path: WelcomeScreen.path,
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: CreateFamilyScreen.segment,
            builder: (context, state) => const CreateFamilyScreen(),
          ),
          GoRoute(
            path: JoinFamilyScreen.segment,
            builder: (context, state) => const JoinFamilyScreen(),
          ),
        ],
      ),
      // One branch per destination so each tab keeps its own stack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TodayScreen.path,
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: NewEventScreen.segment,
                    builder: (context, state) => const NewEventScreen(),
                  ),
                ],
              ),
            ],
          ),
          _branch(WeekScreen.path, const WeekScreen()),
          _branch(ChatScreen.path, const ChatScreen()),
          _branch(ShoppingScreen.path, const ShoppingScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MoreScreen.path,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: AddDeviceScreen.segment,
                    builder: (context, state) => const AddDeviceScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // The kitchen display is its own route outside the shell: a
      // device-scoped session, not a member login (architecture doc §4).
      GoRoute(
        path: KitchenScreen.path,
        builder: (context, state) => const KitchenScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}
