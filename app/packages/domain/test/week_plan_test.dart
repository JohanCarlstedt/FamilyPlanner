import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // The shape a real veckoöversikt has: a header row naming the weekdays,
  // with only Monday dated, and a row per class.
  const table = [
    ['Vecka 39', 'Måndag  21/9', 'Tisdag', 'Onsdag', 'Torsdag', 'Fredag'],
    [
      '5A',
      'Ma: läxa magma + diagnos kap. 1',
      'Studiedag',
      'SO: Repetera s 52-55 Medeltiden',
      'Vildmarksleden NO: Fundera på vad man behöver',
      'Sv: Läsuppdrag och veckans ord Eng: glosor v 39',
    ],
    [
      '5B',
      'Ma: läxa magma + diagnos kap. 1',
      'Studiedag',
      'SO: Repetera s 52-55 Medeltiden',
      '',
      'Sv: Läsuppdrag och veckans ord',
    ],
  ];

  List<WeekPlanEntry> read() =>
      readWeekPlan(table, timeZone: 'Europe/Stockholm');

  test('the classes in it are offered, so a family can pick theirs', () {
    expect(classesIn(table), ['5A', '5B']);
  });

  test('a cell belongs to the day its column is headed with', () {
    final maths = read().firstWhere((e) => e.title.contains('magma'));

    // Monday is dated in the header; the rest count on from it.
    expect(maths.dueAt, DateTime.utc(2026, 9, 21));
    expect(maths.group, '5A');

    final so = read().firstWhere((e) => e.title.contains('Medeltiden'));
    expect(so.dueAt, DateTime.utc(2026, 9, 23));
  });

  test('two subjects in one cell are two pieces of homework', () {
    final friday = [
      for (final e in read())
        if (e.group == '5A' && e.dueAt == DateTime.utc(2026, 9, 25)) e,
    ];

    expect(friday, hasLength(2));
    expect(friday.map((e) => e.subject), containsAll(['Svenska', 'Engelska']));
    expect(
      friday.firstWhere((e) => e.subject == 'Engelska').title,
      contains('glosor'),
    );
  });

  test('a day off is not homework', () {
    expect(
      read().where((e) => e.title.toLowerCase().contains('studiedag')),
      isEmpty,
    );
  });

  test('each class gets its own, and an empty cell gives nothing', () {
    final b = [for (final e in read()) if (e.group == '5B') e];

    expect(b.map((e) => e.title), isNot(contains(contains('Vildmarksleden'))));
    // Thursday is empty for 5B.
    expect(b.any((e) => e.dueAt == DateTime.utc(2026, 9, 24)), isFalse);
  });

  test('school news in the same table is not homework', () {
    const withNews = [
      ['Vecka 40', 'Måndag  28/9', 'Tisdag', 'Onsdag', 'Torsdag', 'Fredag'],
      [
        '5A',
        'Ma: läxa på Magma',
        'Utvecklingssamtalsdag 0810-1300',
        'Vaccin HPV 5A 08.30',
        '',
        'Sv: Läsuppdrag och veckans ord',
      ],
    ];

    final found = readWeekPlan(withNews, timeZone: 'Europe/Stockholm');

    // The maths and the reading are homework; a conference day and a
    // vaccination time are things to read, and were being offered as
    // homework to tick.
    expect(found.map((e) => e.subject), ['Matematik', 'Svenska']);
  });
}
