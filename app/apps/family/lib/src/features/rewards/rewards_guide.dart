import 'package:flutter/material.dart';

import '../../common/l10n.dart';

/// What the rewards are and how they work, in words for whoever is reading.
///
/// A child who opened their city for the first time saw a map and a count
/// and had to work the rest out; a parent who turned the setting on had
/// no way to learn that homework only grows a child's city once they have
/// seen it done. Each gets the rules that are theirs to know: the child
/// how to build and grow, the parent what they control.
Future<void> showRewardsGuide(BuildContext context, {required bool forChild}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _Guide(forChild: forChild),
    );

/// What the family jar is, from a tap on the jar itself.
Future<void> showJarGuide(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.jarTitle, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 12),
            _Line('🫙', l10n.guideJarBody),
          ],
        ),
      ),
    ),
  );
}

class _Guide extends StatelessWidget {
  const _Guide({required this.forChild});

  final bool forChild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lines = forChild
        ? [
            ('🌱', l10n.guideCityEarn),
            ('👆', l10n.guideCityBuild),
            ('🏗️', l10n.guideCityToday),
            ('🏙️', l10n.guideCityGrow),
            ('🏫', l10n.guideCityLearn),
            ('🗺️', l10n.guideCityDistricts),
            ('🏛️', l10n.guideCityTrade),
            ('⚡', l10n.guideCityServices),
            ('🎪', l10n.guideCityLife),
            ('🎆', l10n.guideCityJar),
            ('💛', l10n.guideCityKeep),
          ]
        : [
            ('🫙', l10n.guideParentJar),
            ('🏙️', l10n.guideParentCity),
            ('✅', l10n.guideParentApproval),
            ('📚', l10n.guideParentSeen),
            ('💪', l10n.guideParentWorth),
            ('🎁', l10n.guideParentOwnCity),
            ('💛', l10n.guideParentKeep),
          ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              forChild ? l10n.guideCityTitle : l10n.guideParentTitle,
              style: theme.textTheme.titleLarge,
            ),
            if (!forChild) ...[
              const SizedBox(height: 8),
              Text(l10n.guideParentIntro, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 12),
            for (final (symbol, text) in lines) _Line(symbol, text),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.guideGotIt),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.symbol, this.text);

  final String symbol;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(symbol, style: const TextStyle(fontSize: 22)),
        ),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}
