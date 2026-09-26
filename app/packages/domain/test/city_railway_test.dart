import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// The railway: a station on the town's edge, its track running straight
/// out to the edge of the map, and trades by train paying a coin more.
void main() {
  final start = DateTime.utc(2026, 10, 5, 8);
  final market = CityLot(
    x: 8,
    y: 8,
    zone: Zone.market,
    good: Good.wood,
    at: start,
  );

  City city(List<CityLot> lots, {int done = 30}) => cityOf(
        'maja',
        contributions: [
          for (var i = 0; i < done; i++)
            Contribution(
              memberId: 'maja',
              at: start.add(Duration(days: 1, minutes: i)),
              growsWorld: true,
            ),
        ],
        lots: lots,
        jarEverFull: false,
        today: DateTime.utc(2026, 12, 1),
      );

  const plenty = {Good.wood: 9, Good.stone: 9, Good.wool: 9};

  test('costs goods from more than one kind', () {
    expect(landmarkCosts[Landmark.station]!.length, greaterThan(1));
  });

  test('goes on the edge of the town, where a track can run out', () {
    final c = city([market]);
    final r = c.radius;
    const mid = City.centre;
    // Somewhere on the edge with nothing in the way outwards.
    final edge = [
      for (var y = mid - r; y <= mid + r; y++)
        for (var x = mid - r; x <= mid + r; x++)
          if (((x - mid).abs() == r || (y - mid).abs() == r) &&
              c.canBuildLandmark(x, y, Landmark.station, plenty))
            (x, y),
    ];
    expect(edge, isNotEmpty);
    // Never in the middle of town.
    for (var y = mid - r + 1; y < mid + r; y++) {
      for (var x = mid - r + 1; x < mid + r; x++) {
        expect(c.canBuildLandmark(x, y, Landmark.station, plenty), isFalse,
            reason: '($x, $y) is inside the town');
      }
    }
  });

  test('a small town can have one too, its track crossing the streets', () {
    final c = city([market], done: 10);
    expect(c.radius, lessThan(4));
    final r = c.radius;
    const mid = City.centre;
    final spots = [
      for (var y = mid - r; y <= mid + r; y++)
        for (var x = mid - r; x <= mid + r; x++)
          if (c.canBuildLandmark(x, y, Landmark.station, plenty)) (x, y),
    ];
    expect(spots, isNotEmpty);
  });

  group('with a station', () {
    City withStation() {
      final c = city([market]);
      final r = c.radius;
      const mid = City.centre;
      final (x, y) = [
        for (var y = mid - r; y <= mid + r; y++)
          for (var x = mid - r; x <= mid + r; x++)
            if (c.canBuildLandmark(x, y, Landmark.station, plenty)) (x, y),
      ].first;
      return city([
        market,
        CityLot(
          x: x,
          y: y,
          zone: Zone.landmark,
          landmark: Landmark.station,
          at: start,
        ),
      ]);
    }

    test('its track runs straight out to the edge of the map', () {
      final c = withStation();
      final station = c.station!;
      final rail = c.railPlots;
      expect(rail, isNotEmpty);
      final (dx, dy) = c.railStep!;
      expect(dx.abs() + dy.abs(), 1);
      var (x, y) = (station.x + dx, station.y + dy);
      final line = <(int, int)>[];
      while (x >= 0 && y >= 0 && x < City.size && y < City.size) {
        line.add((x, y));
        (x, y) = (x + dx, y + dy);
      }
      expect(rail, line);
      // Outwards, away from the middle.
      expect(
        (station.x + dx - City.centre).abs() +
            (station.y + dy - City.centre).abs(),
        greaterThan(
          (station.x - City.centre).abs() + (station.y - City.centre).abs(),
        ),
      );
    });

    test('nothing can be built on the track, not even a street', () {
      final c = withStation();
      for (final (x, y) in c.railPlots) {
        expect(c.canBuild(x, y, Zone.road), isFalse);
        expect(c.canBuild(x, y, Zone.home), isFalse);
      }
    });

    test('only one', () {
      final c = withStation();
      final r = c.radius;
      const mid = City.centre;
      for (var y = mid - r; y <= mid + r; y++) {
        for (var x = mid - r; x <= mid + r; x++) {
          expect(c.canBuildLandmark(x, y, Landmark.station, plenty), isFalse);
        }
      }
    });
  });

  test('no station, no track', () {
    final c = city([market]);
    expect(c.station, isNull);
    expect(c.railPlots, isEmpty);
    expect(c.railStep, isNull);
  });

  test('a trade by train pays a coin more when both ends have a station', () {
    final trade = Trade(
      id: 't1',
      from: 'maja',
      to: 'olle',
      give: Good.wood,
      get: Good.fish,
      count: 2,
      state: TradeState.accepted,
      offeredAt: start,
      answeredAt: start.add(const Duration(hours: 1)),
    );
    Coins coins(Set<String> stations) => coinsOf(
          'maja',
          contributions: const [],
          lots: const [],
          life: cityLifeOf(
            'maja',
            contributions: const [],
            lots: const [],
            dayOf: (d) => d,
          ),
          goods: const GoodsLedger(balances: {}, applied: {'t1'}),
          trades: [trade],
          sales: const [],
          today: DateTime.utc(2026, 12, 1),
          stations: stations,
        );
    expect(coins({'maja', 'olle'}).earned - coins(const {}).earned,
        stationBonus);
    expect(coins({'maja'}).earned, coins(const {}).earned,
        reason: 'a train needs somewhere to go');
  });
}
