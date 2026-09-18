import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_screen.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/more/more_screen.dart';
import '../features/shopping/shopping_screen.dart';
import '../features/today/today_screen.dart';
import '../features/week/week_screen.dart';
import '../shell/adaptive_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: TodayScreen.path,
    routes: [
      // One branch per destination so each tab keeps its own stack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(shell: shell),
        branches: [
          _branch(TodayScreen.path, const TodayScreen()),
          _branch(WeekScreen.path, const WeekScreen()),
          _branch(ChatScreen.path, const ChatScreen()),
          _branch(ShoppingScreen.path, const ShoppingScreen()),
          _branch(MoreScreen.path, const MoreScreen()),
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
