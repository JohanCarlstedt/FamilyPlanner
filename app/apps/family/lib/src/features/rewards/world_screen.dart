import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'fireworks.dart';
import 'rewards_providers.dart';
import 'city_view.dart';
import 'rewards_guide.dart';

/// A child's own city (spec section 3, "Contributions").
///
/// The child builds it: tap an empty plot, choose a home, a shop, a park
/// or a street, and it goes up. Then it grows by itself from what they go
/// on doing. A parent opening it sees exactly what the child sees and can
/// change nothing. It is never shown beside a sibling's.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key, required this.memberId});

  static const segment = 'world';

  final String memberId;

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  (int, int)? _selected;
  bool _checkedLevel = false;
  bool _justLevelled = false;

  String get _seenKey => 'world.seenLevel.${widget.memberId}';

  /// Once per opening: whether the city has opened a new district since
  /// this phone last showed it, which is the moment to celebrate. The
  /// first opening only records where they are.
  Future<void> _noticeLevel(int level, {required bool mine}) async {
    if (_checkedLevel) return;
    _checkedLevel = true;
    final prefs = await ref.read(devicePreferencesProvider.future);
    // The first time a child opens their own city, they are told how it
    // works before they are left to work it out from a map.
    if (mine) {
      const guideKey = 'city.guideSeen';
      if (await prefs.read(guideKey) == null) {
        await prefs.write(guideKey, 'yes');
        if (mounted) await showRewardsGuide(context, forChild: true);
      }
    }
    final seen = int.tryParse(await prefs.read(_seenKey) ?? '');
    await prefs.write(_seenKey, '$level');
    if (seen == null || level <= seen || !mounted) return;
    setState(() => _justLevelled = true);
    if (mine) showFireworks(context);
  }

  static String townName(AppLocalizations l10n, int level) => switch (level) {
    1 => l10n.cityHamlet,
    2 => l10n.cityVillage,
    3 => l10n.citySmallTown,
    4 => l10n.cityTown,
    5 => l10n.cityCity,
    _ => l10n.cityBigCity,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value?.memberId;
    final mine = me == widget.memberId;
    final city = ref.watch(cityProvider(widget.memberId));
    final name = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == widget.memberId)
        .firstOrNull
        ?.displayName;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _noticeLevel(city.level, mine: mine),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? l10n.myWorld : l10n.worldOf(name ?? '')),
        actions: [
          IconButton(
            tooltip: l10n.guideHowItWorks,
            icon: const Icon(Icons.help_outline),
            onPressed: () => showRewardsGuide(context, forChild: mine),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cityStatus(townName(l10n, city.level), city.level),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  city.seeds == 0
                      ? l10n.worldNothingYet
                      : city.waiting > 0
                      ? '${l10n.cityWaiting(city.waiting)}${mine ? ' · ${l10n.cityTapToBuild}' : ''}'
                      : l10n.myWorldSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_justLevelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: theme.colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Text(
                          '🎉',
                          style: TextStyle(fontSize: 28),
                        ),
                        title: Text(l10n.worldLevelUp),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            // Pinch to look closer, drag to look around; a tap still lands
            // on the plot under the finger at any zoom.
            child: InteractiveViewer(
              maxScale: 4,
              minScale: 1,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(48),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: CityView(
                  city: city,
                  night: ref.watch(cityNightProvider),
                  festival: ref.watch(jarProvider)?.isFull ?? false,
                  selected: _selected,
                  onTapPlot: mine
                      ? (x, y) => _tapped(context, city, x, y)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tapped(BuildContext context, City city, int x, int y) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!city.isOpen(x, y)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cityClosed)));
      return;
    }
    final building = city.canChange(x, y);
    final empty = city.canBuild(x, y, Zone.home);
    if (!building && !empty) return;
    setState(() => _selected = (x, y));
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      builder: (sheet) => _BuildSheet(city: city, changing: building),
    );
    if (mounted) setState(() => _selected = null);
    if (choice == null) return;
    final store = await ref.read(familyStoreProvider.future);
    if (building) {
      await store.changeCityLot(
        widget.memberId,
        city,
        x: x,
        y: y,
        zone: choice.zone,
      );
    } else if (choice.zone != null) {
      await store.buildInCity(
        widget.memberId,
        city,
        x: x,
        y: y,
        zone: choice.zone!,
      );
    }
    ref.read(syncControllerProvider.notifier).syncNow();
  }
}

/// A choice from the build sheet: a zone, or none to take today's back.
class _Choice {
  const _Choice(this.zone);
  final Zone? zone;
}

class _BuildSheet extends StatelessWidget {
  const _BuildSheet({required this.city, required this.changing});

  final City city;

  /// Changing today's building rather than building on empty ground.
  final bool changing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final shops = city.civic.contains(Civic.school);
    ListTile option(Zone zone, String symbol, String label, {String? locked}) =>
        ListTile(
          leading: Text(symbol, style: const TextStyle(fontSize: 28)),
          title: Text(label),
          subtitle: locked == null ? null : Text(locked),
          enabled: locked == null,
          onTap: () => Navigator.pop(context, _Choice(zone)),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              changing ? l10n.cityBuilding : l10n.cityBuild,
              style: theme.textTheme.titleMedium,
            ),
          ),
          option(Zone.home, '🏠', l10n.cityHome),
          option(
            Zone.shop,
            '🏪',
            l10n.cityShop,
            locked: shops ? null : l10n.cityShopNeedsSchool,
          ),
          option(Zone.park, '🌳', l10n.cityPark),
          option(Zone.road, '🛣️', l10n.cityRoad),
          if (changing)
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(l10n.cityTakeBack),
              onTap: () => Navigator.pop(context, const _Choice(null)),
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
      appBar: AppBar(
        title: Text(l10n.childrensWorlds),
        actions: [
          IconButton(
            tooltip: l10n.guideHowItWorks,
            icon: const Icon(Icons.help_outline),
            onPressed: () => showRewardsGuide(context, forChild: false),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.guideChildrensCities,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
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
        clipBehavior: Clip.antiAlias,
        color: jar.isFull ? theme.colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: () => showJarGuide(context),
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
      ),
    );
  }
}
