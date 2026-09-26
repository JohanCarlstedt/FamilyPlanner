import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart' show FamilyStore;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import 'city_sprites.dart';
import 'rewards_providers.dart';

/// "That's me": which of the town's people the child is, and their home
/// with what they have bought for it. Opened on [home] when the child
/// tapped a home in their town, which they can then make theirs.
Future<void> showMeSheet(
  BuildContext context, {
  required String memberId,
  (int, int)? home,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _MeSheet(memberId: memberId, tapped: home),
);

String homeTouchEmoji(HomeTouch touch) => switch (touch) {
  HomeTouch.flowers => '🌷',
  HomeTouch.flag => '🚩',
  HomeTouch.lantern => '🏮',
  HomeTouch.lights => '✨',
};

String homeTouchName(AppLocalizations l10n, HomeTouch touch) =>
    switch (touch) {
      HomeTouch.flowers => l10n.homeTouchFlowers,
      HomeTouch.flag => l10n.homeTouchFlag,
      HomeTouch.lantern => l10n.homeTouchLantern,
      HomeTouch.lights => l10n.homeTouchLights,
    };

class _MeSheet extends ConsumerWidget {
  const _MeSheet({required this.memberId, this.tapped});

  final String memberId;
  final (int, int)? tapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(cityMeProvider(memberId));
    final city = ref.watch(cityProvider(memberId));
    final coins = ref.watch(coinsProvider(memberId)).balance;
    final sprites = ref.watch(citySpritesProvider).value;
    final myHome = me.homeIn(city);

    Future<void> write(Future<void> Function(FamilyStore store) change) async {
      final store = await ref.read(familyStoreProvider.future);
      await change(store);
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('🙂 ${l10n.meTitle}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.meChooseLook, style: theme.textTheme.titleMedium),
            Text(
              l10n.meChooseLookBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final look in CityMe.looks)
                  _Look(
                    sprite: sprites?['person_${look}_s_0'],
                    chosen: me.lookIn == look,
                    onTap: () =>
                        write((store) => store.setCityLook(memberId, look)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (tapped case (final x, final y)
                when myHome != (x, y) && canBeMyHome(city, x, y))
              FilledButton.icon(
                icon: const Icon(Icons.favorite),
                label: Text(l10n.meMakeMyHome),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  await write((store) => store.setMyHome(memberId, city, x, y));
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('❤️ ${l10n.meHomeSet}')),
                  );
                },
              )
            else if (myHome == null)
              Text(l10n.meNoHome, style: theme.textTheme.bodyMedium),
            if (myHome != null) ...[
              Text(
                '❤️ ${l10n.meMyHome} · ${l10n.meTouches}',
                style: theme.textTheme.titleMedium,
              ),
              Text('🪙 $coins', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              for (final touch in HomeTouch.values)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    leading: Text(
                      homeTouchEmoji(touch),
                      style: const TextStyle(fontSize: 26),
                    ),
                    title: Text(homeTouchName(l10n, touch)),
                    trailing: me.touches.contains(touch)
                        ? Chip(label: Text(l10n.meBought))
                        : FilledButton.tonal(
                            onPressed: me.canBuy(city, touch, coins: coins)
                                ? () => write(
                                    (store) => store.buyHomeTouch(
                                      memberId,
                                      city,
                                      touch,
                                      coins: coins,
                                    ),
                                  )
                                : null,
                            child: Text(l10n.meBuy(homeTouchCosts[touch]!)),
                          ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of the town's people to choose, as the picture they walk as.
class _Look extends StatelessWidget {
  const _Look({required this.sprite, required this.chosen, this.onTap});

  final CitySprite? sprite;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 60,
        height: 72,
        decoration: BoxDecoration(
          color: chosen ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chosen ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: sprite == null
            ? const Center(child: Text('🙂', style: TextStyle(fontSize: 28)))
            : RawImage(image: sprite!.image, fit: BoxFit.contain, scale: 1),
      ),
    );
  }
}
