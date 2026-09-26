import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import 'city_words.dart';
import 'rewards_providers.dart';
import 'trade_sheet.dart';

/// The town's own page: who lives there, its coins, what is coming, what
/// the child is saving for, selling goods and the family's project.
Future<void> showTownSheet(
  BuildContext context, {
  required String memberId,
  required bool mine,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TownSheet(memberId: memberId, mine: mine),
);

class _TownSheet extends ConsumerWidget {
  const _TownSheet({required this.memberId, required this.mine});

  final String memberId;

  /// The child's own town: they may sell, give and choose a goal.
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final city = ref.watch(cityProvider(memberId));
    final coins = ref.watch(coinsProvider(memberId)).balance;
    final population = ref.watch(populationProvider(memberId));
    final ledger = ref.watch(goodsProvider);
    final have = {for (final g in Good.values) g: ledger.of(memberId, g)};
    final family = ref.watch(familyProjectsProvider);
    final goal = ref.watch(worldsProvider).value?[memberId]?.goal;
    final nextMilestone = populationMilestones
        .where((m) => m > population)
        .firstOrNull;
    final ups = nextUps(
      city,
      progress: ref.watch(worldProgressProvider(memberId)),
      homeworkSeen: ref.watch(homeworkSeenProvider(memberId)),
      growing: 3,
    );

    Future<void> act(Future<Object?> Function(FamilyStore store) run) async {
      final store = await ref.read(familyStoreProvider.future);
      await run(store);
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    Widget muted(String text) => Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.townTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    emoji: '👥',
                    value: l10n.cityPopulationLabel(population),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Figure(
                    emoji: '🪙',
                    value: l10n.cityCoinsLabel(coins),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            muted(l10n.townPeopleHow),
            if (nextMilestone != null)
              muted(
                l10n.townNextMilestone(
                  nextMilestone - population,
                  milestoneCoins,
                ),
              ),
            const SizedBox(height: 4),
            muted(l10n.townCoinsHow),

            heading(l10n.nextUpTitle),
            for (final up in ups)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        nextUpEmoji(up),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    Expanded(child: Text(nextUpText(l10n, up))),
                  ],
                ),
              ),

            heading(l10n.townGoal),
            _Goal(
              goal: goal,
              coins: coins,
              have: have,
              city: city,
              onChoose: mine
                  ? (value) => act((s) => s.setCityGoal(memberId, value))
                  : null,
            ),

            if (city.market != null) ...[
              heading(l10n.townSell),
              muted(l10n.townSellHow(coinsPerGoodSold)),
              for (final g in Good.values)
                if (have[g]! > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      goodEmoji(g),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text('${have[g]} ${goodName(l10n, g)}'),
                    trailing: mine
                        ? OutlinedButton(
                            onPressed: () => act(
                              (s) => s.sellGoods(memberId, g, 1, have: have),
                            ),
                            child: Text(l10n.townSellOne),
                          )
                        : null,
                  ),
            ],

            heading(l10n.projectTitle),
            ..._project(context, ref, family, have, act),
          ],
        ),
      ),
    );
  }

  List<Widget> _project(
    BuildContext context,
    WidgetRef ref,
    ({List<FamilyProject> done, FamilyProject? building, int given}) family,
    Map<Good, int> have,
    Future<void> Function(Future<Object?> Function(FamilyStore)) act,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final building = family.building;
    return [
      if (family.done.isNotEmpty)
        Text(
          family.done
              .map((p) => '${projectEmoji(p)} ${projectName(l10n, p)}')
              .join('   '),
          style: theme.textTheme.bodyLarge,
        ),
      if (building == null)
        Text(l10n.projectAllDone)
      else ...[
        const SizedBox(height: 6),
        Text(
          '${projectEmoji(building)} '
          '${l10n.projectProgress(projectName(l10n, building), family.given, projectGoods[building]!)}',
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: family.given / projectGoods[building]!,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.projectHow,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (mine)
          Wrap(
            spacing: 8,
            children: [
              for (final g in Good.values)
                if (have[g]! > 0)
                  ActionChip(
                    avatar: Text(goodEmoji(g)),
                    label: Text(l10n.projectGiveOne),
                    onPressed: () =>
                        act((s) => s.giveToProject(memberId, g, 1, have: have)),
                  ),
            ],
          ),
      ],
    ];
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.emoji, required this.value});

  final String emoji;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}

/// What the child is saving for, how far they have got, and a way to
/// choose something else.
class _Goal extends StatelessWidget {
  const _Goal({
    required this.goal,
    required this.coins,
    required this.have,
    required this.city,
    required this.onChoose,
  });

  final String? goal;
  final int coins;
  final Map<Good, int> have;
  final City city;
  final void Function(String goal)? onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (landmark, service) = goalOf(goal);
    final options = <(String, String)>[
      for (final s in Service.values)
        ('service:${s.name}', '${serviceEmoji(s)} ${serviceName(l10n, s)}'),
      for (final l in Landmark.values)
        if (!city.lots.any((x) => x.landmark == l))
          (
            'landmark:${l.name}',
            '${landmarkEmoji(l)} ${landmarkName(l10n, l)}',
          ),
    ];

    // How far: coins for a service, goods for a special building.
    double? progress;
    String? detail;
    var ready = false;
    if (service != null) {
      final cost = serviceCosts[service]!;
      final goods = serviceGoods[service] ?? 0;
      final held = have.values.fold(0, (a, b) => a + b);
      progress =
          ((coins / cost).clamp(0, 1) +
              (goods == 0 ? 1 : (held / goods).clamp(0, 1))) /
          2;
      detail = '🪙 $coins / ${serviceCostText(l10n, service)}';
      ready = coins >= cost && held >= goods;
    } else if (landmark != null) {
      final cost = landmarkCosts[landmark]!;
      final total = cost.values.fold(0, (a, b) => a + b);
      final got = cost.entries.fold(
        0,
        (a, e) => a + ((have[e.key] ?? 0).clamp(0, e.value)),
      );
      progress = got / total;
      detail =
          '${goodsText({for (final e in cost.entries) e.key: have[e.key] ?? 0})}'
          '  /  ${goodsText(cost)}';
      ready = got == total && city.market != null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null) ...[
          Text(
            service != null
                ? '${serviceEmoji(service)} ${serviceName(l10n, service)}'
                : '${landmarkEmoji(landmark!)} ${landmarkName(l10n, landmark)}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          const SizedBox(height: 4),
          Text(ready ? l10n.townGoalReady : detail!),
        ] else
          Text(l10n.townGoalNone),
        if (onChoose != null)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              onSelected: onChoose,
              itemBuilder: (_) => [
                for (final (value, label) in options)
                  PopupMenuItem(value: value, child: Text(label)),
                PopupMenuItem(value: '', child: Text(l10n.townGoalNothing)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.townGoalNone,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
