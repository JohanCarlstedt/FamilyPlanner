import 'package:domain/domain.dart';
import 'package:family/src/features/rewards/city_sprites.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which picture stands on each plot. A city's data never changes for
/// this: the pictures are only a new way of drawing what was built.
void main() {
  final start = DateTime.utc(2026, 8, 1, 8);

  City city(List<CityLot> lots, {int done = 60, String who = 'tuva'}) => cityOf(
    who,
    contributions: [
      for (var i = 0; i < done; i++)
        Contribution(
          memberId: who,
          at: start.add(Duration(hours: i)),
          growsWorld: true,
          isHomework: i % 3 == 0,
        ),
    ],
    lots: lots,
    jarEverFull: false,
    today: DateTime.utc(2026, 12, 1),
  );

  test('a road is the piece its neighbours make', () {
    final c = city(const []);
    const m = City.centre;
    // The middle of the town: main streets all four ways.
    expect(citySpriteName(c, m, m, month: 6), 'road_15');
    // Along the main street, between two plots of it: straight.
    expect(citySpriteName(c, m, m - 1, month: 6), 'road_5');
    expect(citySpriteName(c, m + 1, m, month: 6), 'road_10');
  });

  test('what was built is drawn at its size, from the city\'s own dice', () {
    final lots = [
      CityLot(x: 8, y: 9, zone: Zone.home, at: start),
      CityLot(x: 9, y: 9, zone: Zone.park, at: start),
      CityLot(x: 9, y: 10, zone: Zone.market, at: start, good: Good.fish),
      CityLot(x: 10, y: 9, zone: Zone.landmark, at: start, landmark: Landmark.castle),
    ];
    final c = city(lots);
    final home = citySpriteName(c, 8, 9, month: 6)!;
    expect(home, startsWith('home${c.sizeOf(8, 9)}_'));
    expect(citySpriteName(c, 9, 9, month: 6), startsWith('park${c.sizeOf(9, 9)}_'));
    expect(citySpriteName(c, 9, 10, month: 6), 'market');
    expect(citySpriteName(c, 10, 9, month: 6), 'landmark_castle');
    // The same city, opened again: the same pictures.
    expect(citySpriteName(city(lots), 8, 9, month: 6), home);
  });

  test('what no kit has is drawn as before', () {
    final c = city([
      CityLot(x: 8, y: 9, zone: Zone.landmark, at: start, landmark: Landmark.zoo),
    ]);
    expect(citySpriteName(c, 8, 9, month: 6), isNull);
    final (wx, wy) = c.water.first;
    expect(citySpriteName(c, wx, wy, month: 6), isNull);
    expect(citySpriteName(c, 0, 0, month: 6), isNull, reason: 'not open yet');
  });

  test('trees turn in the autumn', () {
    final c = city(const [], done: 200);
    final trees = [
      for (var y = 0; y < City.size; y++)
        for (var x = 0; x < City.size; x++)
          if (citySpriteName(c, x, y, month: 6) case final s?
              when s.startsWith('tree_'))
            (x, y),
    ];
    expect(trees, isNotEmpty);
    final october = {
      for (final (x, y) in trees) citySpriteName(c, x, y, month: 10),
    };
    expect(october.any((s) => s!.startsWith('treefall_')), isTrue);
  });
}
