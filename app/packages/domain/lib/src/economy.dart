/// A city's coins (spec section 3, "Contributions"): what services are
/// paid for with, earned by doing things in a town that is doing well.
///
/// Like seeds and goods, coins are counted, never stored: from what the
/// child did, what their town had at the time, the trades both children
/// agreed to and what they sold. Nothing here can be edited upwards.
library;

import 'dart:math';

import 'city.dart';
import 'city_life.dart';
import 'contributions.dart';
import 'trading.dart';

/// What each service costs in coins.
const serviceCosts = <Service, int>{
  Service.bus: 3,
  Service.power: 5,
  Service.water: 5,
  Service.fire: 6,
  Service.clinic: 6,
};

/// Goods a service costs besides its coins, of any kind the child
/// chooses. What a trading house makes goes into the town's own
/// buildings, not only into landmarks, so a child with no sibling to
/// trade with still has a use for it.
const serviceGoods = <Service, int>{
  Service.fire: 2,
  Service.clinic: 2,
};

/// The most a thing done can earn from the town's trade, besides the one
/// coin it always earns and the day's happening.
const maxTradeCoins = 3;

/// People a home has room for at each size: cottage, house, apartments,
/// tower.
const homeRoom = [4, 8, 24, 60];

/// How full a home is with nothing around it, and what each thing
/// nearby adds. A home by a park and a shop, on a bus route and near a
/// clinic, is full; one on a bare street is half empty.
const baseOccupancy = 0.5;
const parkOccupancy = 0.15;
const shopOccupancy = 0.15;
const busOccupancy = 0.1;
const clinicOccupancy = 0.1;

/// Residents at which the town celebrates, each paying [milestoneCoins].
const populationMilestones = [25, 50, 100, 200, 400, 800];
const milestoneCoins = 5;

/// How full the home at (x, y) is, from 0 to 1: how well the child has
/// built round it. A park or shop counts within [requestReach] plots.
double occupancyAt(City city, int x, int y) {
  bool near(Zone zone) => city.lots.any(
        (l) =>
            l.zone == zone &&
            !city.underConstruction(l.x, l.y) &&
            max((l.x - x).abs(), (l.y - y).abs()) <= requestReach,
      );
  return baseOccupancy +
      (near(Zone.park) ? parkOccupancy : 0) +
      (near(Zone.shop) ? shopOccupancy : 0) +
      (city.covered(x, y, Service.bus) ? busOccupancy : 0) +
      (city.covered(x, y, Service.clinic) ? clinicOccupancy : 0);
}

/// People living in the home at (x, y).
int residentsAt(City city, int x, int y) {
  final l = city.lotAt(x, y);
  if (l == null || l.zone != Zone.home || city.underConstruction(x, y)) {
    return 0;
  }
  return (homeRoom[city.sizeOf(x, y)] * occupancyAt(city, x, y)).round();
}

/// Everyone living in [city]. Homes never shrink and nothing near them
/// is ever taken away, so this only ever goes up.
int populationOf(City city) => [
      for (final l in city.lots)
        if (l.zone == Zone.home) residentsAt(city, l.x, l.y),
    ].fold(0, (a, b) => a + b);

/// A child's coins.
class Coins {
  const Coins({required this.earned, required this.spent});

  final int earned;
  final int spent;

  /// Never less than nothing, even if two phones built at once.
  int get balance => max(0, earned - spent);
}

/// The coins a thing done at [at] earns: one, one more for every two
/// finished shops and one for a trading house (trade brings business),
/// and whatever the day's happening adds.
int coinsFor(
  DateTime at, {
  required List<CityLot> lots,
  required DateTime Function(DateTime instant) dayOf,
  Happening? happening,
}) {
  final day = dayOf(at);
  final built = [
    for (final l in lots)
      if (dayOf(l.at).isBefore(day)) l,
  ];
  final shops = built.where((l) => l.zone == Zone.shop).length;
  final market = built.any((l) => l.zone == Zone.market) ? 1 : 0;
  return 1 +
      min<int>(maxTradeCoins, shops ~/ 2 + market) +
      (happeningCoins[happening] ?? 0);
}

/// [member]'s coins: earned by what they did and what their town had at
/// the time, by trading (a coin a good, for both sides of an agreed
/// trade), by selling goods at the trading house, by granting the
/// residents' requests and by the town reaching each of the
/// [populationMilestones] ([population] now: it never goes down, so a
/// milestone once reached stays paid); spent on services.
Coins coinsOf(
  String member, {
  required List<Contribution> contributions,
  required List<CityLot> lots,
  required CityLife life,
  required GoodsLedger goods,
  required List<Trade> trades,
  required List<Sale> sales,
  required DateTime today,
  int population = 0,
}) {
  var earned = milestoneCoins *
      populationMilestones.where((m) => population >= m).length;
  final happenings = <DateTime, Happening?>{};
  for (final c in contributions) {
    if (c.memberId != member || !c.growsWorld) continue;
    final day = life.dayOf(c.at);
    final happening = happenings.putIfAbsent(day, () => life.on(day));
    earned += coinsFor(
      c.at,
      lots: lots,
      dayOf: life.dayOf,
      happening: happening,
    );
  }
  for (final t in trades) {
    if (goods.applied.contains(t.id) && (t.from == member || t.to == member)) {
      earned += t.count;
    }
  }
  for (final s in sales) {
    if (s.member == member && goods.sold.contains(s.id)) {
      earned += s.count * coinsPerGoodSold;
    }
  }
  for (final (_, granted) in life.requestsUntil(today)) {
    if (granted != null) earned += requestReward;
  }
  var spent = 0;
  for (final l in lots) {
    if (l.zone == Zone.service && l.service != null) {
      spent += serviceCosts[l.service]!;
    }
  }
  return Coins(earned: earned, spent: spent);
}

/// Something about to happen in a child's city, to look forward to.
sealed class NextUp {
  const NextUp();
}

/// [left] more things done and what stands at (x, y) grows.
class GrowsSoon extends NextUp {
  const GrowsSoon(this.x, this.y, this.zone, this.left);
  final int x;
  final int y;
  final Zone zone;
  final int left;
}

/// What stands at (x, y) has earned a size and waits for [missing].
class WaitsFor extends NextUp {
  const WaitsFor(this.x, this.y, this.zone, this.missing);
  final int x;
  final int y;
  final Zone zone;
  final Set<Service> missing;
}

/// [left] more things done and the next level opens more land.
class NextLevel extends NextUp {
  const NextLevel(this.level, this.left);
  final int level;
  final int left;
}

/// [left] more homework seen done and the town builds [building].
class NextLearning extends NextUp {
  const NextLearning(this.building, this.left);
  final Civic building;
  final int left;
}

/// The nearest things to look forward to in [city]: whatever waits for a
/// service first (something the child can do about now), then the next
/// level, the next learning building and the soonest growth.
List<NextUp> nextUps(
  City city, {
  required WorldProgress progress,
  required int homeworkSeen,
  int growing = 2,
}) {
  final waiting = <WaitsFor>[];
  final soon = <GrowsSoon>[];
  for (final l in city.lots) {
    if (city.underConstruction(l.x, l.y)) continue;
    final missing = city.missingAt(l.x, l.y);
    if (missing.isNotEmpty) {
      waiting.add(WaitsFor(l.x, l.y, l.zone, missing));
      continue;
    }
    final left = city.toNextSize(l.x, l.y);
    if (left != null) soon.add(GrowsSoon(l.x, l.y, l.zone, left));
  }
  soon.sort((a, b) => a.left.compareTo(b.left));
  final learning = [
    for (final MapEntry(key: building, value: needs)
        in City.homeworkFor.entries)
      if (!city.civic.contains(building) && homeworkSeen < needs)
        NextLearning(building, needs - homeworkSeen),
  ]..sort((a, b) => a.left.compareTo(b.left));
  return [
    // One line a service: a fire station fixes every tower waiting for it.
    for (final s in Service.values)
      if (waiting.where((w) => w.missing.contains(s)).firstOrNull case final w?)
        w,
    NextLevel(progress.level + 1, progress.room - progress.filled),
    if (learning.isNotEmpty) learning.first,
    ...soon.take(growing),
  ];
}

/// One thing a child can have in their book: a building at a size, a
/// town building, a special building, a service or a happening.
typedef Collectible = String;

/// Everything there is to collect, in the order the book shows it.
final List<Collectible> allCollectibles = [
  for (var i = 0; i < City.homeSizes.length; i++) 'home:$i',
  for (var i = 0; i < City.parkSizes.length; i++) 'park:$i',
  for (var i = 0; i < 3; i++) 'shop:$i',
  'market',
  for (final c in Civic.values) 'civic:${c.name}',
  for (final s in Service.values) 'service:${s.name}',
  for (final l in Landmark.values) 'landmark:${l.name}',
  for (final h in Happening.values) 'happening:${h.name}',
];

/// What [city] has to show, and what its child was there for. Nothing
/// is ever smaller, so what stands now is everything it has had.
Set<Collectible> collected(City city, Set<Happening> seen) => {
      for (final l in city.lots)
        if (!city.underConstruction(l.x, l.y))
          ...switch (l.zone) {
            Zone.home || Zone.park || Zone.shop => [
                for (var i = 0; i <= city.sizeOf(l.x, l.y); i++)
                  '${l.zone.name}:$i',
              ],
            Zone.market => ['market'],
            Zone.landmark when l.landmark != null => [
                'landmark:${l.landmark!.name}',
              ],
            Zone.service when l.service != null => [
                'service:${l.service!.name}',
              ],
            _ => const <String>[],
          },
      for (final c in city.civic) 'civic:${c.name}',
      for (final h in seen) 'happening:${h.name}',
    };
