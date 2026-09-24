/// A child's own city (spec section 3, "Contributions").
///
/// The child chooses what is built and where; the city then grows by
/// itself from what they go on doing. Everything here is counted from two
/// things only — what the child has done, and what they placed where — so
/// every phone draws the same city and there is nothing to edit that would
/// make it bigger.
///
/// The rule the whole reward rests on: nothing ever gets smaller. There is
/// no bulldozer, nothing burns down, and a quiet week takes nothing away.
library;

import 'dart:convert';
import 'dart:math';

import 'contributions.dart';
import 'trading.dart';

/// A number in [0, 1) fixed by [seed], a plot and a [salt]: the city's
/// dice. The same on every phone and every opening, and different from
/// one child's city to the next.
double cityNoise(int seed, int x, int y, int salt) {
  var h =
      (x * 374761393 + y * 668265263 + salt * 982451653 + seed * 2654435761) &
          0xffffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff;
  return ((h ^ (h >> 16)) & 0xffffffff) / 4294967296;
}

/// FNV-1a: a stable number from the member a city belongs to.
int _seedOf(String memberId) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(memberId)) {
    h = ((h ^ b) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// What a child can build with a seed. A trading house makes goods to
/// swap with siblings; a landmark is a special building paid for in them.
enum Zone { home, shop, park, road, market, landmark }

/// What the town builds for itself: a hall from the start, learning from
/// homework, and a fountain once the family's jar has ever been full.
enum Civic { hall, school, library, observatory, university, fountain }

/// Something the child placed: where, what, and when.
class CityLot {
  const CityLot({
    required this.x,
    required this.y,
    required this.zone,
    required this.at,
    this.good,
    this.landmark,
  });

  final int x;
  final int y;
  final Zone zone;

  /// For a trading house: what it makes, fixed when it was built.
  final Good? good;

  /// For a special building: which one.
  final Landmark? landmark;

  /// When it was placed, as an instant. Placed today, it is still a
  /// construction site the child may change their mind about.
  final DateTime at;
}

/// A child's city as it stands.
class City {
  City._({
    required this.seed,
    required this.water,
    required this.level,
    required this.seeds,
    required this.radius,
    required this.civic,
    required List<CityLot> lots,
    required int Function(CityLot) grownBy,
    required bool Function(CityLot) builtToday,
  })  : _lots = {for (final l in lots) (l.x, l.y): l},
        _grownBy = grownBy,
        _builtToday = builtToday;

  /// The map is this many plots across, and the town starts in the middle
  /// of it and spreads out one district at a time.
  static const size = 15;
  static const centre = size ~/ 2;

  /// Plots the town keeps for its own buildings. Placed round the middle
  /// so the first ones stand in the first district.
  static const civicPlots = <Civic, (int, int)>{
    Civic.hall: (6, 6),
    Civic.school: (6, 8),
    Civic.library: (8, 6),
    Civic.fountain: (5, 5),
    Civic.observatory: (4, 9),
    Civic.university: (10, 4),
  };

  /// Homework seen done, ever, before each learning building stands.
  static const homeworkFor = <Civic, int>{
    Civic.school: 3,
    Civic.library: 10,
    Civic.observatory: 25,
    Civic.university: 45,
  };

  /// Contributions made after a home was built, before it grows a size:
  /// cottage, house, apartments, tower. Spread out, so a city that has
  /// been going a while still has cottages among its blocks.
  static const homeSizes = [0, 6, 18, 40];

  /// The district a trading house opens with: a town needs a little
  /// size before it has anything to trade.
  static const marketLevel = 2;

  /// Contributions made after a park was laid out, before it grows a
  /// size: a lawn and a sapling, trees and a bench, a pond or a
  /// playground, a big park with a pavilion.
  static const parkSizes = [0, 4, 12, 28];

  /// Finished homes round a park before it grows a size ahead: a park
  /// people live beside gets used, and looked after.
  static const parkNeighbours = 3;

  /// The tallest a home grows with no park or shop beside it. A tower
  /// needs somewhere to go, the way land value works in SimCity.
  static const bareStreetLimit = 2;

  /// This city's dice: from who it belongs to, so each child's town grows
  /// its own way and looks the same on every phone.
  final int seed;

  /// The lake: plots nobody builds on, which the town grows round.
  final Set<(int, int)> water;

  /// Which district the child is on, from 1 — the same levels a world
  /// always had, so a level still means the same amount done.
  final int level;

  /// Everything this child has earned, ever. One seed builds one thing.
  final int seeds;

  /// How far from the middle the open districts reach.
  final int radius;

  /// What the town has built for itself.
  final Set<Civic> civic;

  final Map<(int, int), CityLot> _lots;
  final int Function(CityLot) _grownBy;
  final bool Function(CityLot) _builtToday;

  Iterable<CityLot> get lots => _lots.values;

  /// Seeds earned and not yet built with.
  int get waiting => seeds - _lots.length;

  bool isOpen(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < size &&
      y < size &&
      (x - centre).abs() <= radius &&
      (y - centre).abs() <= radius;

  /// The main street through the middle, and the streets that come with
  /// each ring of districts. A child adds side streets; these are there.
  bool isRoad(int x, int y) =>
      _street(x, y) || _lots[(x, y)]?.zone == Zone.road;

  static bool _street(int x, int y) =>
      x == centre ||
      y == centre ||
      (x - centre).abs() == 4 ||
      (y - centre).abs() == 4;

  static bool _civicPlot(int x, int y) =>
      civicPlots.values.any((p) => p.$1 == x && p.$2 == y);

  bool isWater(int x, int y) => water.contains((x, y));

  CityLot? lotAt(int x, int y) => _lots[(x, y)];

  bool _free(int x, int y) =>
      waiting > 0 &&
      isOpen(x, y) &&
      !isRoad(x, y) &&
      !_civicPlot(x, y) &&
      !isWater(x, y) &&
      !_lots.containsKey((x, y));

  /// The trading house, if one is built.
  CityLot? get market =>
      _lots.values.where((l) => l.zone == Zone.market).firstOrNull;

  /// Whether [zone] may go at (x, y) now. A special building is not a
  /// zone to pick: see [canBuildLandmark].
  bool canBuild(int x, int y, Zone zone) =>
      _free(x, y) &&
      switch (zone) {
        // Homework unlocks the high street: a town with nothing to learn
        // from has nowhere to shop yet.
        Zone.shop => civic.contains(Civic.school),
        // One trading house, from the second district.
        Zone.market => level >= marketLevel && market == null,
        Zone.landmark => false,
        _ => true,
      };

  /// Whether [landmark] may go at (x, y) with the goods in [have]: one of
  /// each per city, after the trading house, paid for in full. A harbour
  /// stands on the shore.
  bool canBuildLandmark(
    int x,
    int y,
    Landmark landmark,
    Map<Good, int> have,
  ) =>
      _free(x, y) &&
      market != null &&
      !_lots.values.any((l) => l.landmark == landmark) &&
      landmarkCosts[landmark]!
          .entries
          .every((e) => (have[e.key] ?? 0) >= e.value) &&
      (landmark != Landmark.harbour ||
          [(1, 0), (-1, 0), (0, 1), (0, -1)]
              .any((d) => isWater(x + d.$1, y + d.$2)));

  /// Placed today: still a construction site.
  bool underConstruction(int x, int y) {
    final l = _lots[(x, y)];
    return l != null && _builtToday(l);
  }

  /// Only today's may be changed. From tomorrow it is there for good.
  bool canChange(int x, int y) => underConstruction(x, y);

  /// How big what stands at (x, y) has grown, from 0.
  ///
  /// A home grows as the child goes on doing things after building it, a
  /// size ahead beside a finished park, and only becomes a tower with a
  /// park or shop beside it. A shop grows with the
  /// finished homes around it. A construction site counts for nothing
  /// next door until it is finished, so changing today's mind can never
  /// shrink a neighbour.
  int sizeOf(int x, int y) {
    final l = _lots[(x, y)];
    if (l == null) return 0;
    final around = [
      for (final (dx, dy) in _neighbours)
        if (_lots[(x + dx, y + dy)] case final n? when !_builtToday(n)) n,
    ];
    switch (l.zone) {
      case Zone.home:
        final done = _grownBy(l);
        var size = 0;
        for (var i = 0; i < homeSizes.length; i++) {
          if (done >= homeSizes[i]) size = i;
        }
        final park = around.any((n) => n.zone == Zone.park);
        final shop = around.any((n) => n.zone == Zone.shop);
        if (park) size++;
        if (!park && !shop && size > bareStreetLimit) size = bareStreetLimit;
        return size < homeSizes.length ? size : homeSizes.length - 1;
      case Zone.shop:
        final homes = around.where((n) => n.zone == Zone.home).length;
        return homes >= 4 ? 2 : (homes >= 2 ? 1 : 0);
      case Zone.park:
        final done = _grownBy(l);
        var size = 0;
        for (var i = 0; i < parkSizes.length; i++) {
          if (done >= parkSizes[i]) size = i;
        }
        final homes = around.where((n) => n.zone == Zone.home).length;
        if (homes >= parkNeighbours) size++;
        return size < parkSizes.length ? size : parkSizes.length - 1;
      case Zone.road:
      case Zone.market:
      case Zone.landmark:
        return 0;
    }
  }

  /// The lake for [seed]: a few plots grown from one, three or more out
  /// from the middle so the first patch is all land. Decided from the seed
  /// alone, never from what is built, so building somewhere can never
  /// move it; a plot already built on before there were lakes keeps its
  /// building and is simply not water.
  static Set<(int, int)> lakeFor(int seed) {
    bool fits((int, int) p) {
      final (x, y) = p;
      final away = max((x - centre).abs(), (y - centre).abs());
      return x >= 0 &&
          y >= 0 &&
          x < size &&
          y < size &&
          away >= 3 &&
          !_street(x, y) &&
          !_civicPlot(x, y);
    }

    final spots = [
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
          if (fits((x, y))) (x, y),
    ];
    final anchor =
        spots[(cityNoise(seed, 0, 0, 1) * spots.length).floor() % spots.length];
    final want = 2 + (cityNoise(seed, 0, 0, 2) * 5).floor();
    final lake = <(int, int)>{anchor};
    const steps = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    for (var i = 0; lake.length < want && i < 60; i++) {
      final from = lake.elementAt(
        (cityNoise(seed, i, 1, 3) * lake.length).floor() % lake.length,
      );
      final (dx, dy) = steps[(cityNoise(seed, i, 2, 4) * 4).floor() % 4];
      final next = (from.$1 + dx, from.$2 + dy);
      if (fits(next)) lake.add(next);
    }
    return lake;
  }

  static const _neighbours = [
    (-1, -1),
    (0, -1),
    (1, -1),
    (-1, 0),
    (1, 0),
    (-1, 1),
    (0, 1),
    (1, 1),
  ];
}

/// [memberId]'s city, from what they have done and what they have built.
///
/// [today] is the family's wall-clock date, and [dayOf] turns an instant
/// into one; together they decide what is still a construction site. The
/// default reads the instant's own date fields, which is right for tests
/// and for callers that pass wall-clock times already.
City cityOf(
  String memberId, {
  required List<Contribution> contributions,
  required List<CityLot> lots,
  required bool jarEverFull,
  required DateTime today,
  DateTime Function(DateTime instant)? dayOf,
}) {
  final mine = [
    for (final c in contributions)
      if (c.memberId == memberId && c.growsWorld) c,
  ];
  final progress = worldOf(memberId, contributions);
  final radius = (1 + progress.level).clamp(2, City.size ~/ 2);
  bool open(int x, int y) =>
      (x - City.centre).abs() <= radius && (y - City.centre).abs() <= radius;

  final studied = mine.where((c) => c.isHomework).length;
  final civic = <Civic>{
    if (mine.isNotEmpty) Civic.hall,
    for (final MapEntry(key: building, value: needs)
        in City.homeworkFor.entries)
      if (studied >= needs) building,
    if (jarEverFull) Civic.fountain,
  }..removeWhere((b) {
      final (x, y) = City.civicPlots[b]!;
      return !open(x, y);
    });

  final day = dayOf ?? (DateTime at) => DateTime.utc(at.year, at.month, at.day);
  final todayDate = DateTime.utc(today.year, today.month, today.day);

  final seed = _seedOf(memberId);
  final taken = {for (final l in lots) (l.x, l.y)};
  return City._(
    seed: seed,
    water: City.lakeFor(seed).difference(taken),
    level: progress.level,
    seeds: progress.seeds,
    radius: radius,
    civic: civic,
    lots: lots,
    grownBy: (l) => mine.where((c) => c.at.isAfter(l.at)).length,
    builtToday: (l) => day(l.at) == todayDate,
  );
}
