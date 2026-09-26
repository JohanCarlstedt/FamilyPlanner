import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/clock.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'fireworks.dart';
import 'rewards_providers.dart';
import 'city_sprites.dart';
import 'city_view.dart';
import 'city_words.dart';
import 'book_screen.dart';
import 'present_sheet.dart';
import 'rewards_guide.dart';
import 'town_sheet.dart';
import 'trade_sheet.dart';

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

class _WorldScreenState extends ConsumerState<WorldScreen>
    with SingleTickerProviderStateMixin {
  (int, int)? _selected;

  /// The flat map of plots, for finding one behind a tall building.
  var _plan = false;

  /// Zooms out from the old districts to the new one when a level opens
  /// more land: the new ring is revealed rather than just there.
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Size? _viewport;

  /// The view's zoom. Opened on the town, not the map: at the start the
  /// open districts are a third of the map's width, and drawn at the whole
  /// map's size a child's town was small and mostly empty field.
  final _view = TransformationController();

  /// The town size the view was last fitted to: fitted again when a
  /// district opens, left alone otherwise so a child's own zoom stays.
  int? _fittedTo;

  @override
  void dispose() {
    _reveal.dispose();
    _view.dispose();
    super.dispose();
  }

  /// The zoom that fits districts out to [radius], and a little field
  /// round them, to the width, centred on the middle of the town.
  static Matrix4 _fitting(int radius, Size viewport) {
    final scale = (City.size / (radius * 2 + 3)).clamp(1.0, 4.0);
    final (:centre, height: _) = cityCentre(viewport.width);
    return Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - centre.dx * scale,
        viewport.height / 2 - centre.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _fit(City city, Size viewport) {
    _viewport = viewport;
    if (_fittedTo == city.radius) return;
    _fittedTo = city.radius;
    _view.value = _fitting(city.radius, viewport);
  }

  /// From the districts before to all of them now, slowly.
  void _revealRing(int radius) {
    final viewport = _viewport;
    if (viewport == null || radius <= 2) return;
    final from = _fitting(radius - 1, viewport);
    final to = _fitting(radius, viewport);
    final tween = Matrix4Tween(begin: from, end: to);
    final curve = CurvedAnimation(parent: _reveal, curve: Curves.easeInOut);
    void step() => _view.value = tween.evaluate(curve);
    _reveal
      ..removeListener(step)
      ..addListener(step)
      ..forward(from: 0);
  }

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
    _revealRing(ref.read(cityProvider(widget.memberId)).radius);
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
    final ledger = ref.watch(goodsProvider);
    final goods = {
      for (final g in Good.values)
        if (ledger.of(widget.memberId, g) > 0) g: ledger.of(widget.memberId, g),
    };
    final offers = mine
        ? offersTo(me, ref.watch(tradesProvider).value ?? const []).length
        : 0;
    final coins = ref.watch(coinsProvider(widget.memberId)).balance;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    // Presents from the last week, newest first: long enough to be seen,
    // short enough not to fill the screen.
    final weekAgo = (ref.watch(nowProvider).value ?? DateTime.now().toUtc())
        .subtract(const Duration(days: 7));
    final recentPresents = [
      for (final p in ref.watch(presentsProvider))
        if (p.to == widget.memberId && p.at.isAfter(weekAgo)) p,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final population = ref.watch(populationProvider(widget.memberId));
    final happening = ref.watch(happeningTodayProvider(widget.memberId));
    final trouble = ref.watch(troubleNowProvider(widget.memberId));
    final hidden = ref.watch(coinsProvider(widget.memberId)).hidden;
    final request = ref.watch(requestThisWeekProvider(widget.memberId));
    final nextUp = nextUps(
      city,
      progress: ref.watch(worldProgressProvider(widget.memberId)),
      homeworkSeen: ref.watch(homeworkSeenProvider(widget.memberId)),
    ).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(mine ? l10n.myWorld : l10n.worldOf(name ?? '')),
        actions: [
          IconButton(
            tooltip: _plan ? l10n.cityShowTown : l10n.cityShowPlots,
            isSelected: _plan,
            onPressed: () => setState(() => _plan = !_plan),
            icon: const Icon(Icons.grid_view),
            selectedIcon: const Icon(Icons.location_city),
          ),
          IconButton(
            tooltip: mine ? l10n.bookTitle : l10n.bookOf(name ?? ''),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BookScreen(memberId: widget.memberId),
              ),
            ),
            icon: const Icon(Icons.auto_stories_outlined),
          ),
          if (!mine && (ref.watch(membershipProvider).value?.isParent ?? false))
            IconButton(
              tooltip: l10n.presentGive,
              onPressed: () =>
                  showPresentSheet(context, to: widget.memberId, name: name),
              icon: const Icon(Icons.card_giftcard),
            ),
          IconButton(
            tooltip: l10n.townTitle,
            onPressed: () =>
                showTownSheet(context, memberId: widget.memberId, mine: mine),
            icon: const Icon(Icons.account_balance_outlined),
          ),
          if (mine && city.market != null)
            IconButton(
              tooltip: l10n.trade,
              onPressed: () => showTradeSheet(context),
              icon: Badge.count(
                count: offers,
                isLabelVisible: offers > 0,
                child: const Icon(Icons.swap_horiz),
              ),
            ),
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
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      '🪙 $coins',
                      '👥 $population',
                      if (goods.isNotEmpty) goodsText(goods),
                    ].join('   '),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (trouble != null)
                  _Strip(
                    emoji: trouble.kind == TroubleKind.fire ? '🔥' : '🦹',
                    title: trouble.kind == TroubleKind.fire
                        ? l10n.troubleFire
                        : hidden > 0
                        ? l10n.troubleThief(hidden)
                        : l10n.troubleThiefLooking,
                    body: trouble.kind == TroubleKind.fire
                        ? l10n.troubleFireBody
                        : l10n.troubleThiefBody,
                    alarm: true,
                    onTap: () =>
                        setState(() => _selected = (trouble.x, trouble.y)),
                  ),
                for (final p in recentPresents)
                  _Strip(
                    emoji: '🎁',
                    title: l10n.presentFrom(
                      names[p.from] ?? '',
                      [
                        if (p.coins > 0) '${p.coins} 🪙',
                        if (p.good != null && p.count > 0)
                          '${p.count} ${goodEmoji(p.good!)}',
                      ].join(' + '),
                    ),
                    body: p.note,
                    highlight: true,
                  ),
                if (happening != null)
                  _Strip(
                    emoji: happeningEmoji(happening),
                    title: happeningName(l10n, happening),
                    body: happeningBody(l10n, happening),
                    highlight: true,
                  ),
                if (request case (final r, final granted))
                  _Strip(
                    emoji: granted == null ? '🙋' : '💛',
                    title: granted == null
                        ? requestText(l10n, r)
                        : l10n.requestThanks(r.who, requestReward),
                    body: granted == null
                        ? l10n.requestReward(requestReward)
                        : null,
                    onTap: r.x == null
                        ? null
                        : () {
                            setState(() => _selected = (r.x!, r.y!));
                            Future<void>.delayed(
                              const Duration(seconds: 3),
                              () {
                                if (mounted && _selected == (r.x, r.y)) {
                                  setState(() => _selected = null);
                                }
                              },
                            );
                          },
                  ),
                if (nextUp != null)
                  _Strip(
                    emoji: nextUpEmoji(nextUp),
                    title: nextUpText(l10n, nextUp),
                    onTap: () => showTownSheet(
                      context,
                      memberId: widget.memberId,
                      mine: mine,
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
            child: LayoutBuilder(
              builder: (context, box) {
                _fit(city, box.biggest);
                return InteractiveViewer(
                  transformationController: _view,
                  maxScale: 6,
                  minScale: 1,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(48),
                  child: SizedBox(
                    width: box.maxWidth,
                    child: CityView(
                      city: city,
                      sprites: ref.watch(citySpritesProvider).value,
                      night: ref.watch(cityNightProvider),
                      festival: ref.watch(jarProvider)?.isFull ?? false,
                      happening: happening,
                      population: population,
                      trouble: trouble,
                      plan: _plan,
                      selected: _selected,
                      onTapPlot: mine
                          ? (x, y) => _tapped(context, city, x, y)
                          : null,
                    ),
                  ),
                );
              },
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
    // Ready to grow: choose how.
    if (city.canUpgrade(x, y)) {
      setState(() => _selected = (x, y));
      final path = await showModalBottomSheet<UpgradePath>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _UpgradeSheet(city: city, x: x, y: y),
      );
      if (mounted) setState(() => _selected = null);
      if (path == null) return;
      final store = await ref.read(familyStoreProvider.future);
      await store.upgradeInCity(widget.memberId, city, x: x, y: y, path: path);
      ref.read(syncControllerProvider.notifier).syncNow();
      return;
    }
    final building = city.canChange(x, y);
    // Empty ground, even with no seed waiting: services cost coins.
    final empty =
        city.canBuild(x, y, Zone.road) ||
        Service.values.any((s) => city.canBuildService(x, y, s));
    if (!building && !empty) return;
    setState(() => _selected = (x, y));
    final have = {
      for (final g in Good.values)
        g: ref.read(goodsProvider).of(widget.memberId, g),
    };
    final coins = ref.read(coinsProvider(widget.memberId)).balance;
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _BuildSheet(
        city: city,
        changing: building,
        x: x,
        y: y,
        have: have,
        coins: coins,
      ),
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
    } else if (choice.landmark case final landmark?) {
      await store.buildLandmark(
        widget.memberId,
        city,
        landmark,
        x: x,
        y: y,
        have: have,
      );
    } else if (choice.decor case final decor?) {
      await store.buildDecor(
        widget.memberId,
        city,
        decor,
        x: x,
        y: y,
        coins: coins,
      );
    } else if (choice.sport case final sport?) {
      await store.buildSport(widget.memberId, city, sport, x: x, y: y);
    } else if (choice.service case final service?) {
      await store.buildService(
        widget.memberId,
        city,
        service,
        x: x,
        y: y,
        coins: coins,
        have: have,
        paid: payWith(have, serviceGoods[service] ?? 0),
      );
    } else if (choice.zone == Zone.market) {
      await store.buildTradingHouse(widget.memberId, city, x: x, y: y);
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

/// A choice from the build sheet: a zone, a special building, or none
/// to take today's back.
class _Choice {
  const _Choice(
    this.zone, {
    this.landmark,
    this.service,
    this.sport,
    this.decor,
  });
  final Zone? zone;
  final Landmark? landmark;
  final Service? service;
  final Sport? sport;
  final Decor? decor;
}

/// [count] goods from [have], taken from whatever the child has most of,
/// so what they are saving for a landmark is the last to go.
Map<Good, int> payWith(Map<Good, int> have, int count) {
  final left = {...have};
  final paid = <Good, int>{};
  for (var i = 0; i < count; i++) {
    final most =
        (left.entries.where((e) => e.value > 0).toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .firstOrNull;
    if (most == null) break;
    left[most.key] = most.value - 1;
    paid[most.key] = (paid[most.key] ?? 0) + 1;
  }
  return paid;
}

/// One line under the town's name: today's happening, the week's
/// request, what is coming next.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.emoji,
    required this.title,
    this.body,
    this.onTap,
    this.highlight = false,
    this.alarm = false,
  });

  final String emoji;
  final String title;
  final String? body;
  final VoidCallback? onTap;
  final bool highlight;

  /// Trouble in town: in the colours of an alarm.
  final bool alarm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: alarm
            ? theme.colorScheme.errorContainer
            : highlight
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyMedium),
                      if (body != null)
                        Text(
                          body!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildSheet extends StatelessWidget {
  const _BuildSheet({
    required this.city,
    required this.changing,
    required this.x,
    required this.y,
    required this.have,
    required this.coins,
  });

  final City city;
  final int x;
  final int y;

  /// The child's coins now, for the services they can afford.
  final int coins;

  /// The child's goods now, for what special buildings they can afford.
  final Map<Good, int> have;

  /// Changing today's building rather than building on empty ground.
  final bool changing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final shops = city.civic.contains(Civic.school);
    // Services cost coins, so the sheet opens with no seed waiting too;
    // then the rest waits for the next thing done.
    // A street is free; anything else needs a seed, unless it is today's
    // building being changed, whose seed is already spent.
    final was = city.lotAt(x, y);
    final seedSpent = changing && (was?.takesSeed ?? false);
    final noSeed = !seedSpent && city.waiting == 0
        ? l10n.cityNoSeedsLeft
        : null;
    ListTile option(Zone zone, String symbol, String label, {String? locked}) {
      if (zone != Zone.road) locked ??= noSeed;
      return ListTile(
        leading: Text(symbol, style: const TextStyle(fontSize: 28)),
        title: Text(label),
        subtitle: locked == null ? null : Text(locked),
        enabled: locked == null,
        onTap: () => Navigator.pop(context, _Choice(zone)),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
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
            // Today's service is only taken back: it was paid in coins.
            if (!(changing &&
                (was?.zone == Zone.service ||
                    was?.zone == Zone.sport ||
                    was?.zone == Zone.decor))) ...[
              option(Zone.home, '🏠', l10n.cityHome),
              option(
                Zone.shop,
                '🏪',
                l10n.cityShop,
                locked: shops ? null : l10n.cityShopNeedsSchool,
              ),
              option(Zone.park, '🌳', l10n.cityPark),
              option(Zone.road, '🛣️', '${l10n.cityRoad} · ${l10n.cityFree}'),
            ],
            // A trading house and the special buildings go up on empty
            // ground, never by changing today's mind about something else.
            if (!changing && city.market == null)
              option(
                Zone.market,
                '🏛️',
                l10n.cityMarket,
                locked: city.level >= City.marketLevel
                    ? null
                    : l10n.cityMarketLocked,
              ),
            if (!changing && city.market != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  l10n.cityLandmarks,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final landmark in Landmark.values)
                ListTile(
                  leading: Text(
                    landmarkEmoji(landmark),
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(landmarkName(l10n, landmark)),
                  subtitle: Text(
                    city.lots.any((l) => l.landmark == landmark)
                        ? l10n.landmarkBuilt
                        : landmark == Landmark.harbour &&
                              !city.canBuildLandmark(x, y, landmark, {
                                for (final g in Good.values) g: 999,
                              })
                        ? l10n.landmarkShore
                        : l10n.landmarkNeeds(
                            goodsText(landmarkCosts[landmark]!),
                          ),
                  ),
                  enabled: city.canBuildLandmark(x, y, landmark, have),
                  onTap: () =>
                      Navigator.pop(context, _Choice(null, landmark: landmark)),
                ),
            ],
            if (!changing) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(l10n.cityDecor, style: theme.textTheme.titleSmall),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(l10n.decorWhy, style: theme.textTheme.bodySmall),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final decor in Decor.values)
                      ActionChip(
                        avatar: Text(decorEmoji(decor)),
                        label: Text(
                          '${decorName(l10n, decor)} · ${decorCosts[decor]} 🪙',
                        ),
                        onPressed:
                            city.canBuildDecor(x, y) &&
                                coins >= decorCosts[decor]!
                            ? () => Navigator.pop(
                                context,
                                _Choice(null, decor: decor),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ],
            if (!changing) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(l10n.citySports, style: theme.textTheme.titleSmall),
              ),
              for (final sport in Sport.values)
                ListTile(
                  leading: Text(
                    sportEmoji(sport),
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(sportName(l10n, sport)),
                  subtitle: Text(
                    city.lots.any((l) => l.sport == sport)
                        ? l10n.landmarkBuilt
                        : city.activities < City.activitiesFor[sport]!
                        ? l10n.sportLocked(
                            City.activitiesFor[sport]! - city.activities,
                          )
                        : l10n.sportWhy,
                  ),
                  enabled: city.canBuildSport(x, y, sport),
                  onTap: () =>
                      Navigator.pop(context, _Choice(null, sport: sport)),
                ),
            ],
            if (!changing) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  l10n.cityServices,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final service in Service.values)
                Builder(
                  builder: (context) {
                    final goods = serviceGoods[service] ?? 0;
                    final haveGoods = have.values.fold(0, (a, b) => a + b);
                    final placeable = city.canBuildService(x, y, service);
                    final affordable =
                        coins >= serviceCosts[service]! && haveGoods >= goods;
                    return ListTile(
                      leading: Text(
                        serviceEmoji(service),
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(serviceName(l10n, service)),
                      subtitle: Text(
                        [
                          serviceCostText(l10n, service),
                          if (!placeable && service == Service.bus)
                            l10n.serviceByStreet
                          else
                            serviceWhy(l10n, service),
                        ].join(' · '),
                      ),
                      enabled: placeable && affordable,
                      onTap: () => Navigator.pop(
                        context,
                        _Choice(null, service: service),
                      ),
                    );
                  },
                ),
            ],
            if (changing)
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(l10n.cityTakeBack),
                onTap: () => Navigator.pop(context, const _Choice(null)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A building ready to grow, and the ways it can: each with what it does.
class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet({required this.city, required this.x, required this.y});

  final City city;
  final int x;
  final int y;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lot = city.lotAt(x, y)!;
    final size = city.sizeOf(x, y);
    final now = collectibleOf(l10n, '${lot.zone.name}:$size');
    final next = collectibleOf(l10n, '${lot.zone.name}:${size + 1}');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('⬆️ ${l10n.upgradeTitle}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${now.name} → ${next.name}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(l10n.upgradeChoose, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final path in City.paths[lot.zone] ?? const <UpgradePath>[])
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Text(
                    pathEmoji(path),
                    style: const TextStyle(fontSize: 30),
                  ),
                  title: Text(pathName(l10n, path)),
                  subtitle: Text(pathWhy(l10n, path)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, path),
                ),
              ),
          ],
        ),
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
          if (ref.watch(membershipProvider).value?.memberId case final me?)
            ListTile(
              leading: const Icon(Icons.location_city),
              title: Text(l10n.myOwnCity),
              subtitle: Text(l10n.myOwnCitySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorldScreen(memberId: me),
                ),
              ),
            ),
          const Divider(),
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
