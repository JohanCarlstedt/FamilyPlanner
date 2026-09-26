import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import 'city_words.dart';
import 'rewards_providers.dart';

/// What each kind of thing built looks like in the paper: symbols, so
/// the list reads the same to a child in any language.
String zoneEmoji(Zone zone) => switch (zone) {
  Zone.home => '🏠',
  Zone.shop => '🏪',
  Zone.park => '🌳',
  Zone.road => '🛣️',
  Zone.market => '🏭',
  Zone.landmark => '🏰',
  Zone.service => '🚒',
  Zone.sport => '⚽',
  Zone.decor => '🌷',
};

/// The paper's big news: the one thing from the week worth shouting.
String paperHeadline(AppLocalizations l10n, TownPaper paper) {
  if (paper.levelledUp) {
    return l10n.paperHeadlineLevel(townNameAt(l10n, paper.level).toLowerCase());
  }
  if (paper.opened.isNotEmpty) {
    return l10n.paperHeadlineOpened(civicName(l10n, paper.opened.first));
  }
  if (paper.troubles.any((t) => t.handled)) return l10n.paperHeadlineHandled;
  if (paper.newResidents >= 5) {
    return l10n.paperHeadlineResidents(paper.newResidents);
  }
  final built = paper.built.values.fold(0, (a, b) => a + b);
  if (built > 0) return l10n.paperHeadlineBuilt(built);
  if (paper.newResidents > 0) {
    return l10n.paperHeadlineResidents(paper.newResidents);
  }
  return l10n.paperHeadlineQuiet;
}

/// Last week's news from [memberId]'s town, laid out like a paper.
class PaperScreen extends ConsumerWidget {
  const PaperScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final paper = ref.watch(townPaperProvider(memberId));
    const ink = Color(0xFF2B2B2B);
    const newsprint = Color(0xFFF6F1E4);
    final serif = theme.textTheme.apply(
      fontFamily: 'serif',
      bodyColor: ink,
      displayColor: ink,
    );

    Widget item(String emoji, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          Expanded(child: Text(text, style: serif.bodyLarge)),
        ],
      ),
    );

    Widget section(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: ink, height: 24),
        Text(
          title.toUpperCase(),
          style: serif.labelLarge?.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );

    return Scaffold(
      backgroundColor: newsprint,
      appBar: AppBar(
        backgroundColor: newsprint,
        foregroundColor: ink,
        title: Text(l10n.paperTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l10n.paperTitle,
            textAlign: TextAlign.center,
            style: serif.displaySmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            l10n.paperWeek(isoWeekNumber(paper.week)),
            textAlign: TextAlign.center,
            style: serif.labelLarge,
          ),
          const Divider(color: ink, thickness: 2, height: 20),
          Text(
            paperHeadline(l10n, paper),
            style: serif.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (paper.quiet) ...[
            const SizedBox(height: 6),
            Text(l10n.paperQuietBody, style: serif.bodyLarge),
          ],
          if (paper.thingsDone > 0) ...[
            const SizedBox(height: 8),
            item('✅', l10n.paperDone(paper.thingsDone)),
            if (paper.homework > 0)
              item('📚', l10n.paperHomework(paper.homework)),
          ],
          if (paper.residents > 0)
            item(
              '👥',
              l10n.paperResidents(paper.residents, paper.newResidents),
            ),
          if (paper.built.isNotEmpty)
            section(l10n.paperBuilt, [
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final MapEntry(key: zone, value: n)
                      in paper.built.entries)
                    Text('${zoneEmoji(zone)} × $n', style: serif.titleMedium),
                ],
              ),
            ]),
          if (paper.grown.isNotEmpty)
            section(l10n.paperGrown, [
              for (final MapEntry(key: path, value: n) in paper.grown.entries)
                item(pathEmoji(path), '${pathName(l10n, path)} × $n'),
            ]),
          if (paper.opened.isNotEmpty ||
              paper.happenings.isNotEmpty ||
              paper.troubles.isNotEmpty ||
              paper.requestsGranted > 0)
            section(l10n.paperHappenings, [
              for (final c in paper.opened)
                item(
                  civicEmoji(c),
                  l10n.paperHeadlineOpened(civicName(l10n, c)),
                ),
              for (final h in paper.happenings)
                item(happeningEmoji(h), happeningName(l10n, h)),
              for (final t in paper.troubles)
                if (collectibleOf(l10n, 'trouble:${t.kind.name}') case (
                  :final emoji,
                  :final name,
                  sprite: _,
                ))
                  item(emoji, t.handled ? '$name – ${l10n.paperByYou}' : name),
              if (paper.requestsGranted > 0)
                item('💛', l10n.paperRequests(paper.requestsGranted)),
            ]),
        ],
      ),
    );
  }
}
