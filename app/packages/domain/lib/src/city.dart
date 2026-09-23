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

import 'contributions.dart';

/// What a child can build with a seed.
enum Zone { home, shop, park, road }

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
  });

  final int x;
  final int y;
  final Zone zone;

  /// When it was placed, as an instant. Placed today, it is still a
  /// construction site the child may change their mind about.
  final DateTime at;
}

/// A child's city as it stands.
class City {
  City._({
    required this.level,
    required this.seeds,
    required this.radius,
    required this.civic,
    required List<CityLot> lots,
    required int Function(CityLot) grownBy,
    required bool Function(CityLot) builtToday,
  }) : _lots = {for (final l in lots) (l.x, l.y): l},
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
  /// cottage, house, apartments, tower.
  static const homeSizes = [0, 5, 12, 24];

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
      x == centre ||
      y == centre ||
      (x - centre).abs() == 4 ||
      (y - centre).abs() == 4 ||
      _lots[(x, y)]?.zone == Zone.road;

  bool _civicPlot(int x, int y) =>
      civicPlots.values.any((p) => p.$1 == x && p.$2 == y);

  CityLot? lotAt(int x, int y) => _lots[(x, y)];

  /// Whether [zone] may go at (x, y) now.
  bool canBuild(int x, int y, Zone zone) =>
      waiting > 0 &&
      isOpen(x, y) &&
      !isRoad(x, y) &&
      !_civicPlot(x, y) &&
      !_lots.containsKey((x, y)) &&
      // Homework unlocks the high street: a town with nothing to learn
      // from has nowhere to shop yet.
      (zone != Zone.shop || civic.contains(Civic.school));

  /// Placed today: still a construction site.
  bool underConstruction(int x, int y) {
    final l = _lots[(x, y)];
    return l != null && _builtToday(l);
  }

  /// Only today's may be changed. From tomorrow it is there for good.
  bool canChange(int x, int y) => underConstruction(x, y);

  /// How big what stands at (x, y) has grown, from 0.
  ///
  /// A home grows as the child goes on doing things after building it,
  /// and a size ahead beside a finished park. A shop grows with the
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
        if (around.any((n) => n.zone == Zone.park)) size++;
        return size < homeSizes.length ? size : homeSizes.length - 1;
      case Zone.shop:
        final homes = around.where((n) => n.zone == Zone.home).length;
        return homes >= 4 ? 2 : (homes >= 2 ? 1 : 0);
      case Zone.park:
      case Zone.road:
        return 0;
    }
  }

  static const _neighbours = [
    (-1, -1), (0, -1), (1, -1),
    (-1, 0), (1, 0),
    (-1, 1), (0, 1), (1, 1),
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
    for (final MapEntry(key: building, value: needs) in City.homeworkFor.entries)
      if (studied >= needs) building,
    if (jarEverFull) Civic.fountain,
  }..removeWhere((b) {
      final (x, y) = City.civicPlots[b]!;
      return !open(x, y);
    });

  final day = dayOf ?? (DateTime at) => DateTime.utc(at.year, at.month, at.day);
  final todayDate = DateTime.utc(today.year, today.month, today.day);

  return City._(
    level: progress.level,
    seeds: progress.seeds,
    radius: radius,
    civic: civic,
    lots: lots,
    grownBy: (l) => mine.where((c) => c.at.isAfter(l.at)).length,
    builtToday: (l) => day(l.at) == todayDate,
  );
}
