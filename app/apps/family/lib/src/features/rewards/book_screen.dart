import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
import 'city_words.dart';
import 'rewards_providers.dart';

/// A child's book: every kind of building and every size it grows to,
/// the services, special buildings and family projects, and what they
/// have seen happen in their town. What they have not found yet is a
/// grey space waiting for it.
class BookScreen extends ConsumerWidget {
  const BookScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mine = ref.watch(membershipProvider).value?.memberId == memberId;
    final name = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == memberId)
        .firstOrNull
        ?.displayName;
    final have = ref.watch(bookProvider(memberId));
    final buildings = [
      for (final c in allCollectibles)
        if (!c.startsWith('happening:')) c,
    ];
    final seen = [
      for (final c in allCollectibles)
        if (c.startsWith('happening:')) c,
    ];

    Widget grid(List<Collectible> items) => GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: [
        for (final c in items) _Entry(item: c, found: have.contains(c)),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? l10n.bookTitle : l10n.bookOf(name ?? '')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l10n.bookCount(
              have.where(allCollectibles.contains).length,
              allCollectibles.length,
            ),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(l10n.bookBuildings, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          grid(buildings),
          const SizedBox(height: 20),
          Text(l10n.bookSeen, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          grid(seen),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.item, required this.found});

  final Collectible item;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (:emoji, :name, :sprite) = collectibleOf(l10n, item);
    final picture = sprite == null
        ? Text(emoji, style: const TextStyle(fontSize: 34))
        : Image.asset(
            'assets/city/$sprite.webp',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Text(emoji, style: const TextStyle(fontSize: 34)),
          );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: found
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: found
                  ? picture
                  : Opacity(
                      opacity: 0.25,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.srcIn,
                        ),
                        child: picture,
                      ),
                    ),
            ),
          ),
          Text(
            found ? name : '?',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
