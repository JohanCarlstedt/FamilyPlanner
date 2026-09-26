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

/// The dice of [memberId]'s city.
int citySeed(String memberId) => _seedOf(memberId);

/// FNV-1a: a stable number from the member a city belongs to.
int _seedOf(String memberId) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(memberId)) {
    h = ((h ^ b) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// What a child can build with a seed. A trading house makes goods to
/// swap with siblings; a landmark is a special building paid for in them;
/// a service keeps the town running and is paid for in coins, not seeds.
enum Zone { home, shop, park, road, market, landmark, service, sport, decor }

/// What a growing town needs (SimCity's power, water and safety). Each
/// covers the plots within [City.serviceReach] of it, and the bigger
/// buildings grow only where they are covered. A fire station also keeps
/// fires away, and a police station thieves.
enum Service { power, water, fire, clinic, bus, police }

/// Something small to make the town the child's own, bought with coins
/// and placed on any free plot.
enum Decor { flowers, bench, lamp, bigTree, flag, statue, fountain }

/// What being active unlocks: the child places each one, free, once they
/// have been active enough times.
enum Sport { pitch, pool, hall }

/// How a building grows a size, chosen by the child when it is ready.
/// Each does something: more people, a garden that works like a park, a
/// shop downstairs that works like a shop, and so on.
enum UpgradePath {
  /// A home: more flats, a quarter more people.
  moreFlats,

  /// A home: a garden, which works like a park for it and its neighbours.
  garden,

  /// A home: a shop downstairs, which works like a shop.
  shopDownstairs,

  /// A shop: a café, which earns like two shops.
  cafe,

  /// A shop: a toy shop, which homes nearby like living near.
  toyShop,

  /// A park: a playground, which homes nearby like living near.
  playground,

  /// A park: woodland, which reaches homes two plots away.
  woodland,
}

/// One step up, as the child chose it, and when.
class Upgrade {
  const Upgrade(this.path, this.at);
  final UpgradePath path;
  final DateTime at;
}

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
    this.service,
    this.paid = const {},
    this.upgrades = const [],
    this.sport,
    this.decor,
  });

  final int x;
  final int y;
  final Zone zone;

  /// For a trading house: what it makes, fixed when it was built.
  final Good? good;

  /// For a special building: which one.
  final Landmark? landmark;

  /// For a service: which one.
  final Service? service;

  /// Goods spent on it when it was built, beyond its coins: the child
  /// chooses which, so it is kept with the building.
  final Map<Good, int> paid;

  /// When it was placed, as an instant. Placed today, it is still a
  /// construction site the child may change their mind about.
  final DateTime at;

  /// For a sports building: which one.
  final Sport? sport;

  /// For a decoration: which one.
  final Decor? decor;

  /// The steps up the child chose, oldest first.
  final List<Upgrade> upgrades;

  /// Whether [path] was chosen for it by [until] (any time, if null).
  bool took(UpgradePath path, [DateTime? until]) => upgrades.any(
        (u) => u.path == path && (until == null || u.at.isBefore(until)),
      );

  /// A copy with one more step up.
  CityLot upgraded(UpgradePath path, DateTime at) => CityLot(
        x: x,
        y: y,
        zone: zone,
        at: this.at,
        good: good,
        landmark: landmark,
        service: service,
        paid: paid,
        upgrades: [...upgrades, Upgrade(path, at)],
        sport: sport,
        decor: decor,
      );

  /// Whether building it spent a seed: not a street, which is free, nor a
  /// service, which is paid for in coins.
  bool get takesSeed =>
      zone != Zone.road &&
      zone != Zone.service &&
      zone != Zone.sport &&
      zone != Zone.decor;
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
    this.activities = 0,
    required List<CityLot> lots,
    this.projects = const [],
    required int Function(CityLot, DateTime? until) grownBy,
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

  /// How far a service reaches: every plot within this many of it, the
  /// diagonal counted as one step.
  static const serviceReach = 3;

  /// What each size needs around it before it can grow into it. A house
  /// needs nothing; apartments need power and water; a tower a fire
  /// station and a clinic too. A big store needs a bus stop for its
  /// customers, a big park a water tower for its pond.
  static const needs = <Zone, Map<int, Set<Service>>>{
    Zone.home: {
      2: {Service.power, Service.water},
      3: {Service.power, Service.water, Service.fire, Service.clinic},
    },
    Zone.shop: {
      2: {Service.bus},
    },
    Zone.park: {
      3: {Service.water},
    },
  };

  /// Times active before each sports building can be placed.
  static const activitiesFor = <Sport, int>{
    Sport.pitch: 3,
    Sport.pool: 10,
    Sport.hall: 25,
  };

  /// The ways each kind of building can go up a size.
  static const paths = <Zone, List<UpgradePath>>{
    Zone.home: [
      UpgradePath.moreFlats,
      UpgradePath.garden,
      UpgradePath.shopDownstairs,
    ],
    Zone.shop: [UpgradePath.cafe, UpgradePath.toyShop],
    Zone.park: [UpgradePath.playground, UpgradePath.woodland],
  };

  /// The biggest each grows.
  static int maxSize(Zone zone) => switch (zone) {
        Zone.home => homeSizes.length - 1,
        Zone.park => parkSizes.length - 1,
        Zone.shop => 2,
        _ => 0,
      };

  /// From when a building grows a size only when the child chooses how.
  /// Whatever it had grown to by then it keeps, and every step up after
  /// is one they chose.
  static final upgradesFrom = DateTime.utc(2026, 9, 28);

  /// When the town started needing services. Whatever had grown by then
  /// keeps its size: needs only hold back growth after this, so nothing
  /// built before is ever smaller for them (the rule the city rests on).
  static final servicesFrom = DateTime.utc(2026, 9, 27);

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

  /// Times this child has been active, ever.
  final int activities;

  /// Plots with room to build on: open, dry, not a street and empty.
  int get freePlots {
    var n = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (_empty(x, y)) n++;
      }
    }
    return n;
  }

  /// Plots kept free beyond the seeds waiting, for services and
  /// decorations, before the next ring opens by itself.
  static const roomToSpare = 2;

  /// Whether a decoration may go at (x, y): any open, empty ground. What
  /// it costs is the economy's to check (`decorCosts`).
  bool canBuildDecor(int x, int y) => _empty(x, y);

  /// Whether [sport] is unlocked and not yet placed.
  bool canPlaceSport(Sport sport) =>
      activities >= activitiesFor[sport]! &&
      !_lots.values.any((l) => l.sport == sport);

  /// Whether [sport] may go at (x, y): unlocked, not yet placed, on open,
  /// empty ground. Free: being active paid for it.
  bool canBuildSport(int x, int y, Sport sport) =>
      canPlaceSport(sport) && _empty(x, y);

  /// What the family has built together, which stands in every city.
  final List<FamilyProject> projects;

  /// Where each of the family's [projects] stands here: the first plot,
  /// going out from the middle, that is open, dry and free, so it never
  /// lands on anything the child built. Nothing can be built there after.
  late final Map<FamilyProject, (int, int)> projectPlots = () {
    final out = <FamilyProject, (int, int)>{};
    for (final p in projects) {
      search:
      for (var r = 1; r <= size ~/ 2; r++) {
        for (var y = centre - r; y <= centre + r; y++) {
          for (var x = centre - r; x <= centre + r; x++) {
            if (max((x - centre).abs(), (y - centre).abs()) != r) continue;
            if (isOpen(x, y) &&
                !isRoad(x, y) &&
                !isWater(x, y) &&
                !_civicPlot(x, y) &&
                !_lots.containsKey((x, y)) &&
                !out.values.contains((x, y))) {
              out[p] = (x, y);
              break search;
            }
          }
        }
      }
    }
    return out;
  }();

  final Map<(int, int), CityLot> _lots;
  final int Function(CityLot, DateTime? until) _grownBy;
  final bool Function(CityLot) _builtToday;

  Iterable<CityLot> get lots => _lots.values;

  /// Seeds earned and not yet built with. Streets are free, and services
  /// are paid for in coins, so neither takes one.
  int get waiting => seeds - _lots.values.where((l) => l.takesSeed).length;

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

  bool _free(int x, int y) => waiting > 0 && _empty(x, y);

  bool _empty(int x, int y) =>
      isOpen(x, y) &&
      !isRoad(x, y) &&
      !_civicPlot(x, y) &&
      !isWater(x, y) &&
      !_lots.containsKey((x, y)) &&
      !projectPlots.values.contains((x, y));

  /// The trading house, if one is built.
  CityLot? get market =>
      _lots.values.where((l) => l.zone == Zone.market).firstOrNull;

  /// Whether [zone] may go at (x, y) now. A special building is not a
  /// zone to pick: see [canBuildLandmark].
  bool canBuild(int x, int y, Zone zone) =>
      // A street is free: it needs open ground, not a seed.
      (zone == Zone.road ? _empty(x, y) : _free(x, y)) &&
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

  /// Whether a [service] may go at (x, y): on open, empty ground, and a
  /// bus stop by a street. What it costs is the economy's to check
  /// (`serviceCosts`).
  bool canBuildService(int x, int y, Service service) =>
      _empty(x, y) &&
      (service != Service.bus ||
          [(1, 0), (-1, 0), (0, 1), (0, -1)]
              .any((d) => isRoad(x + d.$1, y + d.$2)));

  /// Whether a finished [service] reaches (x, y).
  bool covered(int x, int y, Service service) => _coveredBy(x, y, service, null);

  bool _coveredBy(int x, int y, Service service, DateTime? until) =>
      _lots.values.any(
        (l) =>
            l.zone == Zone.service &&
            l.service == service &&
            _finished(l, until) &&
            max((l.x - x).abs(), (l.y - y).abs()) <= serviceReach,
      );

  /// Finished by [until], or, with none, finished now: a construction site
  /// counts for nothing next door until it is, so changing today's mind
  /// can never shrink a neighbour.
  bool _finished(CityLot l, DateTime? until) =>
      until == null ? !_builtToday(l) : l.at.isBefore(until);

  /// The services that would let what stands at (x, y) grow a size it
  /// has otherwise earned. Empty when nothing is holding it back.
  Set<Service> missingAt(int x, int y) {
    final l = _lots[(x, y)];
    if (l == null) return const {};
    final size = sizeOf(x, y);
    if (_earnedAt(l, null) <= size) return const {};
    return {
      for (final s in needs[l.zone]?[size + 1] ?? const <Service>{})
        if (!covered(x, y, s)) s,
    };
  }

  /// Whether what stands at (x, y) has earned its next size and has what
  /// it needs for it: ready for the child to choose how it grows.
  bool canUpgrade(int x, int y) {
    final l = _lots[(x, y)];
    if (l == null || underConstruction(x, y) || City.paths[l.zone] == null) {
      return false;
    }
    final size = sizeOf(x, y);
    return size < maxSize(l.zone) && _grownTo(l, null) > size;
  }

  /// Things still to do before what stands at (x, y) grows its next size
  /// by being done; null when it grows no further that way.
  int? toNextSize(int x, int y) {
    final l = _lots[(x, y)];
    if (l == null) return null;
    final steps = switch (l.zone) {
      Zone.home => homeSizes,
      Zone.park => parkSizes,
      _ => null,
    };
    if (steps == null) return null;
    final done = _grownBy(l, null);
    for (final need in steps) {
      if (need > done) return need - done;
    }
    return null;
  }

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
  /// park or shop beside it. A shop grows with the finished homes around
  /// it. A size is reached only where the services it [needs] reach;
  /// what had grown before the town had needs keeps its size.
  int sizeOf(int x, int y) {
    final l = _lots[(x, y)];
    if (l == null || City.paths[l.zone] == null) return 0;
    // Grown by itself before the child chose: kept. Every step since is
    // one they took.
    final base = l.at.isBefore(upgradesFrom) ? _grownTo(l, upgradesFrom) : 0;
    return min(base + l.upgrades.length, maxSize(l.zone));
  }

  /// The size [l] would have grown to by itself by [until] (now, if
  /// null): earned, and with the services each size needs. What grew
  /// before the town had needs keeps its size.
  int _grownTo(CityLot l, DateTime? until) {
    final earned = _earnedAt(l, until);
    var size = 0;
    while (size < earned &&
        (needs[l.zone]?[size + 1] ?? const <Service>{})
            .every((s) => _coveredBy(l.x, l.y, s, until))) {
      size++;
    }
    if (l.at.isBefore(servicesFrom)) {
      final before = _earnedAt(
        l,
        until != null && until.isBefore(servicesFrom) ? until : servicesFrom,
      );
      if (before > size) size = before;
    }
    return size;
  }

  /// Whether [n] works like a park by [until]: a park, or a home with a
  /// garden.
  static bool worksLikePark(CityLot n, DateTime? until) =>
      n.zone == Zone.park ||
      (n.zone == Zone.home && n.took(UpgradePath.garden, until));

  /// Whether [n] works like a shop by [until]: a shop, or a home with a
  /// shop downstairs.
  static bool worksLikeShop(CityLot n, DateTime? until) =>
      n.zone == Zone.shop ||
      (n.zone == Zone.home && n.took(UpgradePath.shopDownstairs, until));

  /// The size [l] has earned by [until] from what was done since it was
  /// built and what stands around it, before any needs are counted.
  int _earnedAt(CityLot l, DateTime? until) {
    final around = [
      for (final (dx, dy) in _neighbours)
        if (_lots[(l.x + dx, l.y + dy)] case final n? when _finished(n, until))
          n,
    ];
    final done = _grownBy(l, until);
    switch (l.zone) {
      case Zone.home:
        var size = 0;
        for (var i = 0; i < homeSizes.length; i++) {
          if (done >= homeSizes[i]) size = i;
        }
        // Woodland reaches two plots, not only next door.
        final park = around.any((n) => worksLikePark(n, until)) ||
            _lots.values.any(
              (n) =>
                  n.zone == Zone.park &&
                  n.took(UpgradePath.woodland, until) &&
                  _finished(n, until) &&
                  max((n.x - l.x).abs(), (n.y - l.y).abs()) <= 2,
            );
        final shop = around.any((n) => worksLikeShop(n, until));
        if (park) size++;
        if (!park && !shop && size > bareStreetLimit) size = bareStreetLimit;
        return size < homeSizes.length ? size : homeSizes.length - 1;
      case Zone.shop:
        final homes = around.where((n) => n.zone == Zone.home).length;
        return homes >= 4 ? 2 : (homes >= 2 ? 1 : 0);
      case Zone.park:
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
      case Zone.service:
      case Zone.sport:
      case Zone.decor:
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
  List<FamilyProject> projects = const [],
}) {
  final mine = [
    for (final c in contributions)
      if (c.memberId == memberId && c.growsWorld) c,
  ];
  final progress = worldOf(memberId, contributions);
  final studied = mine.where((c) => c.isHomework).length;
  final day = dayOf ?? (DateTime at) => DateTime.utc(at.year, at.month, at.day);
  final todayDate = DateTime.utc(today.year, today.month, today.day);
  final seed = _seedOf(memberId);
  final taken = {for (final l in lots) (l.x, l.y)};

  City build(int radius) {
    bool open(int x, int y) =>
        (x - City.centre).abs() <= radius && (y - City.centre).abs() <= radius;
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
    return City._(
      seed: seed,
      water: City.lakeFor(seed).difference(taken),
      level: progress.level,
      seeds: progress.seeds,
      radius: radius,
      civic: civic,
      activities: mine.where((c) => c.isActivity).length,
      lots: lots,
      projects: projects,
      grownBy: (l, until) => mine
          .where(
            (c) =>
                c.at.isAfter(l.at) && (until == null || c.at.isBefore(until)),
          )
          .length,
      builtToday: (l) => day(l.at) == todayDate,
    );
  }

  // The level opens the districts, and never less than what already
  // stands in them.
  var radius = (1 + progress.level).clamp(2, City.size ~/ 2);
  for (final l in lots) {
    radius = max(
      radius,
      max((l.x - City.centre).abs(), (l.y - City.centre).abs()),
    );
  }
  var city = build(radius);
  // A full town opens the next ring by itself: with streets free and
  // decorations to place, a child could otherwise have things to build and
  // nowhere to put them. Only ever more land, never less.
  while (radius < City.size ~/ 2 &&
      city.freePlots < city.waiting + City.roomToSpare) {
    radius++;
    city = build(radius);
  }
  return city;
}
