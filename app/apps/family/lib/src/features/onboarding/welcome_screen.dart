import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../common/l10n.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';
import '../recovery/recover_screen.dart';

/// First run: found a family on this device, or join one by pairing code.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const path = '/welcome';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
