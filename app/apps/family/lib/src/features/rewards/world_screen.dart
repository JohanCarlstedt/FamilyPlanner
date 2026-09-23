import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/clock.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../events/occurrence_editing.dart' show wallClock;
import 'fireworks.dart';
import 'rewards_providers.dart';
import 'world_themes.dart';

/// A child's own world (spec section 3, "Contributions").
///
/// The child arranges it; a parent opening it sees exactly what the child
/// sees and can change nothing. It is never shown beside a sibling's: this
/// screen is one world, and the list of children's worlds is a list of
/// names, not of levels.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key, required this.memberId});

  static const segment = 'world';

  final String memberId;

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  /// Checked once per opening: whether this world has moved up a level
  /// since this phone last showed it, which is the moment to celebrate.
  bool _checkedLevel = false;
  bool _justLevelled = false;

  String get _seenKey => 'world.seenLevel.${widget.memberId}';

  Future<void> _noticeLevel(int level, {required bool mine}) async {
    if (_checkedLevel) return;
    _checkedLevel = true;
    final prefs = await ref.read(devicePreferencesProvider.future);
    final seen = int.tryParse(await prefs.read(_seenKey) ?? '');
    await prefs.write(_seenKey, '$level');
    // The first opening only records where they are: arriving at level 3
    // with fireworks for something that happened last month would be odd.
    if (seen == null || level <= seen || !mounted) return;
    setState(() => _justLevelled = true);
    if (mine) showFireworks(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value?.memberId;
    final mine = me == widget.memberId;
    final world = ref.watch(worldsProvider).value?[widget.memberId];
    final progress = ref.watch(worldProgressProvider(widget.memberId));
    final name = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == widget.memberId)
        .firstOrNull
        ?.displayName;

    if (world == null && mine) return _ChooseTheme(memberId: widget.memberId);

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _noticeLevel(progress.level, mine: mine),
    );

    final look = WorldLook.all[world?.theme ?? WorldTheme.garden]!;
    final placed = world?.placedIn(progress.level) ?? const {};
    final waiting = world?.waiting(progress) ?? progress.filled;
    final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
    final today = wallClock(now, familyTimeZone);
    bool placedToday(WorldPlacement p) {
      final at = wallClock(p.at, familyTimeZone);
      return (at.year, at.month, at.day) == (today.year, today.month, today.day);
    }

    final next = look.next(progress.seeds);

    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? l10n.myWorld : l10n.worldOf(name ?? '')),
        actions: [
          if (mine)
            IconButton(
              tooltip: l10n.worldChangeTheme,
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _ChooseTheme(memberId: widget.memberId),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${themeName(l10n, look.theme)} · ${l10n.worldLevel(progress.level)}',
            style: theme.textTheme.titleMedium,
          ),
          if (_justLevelled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Text('🎉', style: TextStyle(fontSize: 28)),
                  title: Text(l10n.worldLevelUp),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (progress.seeds == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.worldNothingYet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var spot = 0; spot < progress.room; spot++)
                _Spot(
                  symbol: switch (placed[spot]) {
                    final p? => placedToday(p) ? look.sprout : look.symbolFor(p.thing),
                    null => null,
                  },
                  canPlace: mine && (placed.containsKey(spot) || waiting > 0),
                  onTap: () => _place(context, look, progress, spot, waiting),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (waiting > 0)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🌰', style: TextStyle(fontSize: 24)),
              title: Text(l10n.worldWaiting(waiting)),
            ),
          if (next case (final thing, final count))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(thing.symbol, style: const TextStyle(fontSize: 24)),
              title: Text(l10n.worldNext(thing.symbol, count)),
            ),
          // Finished worlds are kept to look back at.
          for (var level = progress.level - 1; level >= 1; level--)
            _FinishedWorld(
              label: l10n.worldLevel(level),
              symbols: [
                for (var spot = 0; spot < WorldProgress.roomAt(level); spot++)
                  switch (world?.placedIn(level)[spot]) {
                    final p? => look.symbolFor(p.thing),
                    // Earned but never placed before the world filled:
                    // still grown, as the theme's first thing.
                    null => look.things.first.symbol,
                  },
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _place(
    BuildContext context,
    WorldLook look,
    WorldProgress progress,
    int spot,
    int waiting,
  ) async {
    final l10n = context.l10n;
    final thing = await showModalBottomSheet<WorldThing>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.worldPick, style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in look.unlocked(progress.seeds))
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(sheet, t),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(t.symbol, style: const TextStyle(fontSize: 36)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (thing == null) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.placeInWorld(
      widget.memberId,
      level: progress.level,
      spot: spot,
      thing: thing.key,
      waiting: waiting,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }
}

class _Spot extends StatelessWidget {
  const _Spot({required this.symbol, required this.canPlace, required this.onTap});

  final String? symbol;
  final bool canPlace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: symbol == null
          ? Colors.transparent
          : theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: symbol == null
            ? BorderSide(color: theme.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canPlace ? onTap : null,
        child: Center(
          child: symbol != null
              ? Text(symbol!, style: const TextStyle(fontSize: 32))
              : canPlace
              ? Icon(Icons.add, color: theme.colorScheme.primary)
              : null,
        ),
      ),
    );
  }
}

class _FinishedWorld extends StatelessWidget {
  const _FinishedWorld({required this.label, required this.symbols});

  final String label;
  final List<String> symbols;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(symbols.join(' '), style: const TextStyle(fontSize: 20)),
      ],
    ),
  );
}

/// The child picks what their world is. Offered again from the world
/// screen; changing it keeps everything already placed.
class _ChooseTheme extends ConsumerWidget {
  const _ChooseTheme({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.worldChooseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.worldChooseHelp, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          for (final look in WorldLook.all.values)
            Card(
              child: ListTile(
                leading: Text(
                  look.things.take(3).map((t) => t.symbol).join(),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(themeName(l10n, look.theme)),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final store = await ref.read(familyStoreProvider.future);
                  await store.chooseWorldTheme(memberId, look.theme);
                  ref.read(syncControllerProvider.notifier).syncNow();
                  if (navigator.canPop()) navigator.pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A parent's way in: the children, by name. Only names — never levels
/// side by side, which would make this the ranking the spec rules out.
class ChildrensWorldsScreen extends ConsumerWidget {
  const ChildrensWorldsScreen({super.key});

  static const segment = 'worlds';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final children = [
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        if (m.isChild && m.isActive) m,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.childrensWorlds)),
      body: ListView(
        children: [
          for (final c in children)
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(l10n.worldOf(c.displayName)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorldScreen(memberId: c.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The family jar on Today, when rewards are on (spec section 3,
/// "Contributions"): how full it is this week and what it is for. No names
/// in it — whoever filled it, filled it.
class JarCard extends ConsumerWidget {
  const JarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jar = ref.watch(jarProvider);
    if (jar == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final jarFor = ref.watch(settingsProvider).value?.jarFor;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: jar.isFull ? theme.colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🫙', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      jar.isFull ? l10n.jarFull : l10n.jarTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    l10n.jarProgress(jar.filled, jar.size),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: jar.size == 0 ? 0 : jar.filled / jar.size,
                  minHeight: 8,
                ),
              ),
              if (jarFor != null) ...[
                const SizedBox(height: 6),
                Text(jarFor, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
