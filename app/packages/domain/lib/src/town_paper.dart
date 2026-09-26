import 'city.dart';
import 'city_life.dart';
import 'contributions.dart';
import 'economy.dart';

/// The town paper: every Monday, what happened in the child's town the
/// week before. Counted from the same things as the town, so it is never
/// stored and every phone prints the same one.
class TownPaper {
  const TownPaper({
    required this.week,
    required this.thingsDone,
    required this.homework,
    required this.built,
    required this.grown,
    required this.opened,
    required this.levelBefore,
    required this.level,
    required this.residentsBefore,
    required this.residents,
    required this.happenings,
    required this.troubles,
    required this.requestsGranted,
  });

  /// The Monday the week began.
  final DateTime week;
  final int thingsDone;
  final int homework;

  /// What the child built, by kind.
  final Map<Zone, int> built;

  /// What grew a size by the child's choice, by the way it grew.
  final Map<UpgradePath, int> grown;

  /// Learning buildings the town opened.
  final Set<Civic> opened;

  final int levelBefore;
  final int level;
  final int residentsBefore;
  final int residents;

  /// What went on in town, day by day.
  final List<Happening> happenings;

  /// Fires put out, thieves and animals caught that week.
  final List<Trouble> troubles;

  final int requestsGranted;

  int get newResidents => residents - residentsBefore;
  bool get levelledUp => level > levelBefore;

  /// The child did nothing that week: the paper says so, kindly, and
  /// still has the town's own news.
  bool get quiet => thingsDone == 0 && built.isEmpty && grown.isEmpty;
}

/// The week the paper out on [today] covers: the one before this week's
/// Monday.
DateTime townPaperWeek(DateTime today) {
  final monday = CityLife.weekOf(today);
  return DateTime.utc(monday.year, monday.month, monday.day - 7);
}

/// [member]'s paper for the [week] starting on that Monday.
TownPaper townPaper(
  String member, {
  required DateTime week,
  required List<Contribution> contributions,
  required List<CityLot> lots,
  required DateTime Function(DateTime instant) dayOf,
  Map<DateTime, DateTime> handled = const {},
  bool jarEverFull = false,
}) {
  final end = DateTime.utc(week.year, week.month, week.day + 7);
  bool inWeek(DateTime at) {
    final d = dayOf(at);
    return !d.isBefore(week) && d.isBefore(end);
  }

  final mine = [
    for (final c in contributions)
      if (c.memberId == member && c.growsWorld) c,
  ];
  // The town as it stood on the Monday, and as it stands at the end.
  City townOn(DateTime day) => cityOf(
        member,
        contributions: [
          for (final c in mine)
            if (dayOf(c.at).isBefore(day)) c,
        ],
        lots: [
          for (final l in lots)
            if (dayOf(l.at).isBefore(day)) l.grownUntil(day, dayOf),
        ],
        jarEverFull: jarEverFull,
        today: day,
        dayOf: dayOf,
      );
  final was = townOn(week);
  final now = townOn(end);
  final life = cityLifeOf(
    member,
    contributions: mine,
    lots: lots,
    dayOf: dayOf,
    handled: handled,
  );
  final lastDay = DateTime.utc(end.year, end.month, end.day - 1);

  final built = <Zone, int>{};
  for (final l in lots) {
    if (inWeek(l.at)) built[l.zone] = (built[l.zone] ?? 0) + 1;
  }
  final grown = <UpgradePath, int>{};
  for (final l in lots) {
    for (final u in l.upgrades) {
      if (inWeek(u.at)) grown[u.path] = (grown[u.path] ?? 0) + 1;
    }
  }
  final done = mine.where((c) => inWeek(c.at)).toList();
  return TownPaper(
    week: week,
    thingsDone: done.length,
    homework: done.where((c) => c.isHomework).length,
    built: built,
    grown: grown,
    opened: now.civic
        .difference(was.civic)
        .where(City.homeworkFor.containsKey)
        .toSet(),
    levelBefore: was.level,
    level: now.level,
    residentsBefore: populationOf(was),
    residents: populationOf(now),
    happenings: [
      for (var i = 0; i < 7; i++)
        if (life.on(DateTime.utc(week.year, week.month, week.day + i))
            case final h?)
          h,
    ],
    troubles: [
      for (final t in life.troublesUntil(lastDay))
        if (t.endedAt case final ended? when inWeek(ended)) t,
    ],
    requestsGranted: life
        .requestsUntil(lastDay)
        .where((r) => r.$1.week == week && r.$2 != null)
        .length,
  );
}
