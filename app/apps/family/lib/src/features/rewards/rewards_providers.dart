import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/clock.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../actions/actions_providers.dart';
import '../events/occurrence_editing.dart' show instantOf, wallClock;
import '../homework/homework_screen.dart' show homeworkProvider;

/// Whether the family has turned rewards on (spec section 3,
/// "Contributions"). Everything in this folder hides behind it.
final rewardsOnProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).value?.rewardsOn ?? false,
);

/// Everything finished, as the rewards count it — counted afresh from the
/// chores and homework already on this phone, never stored.
final contributionsProvider = Provider<List<Contribution>>(
  (ref) => FamilyStore.contributionsFrom(
    actions: ref.watch(actionsProvider).value ?? const [],
    homework: ref.watch(homeworkProvider).value ?? const [],
  ),
);

/// This week's family jar, Monday to Monday in the family's own zone.
final jarProvider = Provider<JarProgress?>((ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.rewardsOn) return null;
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  final local = wallClock(now, familyTimeZone);
  final monday = DateTime.utc(
    local.year,
    local.month,
    local.day - (local.weekday - 1),
  );
  return familyJar(
    ref.watch(contributionsProvider),
    from: instantOf(monday, familyTimeZone),
    until: instantOf(
      DateTime.utc(monday.year, monday.month, monday.day + 7),
      familyTimeZone,
    ),
    size: settings.jarSize,
  );
});

/// Every child's world as stored: theme and placements.
final worldsProvider = StreamProvider<Map<String, WorldPayload>>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchWorlds().map(
    (rows) => {for (final (_, w) in rows) w.memberId: w},
  );
});

/// How far [memberId]'s world has come, counted from what they did.
final worldProgressProvider = Provider.family<WorldProgress, String>(
  (ref, memberId) => worldOf(memberId, ref.watch(contributionsProvider)),
);

/// The family's wall-clock date for an instant, as `DateTime.utc` fields
/// (invariant 4).
DateTime familyDay(DateTime instant) {
  final l = wallClock(instant, familyTimeZone);
  return DateTime.utc(l.year, l.month, l.day);
}

/// Whether the family's jar has been full in any week so far: what puts
/// the fountain in every child's square. Counted against the jar's size
/// as it is now, since that is the goal the family has chosen.
final jarEverFullProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.rewardsOn) return false;
  final weeks = <DateTime, int>{};
  for (final c in ref.watch(contributionsProvider)) {
    final day = familyDay(c.at);
    final monday = DateTime.utc(
      day.year,
      day.month,
      day.day - (day.weekday - 1),
    );
    weeks[monday] = (weeks[monday] ?? 0) + 1;
  }
  return weeks.values.any((n) => n >= settings.jarSize);
});

/// [memberId]'s city as it stands now: what they built, grown by what
/// they have done since.
final cityProvider = Provider.family<City, String>((ref, memberId) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  return cityOf(
    memberId,
    contributions: ref.watch(contributionsProvider),
    lots: ref.watch(worldsProvider).value?[memberId]?.city ?? const [],
    jarEverFull: ref.watch(jarEverFullProvider),
    today: familyDay(now),
    dayOf: familyDay,
    projects: ref.watch(familyProjectsProvider).done,
  );
});

/// Evening and night by the family's clock: the city's windows light up.
final cityNightProvider = Provider<bool>((ref) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  final hour = wallClock(now, familyTimeZone).hour;
  return hour >= 20 || hour < 6;
});

/// Every trade offered between the children, answered or not.
final tradesProvider = StreamProvider<List<(String, TradePayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchTrades();
});

/// Every child's city through time: what happened in it on any day.
final cityLifeProvider = Provider.family<CityLife, String>(
  (ref, memberId) => cityLifeOf(
    memberId,
    contributions: ref.watch(contributionsProvider),
    lots: ref.watch(worldsProvider).value?[memberId]?.city ?? const [],
    dayOf: familyDay,
  ),
);

/// Everyone's goods, counted from what they did, what they built, the
/// trades both children agreed to, what they sold and what they gave the
/// family's project. Never stored, so never edited.
final goodsProvider = Provider<GoodsLedger>((ref) {
  final worlds = ref.watch(worldsProvider).value ?? const {};
  final lives = {for (final who in worlds.keys) who: ref.watch(cityLifeProvider(who))};
  return goodsLedger(
    contributions: ref.watch(contributionsProvider),
    lots: {
      for (final MapEntry(key: who, value: w) in worlds.entries) who: w.city,
    },
    trades: ref.watch(_tradeListProvider),
    sales: [for (final w in worlds.values) ...w.sales],
    gifts: [for (final w in worlds.values) ...w.gifts],
    marketDay: (who, at) =>
        lives[who]?.on(familyDay(at)) == Happening.marketDay,
  );
});

final _tradeListProvider = Provider<List<Trade>>(
  (ref) => [
    for (final (id, t)
        in ref.watch(tradesProvider).value ?? const <(String, TradePayload)>[])
      ?t.toTrade(id),
  ],
);

/// What the family has built together, and what it is building.
final familyProjectsProvider =
    Provider<({List<FamilyProject> done, FamilyProject? building, int given})>(
      (ref) => familyProjects(ref.watch(goodsProvider).givenInAll),
    );

/// Everyone living in [memberId]'s town.
final populationProvider = Provider.family<int, String>(
  (ref, memberId) => populationOf(ref.watch(cityProvider(memberId))),
);

/// [memberId]'s coins, counted from everything that earns and spends them.
final coinsProvider = Provider.family<Coins, String>((ref, memberId) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  final world = ref.watch(worldsProvider).value?[memberId];
  return coinsOf(
    memberId,
    contributions: ref.watch(contributionsProvider),
    lots: world?.city ?? const [],
    life: ref.watch(cityLifeProvider(memberId)),
    goods: ref.watch(goodsProvider),
    trades: ref.watch(_tradeListProvider),
    sales: world?.sales ?? const [],
    today: familyDay(now),
    population: ref.watch(populationProvider(memberId)),
  );
});

/// What is going on in [memberId]'s city today.
final happeningTodayProvider = Provider.family<Happening?, String>((
  ref,
  memberId,
) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  return ref.watch(cityLifeProvider(memberId)).on(familyDay(now));
});

/// This week's request in [memberId]'s city, and what granted it.
final requestThisWeekProvider =
    Provider.family<(CityRequest, CityLot?)?, String>((ref, memberId) {
      final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
      final life = ref.watch(cityLifeProvider(memberId));
      final request = life.requestFor(CityLife.weekOf(familyDay(now)));
      return request == null ? null : (request, life.grantOf(request));
    });

/// What is in [memberId]'s book.
final bookProvider = Provider.family<Set<Collectible>, String>((ref, memberId) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  return collected(
    ref.watch(cityProvider(memberId)),
    ref.watch(cityLifeProvider(memberId)).seenUntil(familyDay(now)),
  );
});

/// Homework of [memberId]'s a parent has seen done: what builds the
/// town's learning.
final homeworkSeenProvider = Provider.family<int, String>(
  (ref, memberId) => ref
      .watch(contributionsProvider)
      .where((c) => c.memberId == memberId && c.isHomework && c.growsWorld)
      .length,
);

/// Children with a trading house, and what each one's makes.
final tradersProvider = Provider<Map<String, Good>>((ref) {
  final worlds = ref.watch(worldsProvider).value ?? const {};
  return {
    for (final MapEntry(key: who, value: w) in worlds.entries)
      for (final l in w.city)
        if (l.zone == Zone.market && l.good != null) who: l.good!,
  };
});
