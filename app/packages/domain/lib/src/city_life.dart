/// What happens in a child's city by itself (spec section 3,
/// "Contributions"): a day's event and the week's request from someone
/// who lives there.
///
/// Both are rolled from the city's own dice and the date, never stored,
/// so every phone sees the same festival on the same day. Nothing that
/// happens is ever bad: there are no fires, floods or storms, only
/// things to enjoy and small wishes that pay a little when granted. A
/// wish nobody granted simply goes away with its week.
library;

import 'dart:math';

import 'city.dart';
import 'contributions.dart';

/// Something going on in the city today.
enum Happening {
  /// The trading house makes twice as much for what is done today.
  marketDay,

  /// Music in the park and fireworks in the evening; a coin more for
  /// everything done today.
  festival,

  /// Visitors come to see a special building; two coins more for
  /// everything done today.
  touristBus,

  /// Hot-air balloons over the town.
  balloonRace,

  /// A whale in the lake, however it got there.
  whale,

  /// Shooting stars over the observatory, in the evening.
  meteorShower,
}

/// Coins more for each thing done on the day of a happening.
const happeningCoins = <Happening, int>{
  Happening.festival: 1,
  Happening.touristBus: 2,
};

/// Happenings only to be seen. A child who did something that day was
/// there, and it goes in their book.
const sightings = {
  Happening.balloonRace,
  Happening.whale,
  Happening.meteorShower,
};

/// How often a city has anything going on: most days are ordinary, so a
/// festival is something.
const happeningChance = 0.3;

/// What a request asks for.
enum RequestKind {
  /// A park near someone's home.
  parkNear,

  /// A shop near someone's home.
  shopNear,

  /// A new home: someone wants to move in.
  home,

  /// A service the town has none of yet.
  service,
}

/// Coins for granting the week's request.
const requestReward = 3;

/// How near "near" is: this many plots, the diagonal counted as one.
const requestReach = 2;

/// One resident's wish for the week.
class CityRequest {
  const CityRequest({
    required this.kind,
    required this.week,
    required this.who,
    this.x,
    this.y,
    this.service,
  });

  final RequestKind kind;

  /// The Monday the week starts, as date fields.
  final DateTime week;

  /// Who is asking: a first name, the same on every phone.
  final String who;

  /// Where they live, for a request to build near them.
  final int? x;
  final int? y;

  /// For [RequestKind.service]: which one.
  final Service? service;

  /// Whether [l] grants it.
  bool grantedBy(CityLot l) => switch (kind) {
        RequestKind.parkNear => l.zone == Zone.park && _near(l),
        RequestKind.shopNear => l.zone == Zone.shop && _near(l),
        RequestKind.home => l.zone == Zone.home,
        RequestKind.service => l.zone == Zone.service && l.service == service,
      };

  bool _near(CityLot l) =>
      max((l.x - x!).abs(), (l.y - y!).abs()) <= requestReach;
}

/// The people who live in the towns. Short, and known in Sweden and
/// beyond.
const residents = [
  'Lisa', 'Omar', 'Elsa', 'Noah', 'Alva', 'Ali', 'Wilma', 'Hugo', //
  'Saga', 'Liam', 'Ebba', 'Nils', 'Stella', 'Adam', 'Iris', 'Leo',
];

/// A child's city through time: what was there on a given day, and so
/// what happened in it. Counted from the same two things as the city.
class CityLife {
  CityLife({
    required this.seed,
    required this.lake,
    required List<CityLot> lots,
    required List<Contribution> mine,
    required this.dayOf,
  })  : _lots = [...lots]..sort((a, b) => a.at.compareTo(b.at)),
        _mine = [...mine]..sort((a, b) => a.at.compareTo(b.at));

  final int seed;

  /// The city's lake, from its seed.
  final Set<(int, int)> lake;

  /// The family's wall-clock date of an instant, as `DateTime.utc` fields.
  final DateTime Function(DateTime instant) dayOf;

  final List<CityLot> _lots;
  final List<Contribution> _mine;

  static int _dayNumber(DateTime day) =>
      day.difference(DateTime.utc(2026)).inDays;

  /// Finished by [day]: built on an earlier day.
  List<CityLot> _before(DateTime day) => [
        for (final l in _lots)
          if (dayOf(l.at).isBefore(day)) l,
      ];

  /// What is going on in the city on [day], if anything. Only from the
  /// day the town came alive (`City.servicesFrom`).
  Happening? on(DateTime day) {
    if (day.isBefore(City.servicesFrom)) return null;
    final n = _dayNumber(day);
    if (cityNoise(seed, n, 0, 71) >= happeningChance) return null;
    final built = _before(day);
    final done = [
      for (final c in _mine)
        if (dayOf(c.at).isBefore(day)) c,
    ];
    var level = 1;
    var left = done.length;
    while (left >= WorldProgress.roomAt(level)) {
      left -= WorldProgress.roomAt(level);
      level++;
    }
    final studied = done.where((c) => c.isHomework).length;
    final can = [
      if (built.any((l) => l.zone == Zone.market)) Happening.marketDay,
      if (built.any((l) => l.zone == Zone.park)) Happening.festival,
      if (built.any((l) => l.zone == Zone.landmark)) Happening.touristBus,
      if (level >= 2) Happening.balloonRace,
      if (lake.length >= 3) Happening.whale,
      if (studied >= City.homeworkFor[Civic.observatory]!)
        Happening.meteorShower,
    ];
    if (can.isEmpty) return null;
    return can[(cityNoise(seed, n, 1, 72) * can.length).floor() % can.length];
  }

  /// The Monday of [day]'s week.
  static DateTime weekOf(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day - (day.weekday - 1));

  /// The request someone in the city makes in the week starting
  /// [monday], from the city as it stood that morning. Weeks start
  /// with the one the town came alive in.
  CityRequest? requestFor(DateTime monday) {
    if (monday.isBefore(weekOf(City.servicesFrom))) return null;
    final n = _dayNumber(monday) ~/ 7;
    final built = _before(monday);
    final homes = [
      for (final l in built)
        if (l.zone == Zone.home) l,
    ];
    final has = {
      for (final l in built)
        if (l.service != null) l.service!,
    };
    final wanted = [...Service.values]..sort(
        (a, b) => cityNoise(seed, a.index, n, 84)
            .compareTo(cityNoise(seed, b.index, n, 84)),
      );
    final missing = wanted.where((s) => !has.contains(s)).firstOrNull;
    final kinds = [
      RequestKind.home,
      if (homes.isNotEmpty) RequestKind.parkNear,
      if (homes.isNotEmpty && built.any((l) => l.zone == Zone.shop))
        RequestKind.shopNear,
      if (homes.length >= 4 && missing != null) RequestKind.service,
    ];
    final kind = kinds[
        (cityNoise(seed, n, 0, 81) * kinds.length).floor() % kinds.length];
    final who = residents[
        (cityNoise(seed, n, 2, 83) * residents.length).floor() %
            residents.length];
    final home = homes.isEmpty
        ? null
        : homes[
            (cityNoise(seed, n, 1, 82) * homes.length).floor() % homes.length];
    return CityRequest(
      kind: kind,
      week: monday,
      who: who,
      x: home?.x,
      y: home?.y,
      service: kind == RequestKind.service ? missing : null,
    );
  }

  /// What granted [request], if anything: the first thing built in its
  /// week that does.
  CityLot? grantOf(CityRequest request) {
    final end = request.week.add(const Duration(days: 7));
    for (final l in _lots) {
      final day = dayOf(l.at);
      if (day.isBefore(request.week) || !day.isBefore(end)) continue;
      if (request.grantedBy(l)) return l;
    }
    return null;
  }

  /// Every request up to the week of [today], with what granted it.
  List<(CityRequest, CityLot?)> requestsUntil(DateTime today) {
    final out = <(CityRequest, CityLot?)>[];
    for (var week = weekOf(City.servicesFrom);
        !week.isAfter(today);
        week = DateTime.utc(week.year, week.month, week.day + 7)) {
      if (requestFor(week) case final r?) out.add((r, grantOf(r)));
    }
    return out;
  }

  /// The happenings the child was there for: a day they did something.
  Set<Happening> seenUntil(DateTime today) {
    final days = {for (final c in _mine) dayOf(c.at)};
    return {
      for (final d in days)
        if (!d.isAfter(today))
          if (on(d) case final h?) h,
    };
  }
}

/// [memberId]'s city through time.
CityLife cityLifeOf(
  String memberId, {
  required List<Contribution> contributions,
  required List<CityLot> lots,
  required DateTime Function(DateTime instant) dayOf,
}) {
  final seed = citySeed(memberId);
  return CityLife(
    seed: seed,
    lake: City.lakeFor(seed),
    lots: lots,
    mine: [
      for (final c in contributions)
        if (c.memberId == memberId && c.growsWorld) c,
    ],
    dayOf: dayOf,
  );
}
