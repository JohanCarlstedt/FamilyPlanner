import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
import 'city_sprites.dart';
import 'city_view.dart';
import 'city_words.dart';
import 'rewards_providers.dart';
import 'world_screen.dart';

/// A child's city on Today: a small picture of it, what is ready to grow,
/// trouble or a happening, coins and people. A tap goes in. Nothing
/// unless the family has rewards on.
class CityCard extends ConsumerWidget {
  const CityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rewardsOnProvider)) return const SizedBox.shrink();
    final me = ref.watch(membershipProvider).value?.memberId;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    if (me == null || !members.any((m) => m.id == me && m.isChild)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final city = ref.watch(cityProvider(me));
    final ready = city.lots.where((l) => city.canUpgrade(l.x, l.y)).length;
    final trouble = ref.watch(troubleNowProvider(me));
    final happening = ref.watch(happeningTodayProvider(me));
    final coins = ref.watch(coinsProvider(me)).balance;
    final population = ref.watch(populationProvider(me));
    final lines = [
      if (ready > 0) '⬆️ ${l10n.cityCardReady(ready)}',
      if (trouble != null)
        trouble.kind == TroubleKind.fire
            ? '🔥 ${l10n.troubleFire}'
            : '🦹 ${l10n.troubleThiefLooking}',
      if (happening != null)
        '${happeningEmoji(happening)} ${happeningName(l10n, happening)}',
      if (city.waiting > 0) '🌱 ${l10n.cityWaiting(city.waiting)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => WorldScreen(memberId: me)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 92,
                child: _Thumbnail(city: city),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.cityCardTitle, style: theme.textTheme.titleSmall),
                      for (final line in lines.take(2))
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      Text(
                        '🪙 $coins   👥 $population',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The town, fitted into a small box, drawn still.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.city});

  final City city;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, box) {
      const width = 390.0;
      final (:centre, height: _) = cityCentre(width);
      final scale =
          (City.size / (city.radius * 2 + 3)).clamp(1.0, 4.0) *
          box.maxWidth /
          width;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(
                box.maxWidth / 2 - centre.dx * scale,
                box.maxHeight / 2 - centre.dy * scale,
                0,
                1,
              )
              ..scaleByDouble(scale, scale, 1, 1),
            child: SizedBox(
              width: width,
              child: CityView(
                city: city,
                sprites: ref.watch(citySpritesProvider).value,
                night: ref.watch(cityNightProvider),
                festival: false,
                still: true,
              ),
            ),
          ),
        ),
      );
    },
  );
}
