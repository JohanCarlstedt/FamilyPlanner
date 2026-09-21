import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../routing/router.dart';
import '../more/more_screen.dart';
import '../recovery/recovery_kit_flow.dart';

/// A few cards on a device's first run, before the app proper.
///
/// The founder has a setup flow; everyone who *joins* had nothing, and
/// was dropped onto Today with no idea what any of it was. That is most
/// of the household — one person starts the family and four more arrive
/// into an app nobody has explained.
///
/// Orientation, not configuration: what this is for, that nobody outside
/// the family can read it, and the one thing each person should do next.
/// Skippable, because a person who wants to get on with it should be
/// allowed to, and shown once per device.
class FirstRunGuide extends ConsumerStatefulWidget {
  const FirstRunGuide({super.key});

  static const path = '/guide';

  @override
  ConsumerState<FirstRunGuide> createState() => _FirstRunGuideState();
}

class _FirstRunGuideState extends ConsumerState<FirstRunGuide> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _done({String? then}) async {
    await ref.read(guideSeenProvider.notifier).seen();
    if (!mounted) return;
    final router = ref.read(routerProvider);
    router.go(then ?? '/today');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;

    final cards = <_Card>[
      _Card(
        icon: Icons.calendar_month_outlined,
        title: l10n.guideWeekTitle,
        body: l10n.guideWeekBody,
      ),
      _Card(
        icon: Icons.forum_outlined,
        title: l10n.guideTalkTitle,
        body: isParent ? l10n.guideTalkBodyParent : l10n.guideTalkBodyChild,
      ),
      _Card(
        icon: Icons.lock_outline,
        title: l10n.guidePrivacyTitle,
        body: l10n.guidePrivacyBody,
      ),
      // The last card is the one with something to do on it, and what that
      // is differs: a parent holds the way back into the family if every
      // phone is lost, a child does not.
      if (isParent)
        _Card(
          icon: Icons.vpn_key_outlined,
          title: l10n.guideKeyTitle,
          body: l10n.guideKeyBody,
          action: l10n.guideKeyAction,
          goes: '${MoreScreen.path}/${RecoveryKitScreen.segment}',
        )
      else
        _Card(
          icon: Icons.waving_hand_outlined,
          title: l10n.guideReadyTitle,
          body: l10n.guideReadyBody,
        ),
    ];

    final last = _page == cards.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _done,
                child: Text(l10n.guideSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: cards.length,
                itemBuilder: (context, i) => _CardView(card: cards[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: last
                        ? () => _done(then: cards[_page].goes)
                        : () => _pages.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    child: Text(
                      last ? (cards[_page].action ?? l10n.guideStart) : l10n.next,
                    ),
                  ),
                  if (last && cards[_page].action != null)
                    TextButton(
                      onPressed: _done,
                      child: Text(l10n.guideLater),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card {
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.goes,
  });

  final IconData icon;
  final String title;
  final String body;

  /// What the button says on the last card, when there is something to do.
  final String? action;

  /// Where that button goes instead of Today.
  final String? goes;
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card});

  final _Card card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(card.icon, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 32),
          Text(
            card.title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            card.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Whether this device has been shown the guide. Per device and never
/// synced: it is about the person holding this phone, not the family.
final guideSeenProvider =
    AsyncNotifierProvider<GuideSeenNotifier, bool>(GuideSeenNotifier.new);

class GuideSeenNotifier extends AsyncNotifier<bool> {
  static const _key = 'guide.seen.v1';

  @override
  Future<bool> build() async {
    final prefs = await ref.watch(devicePreferencesProvider.future);
    return await prefs.read(_key) == 'yes';
  }

  Future<void> seen() async {
    final prefs = await ref.read(devicePreferencesProvider.future);
    await prefs.write(_key, 'yes');
    state = const AsyncData(true);
  }
}
