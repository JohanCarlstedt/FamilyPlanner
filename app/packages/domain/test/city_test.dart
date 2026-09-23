import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// A child's own city (spec section 3, "Contributions"): they choose what
/// is built and where, and it grows by itself from what they go on doing.
void main() {
  final monday = DateTime.utc(2026, 9, 21, 8);

  List<Contribution> chores(int n, {DateTime? from}) => [
    for (var i = 0; i < n; i++)
      Contribution(
        memberId: 'maja',
        at: (from ?? monday).add(Duration(hours: i)),
        growsWorld: true,
      ),
  ];

  List<Contribution> homework(int n) => [
    for (var i = 0; i < n; i++)
      Contribution(
        memberId: 'maja',
        at: monday.add(Duration(minutes: i)),
        growsWorld: true,
        isHomework: true,
      ),
  ];

  City city(
    List<Contribution> done, {
    List<CityLot> lots = const [],
    bool jarEverFull = false,
    DateTime? today,
  }) => cityOf(
    'maja',
    contributions: done,
    lots: lots,
    jarEverFull: jarEverFull,
    today: today ?? DateTime.utc(2026, 9, 30),
  );

  CityLot lot(int x, int y, Zone zone, {DateTime? at}) =>
      CityLot(x: x, y: y, zone: zone, at: at ?? monday);

  group('the map', () {
    test('a new city is a small patch round the middle, with its streets', () {
      final c = city(const []);
      expect(c.radius, 2);
      expect(c.isOpen(City.centre, City.centre), isTrue);
      expect(c.isOpen(0, 0), isFalse);
      expect(c.isRoad(City.centre, City.centre + 1), isTrue,
          reason: 'the main street runs through the middle');
    });

    test('more districts open as the child goes up a level', () {
      final small = city(chores(3));
      final bigger = city(chores(WorldProgress.firstRoom + 1));
      expect(bigger.level, small.level + 1);
      expect(bigger.radius, greaterThan(small.radius));
    });

    test('it never grows past the edge of the map', () {
      expect(city(chores(400)).radius, lessThanOrEqualTo(City.size ~/ 2));
    });
  });

  group('building', () {
    test('costs one seed, whatever it is', () {
      final c = city(chores(3), lots: [lot(8, 9, Zone.home), lot(9, 8, Zone.park)]);
      expect(c.seeds, 3);
      expect(c.waiting, 1);
    });

    test('only on open, empty ground', () {
      final c = city(chores(5), lots: [lot(8, 9, Zone.home)]);
      expect(c.canBuild(8, 9, Zone.park), isFalse, reason: 'taken');
      expect(c.canBuild(City.centre, City.centre + 1, Zone.home), isFalse,
          reason: 'the main street');
      expect(c.canBuild(0, 0, Zone.home), isFalse, reason: 'not open yet');
      expect(c.canBuild(9, 9, Zone.home), isTrue);
    });

    test('nothing at all without a seed to spend', () {
      final c = city(chores(1), lots: [lot(8, 9, Zone.home)]);
      expect(c.waiting, 0);
      expect(c.canBuild(9, 9, Zone.home), isFalse);
    });

    test('not on the plots kept for the town hall, school and the rest', () {
      final c = city(chores(5));
      for (final plot in City.civicPlots.values) {
        expect(c.canBuild(plot.$1, plot.$2, Zone.home), isFalse);
      }
    });

    test('shops open once the town has a school', () {
      // Homework unlocks the high street: a town of homes and nothing to
      // learn from has nowhere to shop yet.
      expect(city(chores(5)).canBuild(9, 9, Zone.shop), isFalse);
      final schooled = city([...chores(5), ...homework(3)]);
      expect(schooled.civic, contains(Civic.school));
      expect(schooled.canBuild(9, 9, Zone.shop), isTrue);
    });
  });

  group('today is a construction site', () {
    final today = DateTime.utc(2026, 9, 22);

    test('built today can still be changed', () {
      final c = city(
        chores(3),
        lots: [lot(8, 9, Zone.home, at: DateTime.utc(2026, 9, 22, 15))],
        today: today,
      );
      expect(c.underConstruction(8, 9), isTrue);
      expect(c.canChange(8, 9), isTrue);
    });

    test('from tomorrow it is there for good', () {
      // No bulldozer: nothing that has been built is ever lost.
      final c = city(
        chores(3),
        lots: [lot(8, 9, Zone.home, at: DateTime.utc(2026, 9, 21, 15))],
        today: today,
      );
      expect(c.underConstruction(8, 9), isFalse);
      expect(c.canChange(8, 9), isFalse);
    });
  });

  group('growing by itself', () {
    test('a home grows as the child goes on doing things after building it', () {
      final built = lot(8, 9, Zone.home, at: monday);
      final young = city(chores(1), lots: [built]);
      final older = city(
        [...chores(1), ...chores(30, from: monday.add(const Duration(days: 1)))],
        lots: [built],
      );
      expect(young.sizeOf(8, 9), 0);
      expect(older.sizeOf(8, 9), greaterThan(young.sizeOf(8, 9)));
    });

    test('a home beside a park grows a size ahead', () {
      final after = chores(6, from: monday.add(const Duration(days: 1)));
      final alone = city([...chores(2), ...after], lots: [lot(8, 9, Zone.home)]);
      final parked = city(
        [...chores(2), ...after],
        lots: [lot(8, 9, Zone.home), lot(9, 9, Zone.park)],
      );
      expect(parked.sizeOf(8, 9), alone.sizeOf(8, 9) + 1);
    });

    test('a tower needs a park or a shop beside it', () {
      // SimCity's land value: however long a home has stood, it tops out
      // as apartments on a bare street. Where it is built decides how
      // high it goes — which is what makes a city a skyline and not a
      // grid of identical towers.
      final lots = [lot(8, 9, Zone.home)];
      final later = chores(100, from: monday.add(const Duration(days: 1)));
      expect(city([...chores(1), ...later], lots: lots).sizeOf(8, 9), 2);
      expect(
        city([...chores(1), ...later], lots: [...lots, lot(9, 9, Zone.park)])
            .sizeOf(8, 9),
        3,
      );
      final schooled = [...chores(1), ...homework(3), ...later];
      expect(
        city(schooled, lots: [...lots, lot(8, 10, Zone.shop)]).sizeOf(8, 9),
        3,
      );
    });

    test('a shop grows with the homes around it', () {
      final base = [...chores(8), ...homework(3)];
      final lonely = city(base, lots: [lot(9, 9, Zone.shop)]);
      final busy = city(
        base,
        lots: [
          lot(9, 9, Zone.shop),
          lot(8, 9, Zone.home),
          lot(9, 8, Zone.home),
          lot(10, 9, Zone.home),
          lot(9, 10, Zone.home),
        ],
      );
      expect(busy.sizeOf(9, 9), greaterThan(lonely.sizeOf(9, 9)));
    });

    test('nothing ever gets smaller', () {
      // Whatever happens next — more done, more built — every building is
      // at least as big as it was. The rule the whole reward rests on.
      final lots = [lot(8, 9, Zone.home), lot(9, 9, Zone.park)];
      var before = city(chores(4), lots: lots);
      for (var more = 5; more < 60; more += 5) {
        final now = city(chores(more), lots: [...lots, lot(10, 10, Zone.home)]);
        for (final l in lots) {
          expect(now.sizeOf(l.x, l.y), greaterThanOrEqualTo(before.sizeOf(l.x, l.y)));
        }
        before = now;
      }
    });
  });

  group('the town builds its own learning from homework', () {
    test('a town hall from the first thing done', () {
      expect(city(const []).civic, isEmpty);
      expect(city(chores(1)).civic, contains(Civic.hall));
    });

    test('school, library, observatory and university as homework goes on', () {
      expect(city(homework(2)).civic, isNot(contains(Civic.school)));
      expect(city(homework(3)).civic, contains(Civic.school));
      expect(city(homework(10)).civic, contains(Civic.library));
      expect(city(homework(25)).civic, contains(Civic.observatory));
      expect(city(homework(45)).civic, contains(Civic.university));
    });

    test('homework nobody has seen yet builds nothing', () {
      final unseen = [
        for (var i = 0; i < 5; i++)
          Contribution(
            memberId: 'maja',
            at: monday,
            growsWorld: false,
            isHomework: true,
          ),
      ];
      expect(city(unseen).civic, isNot(contains(Civic.school)));
    });

    test('a family jar ever filled puts a fountain in the square', () {
      expect(city(chores(1)).civic, isNot(contains(Civic.fountain)));
      expect(city(chores(1), jarEverFull: true).civic, contains(Civic.fountain));
    });

    test('a civic building only stands once its district is open', () {
      // The university's plot is out past the first district; enough
      // homework alone does not put it in a field.
      final plot = City.civicPlots[Civic.university]!;
      final c = city(homework(45));
      expect(c.civic.contains(Civic.university), c.isOpen(plot.$1, plot.$2));
    });
  });

  test('nobody else is in it', () {
    final leos = [
      for (var i = 0; i < 20; i++)
        Contribution(memberId: 'leo', at: monday, growsWorld: true),
    ];
    expect(city(leos).seeds, 0);
  });
}
