import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// "That's me": the child is one of the people in their own town, lives
/// in a home they choose, and makes it theirs with things bought with
/// coins.
void main() {
  final start = DateTime.utc(2026, 10, 5, 8);

  List<Contribution> chores(int n) => [
        for (var i = 0; i < n; i++)
          Contribution(
            memberId: 'maja',
            at: start.add(Duration(days: 1, minutes: i)),
            growsWorld: true,
          ),
      ];

  City city(List<CityLot> lots) => cityOf(
        'maja',
        contributions: chores(10),
        lots: lots,
        jarEverFull: false,
        today: DateTime.utc(2026, 12, 1),
      );

  final home = CityLot(x: 7, y: 8, zone: Zone.home, at: start);
  final park = CityLot(x: 8, y: 8, zone: Zone.park, at: start);

  group('my home', () {
    test('is a home the child has built', () {
      final c = city([home, park]);
      expect(const CityMe(home: (7, 8)).homeIn(c), (7, 8));
      expect(canBeMyHome(c, 7, 8), isTrue);
      expect(canBeMyHome(c, 8, 8), isFalse, reason: 'a park is no home');
      expect(canBeMyHome(c, 3, 3), isFalse, reason: 'nothing stands there');
    });

    test('is nowhere once no home stands there, and nothing is lost', () {
      // Changed on the day it was built into a park: the choice waits for
      // a home, and what was bought for it is kept.
      final c = city([park.copyWithAt(7, 8)]);
      const me = CityMe(home: (7, 8), touches: {HomeTouch.flowers});
      expect(me.homeIn(c), isNull);
      expect(me.touches, {HomeTouch.flowers});
    });

    test('no home chosen is no home', () {
      expect(const CityMe().homeIn(city([home])), isNull);
    });
  });

  group('who I am', () {
    test('a look the town has a picture of', () {
      expect(CityMe.looks, hasLength(9));
      expect(CityMe.looks, contains('w'), reason: 'one in a wheelchair');
      expect(const CityMe(look: '3').lookIn, '3');
      // A look a later version added is not guessed at here.
      expect(const CityMe(look: 'robot').lookIn, isNull);
    });
  });

  group('touches for my home', () {
    test('cost coins, each once', () {
      expect(homeTouchCosts.keys.toSet(), HomeTouch.values.toSet());
      expect(
        const CityMe(touches: {HomeTouch.flowers, HomeTouch.lights}).spent,
        homeTouchCosts[HomeTouch.flowers]! + homeTouchCosts[HomeTouch.lights]!,
      );
    });

    test('are paid for out of the town\'s coins', () {
      final done = chores(10);
      final lots = [home];
      Coins coins({Set<HomeTouch> touches = const {}}) => coinsOf(
            'maja',
            contributions: done,
            lots: lots,
            life: cityLifeOf('maja',
                contributions: const [], lots: lots, dayOf: (d) => d),
            goods: const GoodsLedger(balances: {}, applied: {}),
            trades: const [],
            sales: const [],
            today: DateTime.utc(2026, 12, 1),
            touches: touches,
          );
      expect(
        coins(touches: {HomeTouch.flag}).spent - coins().spent,
        homeTouchCosts[HomeTouch.flag],
      );
    });

    test('can be bought only with the coins for it, and only once', () {
      const me = CityMe(home: (7, 8), touches: {HomeTouch.flag});
      final c = city([home]);
      expect(me.canBuy(c, HomeTouch.flag, coins: 99), isFalse);
      expect(me.canBuy(c, HomeTouch.flowers, coins: 0), isFalse);
      expect(
        me.canBuy(c, HomeTouch.flowers,
            coins: homeTouchCosts[HomeTouch.flowers]!),
        isTrue,
      );
      // Nothing to put them on without a home.
      expect(
        const CityMe().canBuy(c, HomeTouch.flowers, coins: 99),
        isFalse,
      );
    });
  });
}

extension on CityLot {
  CityLot copyWithAt(int x, int y) => CityLot(x: x, y: y, zone: zone, at: at);
}
