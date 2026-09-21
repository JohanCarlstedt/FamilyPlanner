import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/server_address.dart';
import '../../common/l10n.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';
import 'server_screen.dart';
import '../recovery/recover_screen.dart';

/// First run: found a family on this device, or join one by pairing code.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const path = '/welcome';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Quiet, and only here: after pairing the server can no longer change,
    // and a family on the hosted service never needs to think about it.
    final server = ref.watch(serverProvider);
    final isCustom = ref.watch(serverProvider.notifier).isCustom;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Family Planner',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.welcomeTagline,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => context.go(
                      '${WelcomeScreen.path}/${CreateFamilyScreen.segment}',
                    ),
                    child: Text(context.l10n.startFamily),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go(
                      '${WelcomeScreen.path}/${JoinFamilyScreen.segment}',
                    ),
                    child: Text(context.l10n.joinFamily),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(
                      '${WelcomeScreen.path}/${RecoverScreen.segment}',
                    ),
                    child: Text(context.l10n.recoverFamily),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => ServerDialog.show(context),
                    child: Text(
                      isCustom
                          ? context.l10n.serverUsing(server.host)
                          : context.l10n.serverOwn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
