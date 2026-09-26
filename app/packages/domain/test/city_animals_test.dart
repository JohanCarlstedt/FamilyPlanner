import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Animals in the town: the zoo and the farm fill up as the child keeps
/// going, a farm's animals bring a coin each, and a zoo's can escape.
void main() {
  final start = DateTime.utc(2026, 10, 5, 8);

  List<Contribution> chores(int n, {DateTime? from}) => [
        for (var i = 0; i < n; i++)
          Contribution(
            memberId: 'maja',
            at: (from ?? start).add(Duration(days: 1, minutes: i)),
            growsWorld: true,
          ),
      ];

  City city(List<Contribution> done, List<CityLot> lots) => cityOf(
        'maja',
        contributions: done,
        lots: lots,
        jarEverFull: false,
        today: DateTime.utc(2026, 12, 1),
      );

  final zoo = CityLot(
    x: 8,
    y: 8,
    zone: Zone.landmark,
    landmark: Landmark.zoo,
    at: start,
  );

  group('the zoo', () {
    test('opens with one animal and gets another every few things done', () {
      expect(city(const [], [zoo]).zooAnimals, hasLength(1));
      expect(city(chores(zooEvery), [zoo]).zooAnimals, hasLength(2));
      expect(
        city(chores(zooEvery * 3 + 1), [zoo]).zooAnimals,
        hasLength(4),
      );
    });

    test('has room for every kind once, and no more', () {
      final animals = city(chores(200), [zoo]).zooAnimals;
      expect(animals, hasLength(ZooAnimal.values.length));
      expect(animals.toSet(), ZooAnimal.values.toSet());
    });

    test('no zoo, no animals', () {
      expect(city(chores(50), const []).zooAnimals, isEmpty);
    });

    test('a zoo being built today has none yet', () {
      final today = CityLot(
        x: 8,
        y: 8,
        zone: Zone.landmark,
        landmark: Landmark.zoo,
        at: DateTime.utc(2026, 12, 1, 9),
      );
      expect(city(chores(10), [today]).zooAnimals, isEmpty);
    });
  });

  group('a farm', () {
    final grown = start.add(const Duration(days: 3));
    CityLot farm(DateTime at) => CityLot(
          x: 6,
          y: 9,
          zone: Zone.park,
          at: start,
          upgrades: [Upgrade(UpgradePath.farm, at)],
        );

    test('is a way for a park to grow', () {
      expect(City.paths[Zone.park], contains(UpgradePath.farm));
    });

    test('still works like a park for the homes round it', () {
      expect(City.worksLikePark(farm(grown), null), isTrue);
    });

    test('animals move in as the child keeps going, up to a yardful', () {
      // Things done before it became a farm bring none.
      final before = chores(10);
      expect(farmAnimalsOf(farm(grown), before), 1);
      final after = chores(farmEvery * 2, from: grown);
      expect(farmAnimalsOf(farm(grown), after), 3);
      expect(farmAnimalsOf(farm(grown), chores(200, from: grown)), farmMax);
    });

    test('the town counts them the same way', () {
      final done = chores(farmEvery * 2 + 1, from: grown);
      expect(city(done, [farm(grown)]).farmAnimalsAt(6, 9), 3);
      expect(city(done, [farm(grown)]).farmAnimalsAt(1, 1), 0);
    });

    test('a park that is no farm has none', () {
      final park = CityLot(x: 6, y: 9, zone: Zone.park, at: start);
      expect(farmAnimalsOf(park, chores(50)), 0);
    });

    test('every animal that moves in brings a coin', () {
      final done = chores(farmEvery * 2, from: grown);
      Coins coins(List<CityLot> lots) => coinsOf(
            'maja',
            contributions: done,
            lots: lots,
            life: cityLifeOf(
              'maja',
              contributions: const [],
              lots: const [],
              dayOf: (d) => d,
            ),
            goods: const GoodsLedger(balances: {}, applied: {}),
            trades: const [],
            sales: const [],
            today: DateTime.utc(2026, 12, 1),
          );
      final plain = CityLot(x: 6, y: 9, zone: Zone.park, at: start);
      expect(coins([farm(grown)]).earned - coins([plain]).earned, 3);
    });
  });
}
