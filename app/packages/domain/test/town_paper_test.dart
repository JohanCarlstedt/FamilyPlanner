import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// The town paper: every Monday, what happened in the child's town the
/// week before, counted from the same things as the town itself.
void main() {
  DateTime day(DateTime at) => DateTime.utc(at.year, at.month, at.day);
  // Monday 12 October 2026, and the week before it.
  final week = DateTime.utc(2026, 10, 5);
  final nextMonday = DateTime.utc(2026, 10, 12);

  Contribution done(DateTime at, {bool homework = false}) => Contribution(
        memberId: 'maja',
        at: at,
        growsWorld: true,
        isHomework: homework,
      );

  final before = DateTime.utc(2026, 9, 20, 8);
  final earlier = [
    for (var i = 0; i < 6; i++) done(before.add(Duration(hours: i))),
  ];
  final oldLots = [
    CityLot(x: 7, y: 8, zone: Zone.home, at: before),
    CityLot(x: 8, y: 8, zone: Zone.park, at: before),
  ];
  final thisWeek = [
    for (var i = 0; i < 5; i++)
      done(week.add(Duration(days: i, hours: 16)), homework: i < 3),
  ];
  final newLots = [
    CityLot(x: 6, y: 8, zone: Zone.home, at: week.add(const Duration(hours: 17))),
    CityLot(
      x: 6,
      y: 9,
      zone: Zone.shop,
      at: week.add(const Duration(days: 1, hours: 17)),
    ),
    CityLot(
      x: 6,
      y: 10,
      zone: Zone.road,
      at: week.add(const Duration(days: 2, hours: 17)),
    ),
  ];

  TownPaper paper({
    List<Contribution>? contributions,
    List<CityLot>? lots,
    Map<DateTime, DateTime> handled = const {},
  }) =>
      townPaper(
        'maja',
        week: week,
        contributions: contributions ?? [...earlier, ...thisWeek],
        lots: lots ?? [...oldLots, ...newLots],
        dayOf: day,
        handled: handled,
      );

  test('covers the week before the Monday it comes out', () {
    expect(paper().week, week);
    expect(townPaperWeek(DateTime.utc(2026, 10, 14)), week,
        reason: 'on Wednesday, still last week\'s paper');
    expect(townPaperWeek(nextMonday), week);
  });

  test('what was done and built that week, and nothing from before', () {
    final p = paper();
    expect(p.thingsDone, 5);
    expect(p.homework, 3);
    expect(p.built, {Zone.home: 1, Zone.shop: 1, Zone.road: 1});
  });

  test('the learning building homework opened that week', () {
    // The school needs three pieces of homework, all done this week.
    expect(paper().opened, contains(Civic.school));
  });

  test('who moved in', () {
    final p = paper();
    expect(p.residents, greaterThan(p.residentsBefore));
    expect(p.newResidents, p.residents - p.residentsBefore);
  });

  test('buildings grown by the child\'s choice that week', () {
    final grown = [
      CityLot(
        x: 7,
        y: 8,
        zone: Zone.home,
        at: before,
        upgrades: [
          Upgrade(UpgradePath.garden, week.add(const Duration(days: 3))),
        ],
      ),
      oldLots[1],
    ];
    expect(paper(lots: grown).grown, {UpgradePath.garden: 1});
  });

  test('happenings in town that week', () {
    final p = paper();
    final life = cityLifeOf(
      'maja',
      contributions: [...earlier, ...thisWeek],
      lots: [...oldLots, ...newLots],
      dayOf: day,
    );
    expect(p.happenings, [
      for (var i = 0; i < 7; i++)
        if (life.on(week.add(Duration(days: i))) case final h?) h,
    ]);
  });

  test('a quiet week is quiet', () {
    final p = paper(contributions: earlier, lots: oldLots);
    expect(p.thingsDone, 0);
    expect(p.built, isEmpty);
    expect(p.quiet, isTrue);
    expect(paper().quiet, isFalse);
  });
}
