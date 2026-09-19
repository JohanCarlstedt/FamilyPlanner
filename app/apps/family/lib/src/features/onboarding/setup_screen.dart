import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../members/members_screen.dart';
import '../recovery/recovery_kit_flow.dart';
import '../today/today_screen.dart';

/// The founder's first minutes in a new family (spec §9 "Getting to a useful
/// first week"): children before anything else, then what the encryption
/// means, said once and plainly.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  static const path = '/setup';

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        l10n.setupWhoTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.setupWhoBody, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      for (final (i, m) in members.indexed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: MemberStyle.colorOf(m, i),
                          ),
                          title: Text(m.displayName),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => editMember(context, ref),
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: Text(l10n.addChild),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.setupPrivacyTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.setupPrivacyBody,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  // Spec §9 step 7: setup isn't finished until the words
                  // are written down and checked.
                  RecoveryKitFlow(onDone: () => context.go(TodayScreen.path)),
                ],
              ),
            ),
            if (_page < 2)
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _next, child: Text(l10n.next)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
