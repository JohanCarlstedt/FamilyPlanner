import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // A week letter shaped like the ones that actually arrive: a heading, a
  // paragraph nobody needs, and the homework buried in it.
  const letter = '''
Veckobrev vecka 39

Hej alla föräldrar! Vi har haft en fin vecka med höstsol och mycket
arbete i klassrummet. På onsdag har vi friluftsdag, ta med matsäck.

Läxor:
Matematik: sidorna 42-44, till torsdag 24/9
Glosor engelska till fredag
Svenska: läs kapitel 3 i Ronja, klart på måndag 28/9

Prov i NO på tisdag 29/9 om vattnets kretslopp.

Hälsningar
Linus
''';

  List<HomeworkCandidate> read(String text) => readHomeworkLetter(
        text,
        now: DateTime.utc(2026, 9, 21, 6), // Monday of week 39, 08:00 local
        timeZone: 'Europe/Stockholm',
      );

  test('finds the homework and leaves the chat out of it', () {
    final found = read(letter);

    expect(
      found.map((h) => h.title),
      containsAll([
        contains('sidorna 42-44'),
        contains('Glosor'),
        contains('kapitel 3'),
      ]),
    );
    // The friluftsdag paragraph is news, not homework.
    expect(found.map((h) => h.title).join(' '), isNot(contains('matsäck')));
  });

  test('reads the due date, and the weekday when that is all there is', () {
    final found = read(letter);
    final maths = found.firstWhere((h) => h.title.contains('42-44'));
    final glosor = found.firstWhere((h) => h.title.contains('Glosor'));

    // "till torsdag 24/9": the date wins, and it is a wall-clock date.
    expect(maths.dueAt, DateTime.utc(2026, 9, 24));
    // "till fredag" with no date: the next Friday from now.
    expect(glosor.dueAt, DateTime.utc(2026, 9, 25));
  });

  test('a test is homework of its own kind', () {
    final found = read(letter);
    final prov = found.firstWhere((h) => h.title.toLowerCase().contains('no'));

    expect(prov.type, HomeworkType.test);
    expect(prov.dueAt, DateTime.utc(2026, 9, 29));
  });

  test('the subject is picked up when the line names one', () {
    final found = read(letter);

    expect(
      found.firstWhere((h) => h.title.contains('42-44')).subject,
      'Matematik',
    );
    expect(found.firstWhere((h) => h.title.contains('Glosor')).subject,
        'Engelska');
  });

  test('nothing is invented from a letter with no homework in it', () {
    expect(
        read('Hej! Kom ihåg gympakläder på torsdag. Trevlig helg!'), isEmpty);
  });

  test('a date already past is read as next year, not as overdue', () {
    // A letter read in late December mentioning 8/1.
    final found = readHomeworkLetter(
      'Läxa: matematik till 8/1',
      now: DateTime.utc(2026, 12, 28),
      timeZone: 'Europe/Stockholm',
    );

    expect(found.single.dueAt, DateTime.utc(2027, 1, 8));
  });
}
