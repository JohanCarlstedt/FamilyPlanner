import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Services, coins, happenings and requests (spec section 3,
/// "Contributions"): the town needs things to grow, earns coins to pay
/// for them, and has a life of its own.
void main() {
  // A Monday after the town came alive.
  final start = DateTime.utc(2026, 10, 5, 8);
  DateTime day(DateTime at) => DateTime.utc(at.year, at.month, at.day);

  List<Contribution> chores(int n, {DateTime? from, String who = 'maja'}) => [
        for (var i = 0; i < n; i++)
          Contribution(
            memberId: who,
            at: (from ?? start).add(Duration(days: 1, minutes: i)),
            growsWorld: true,
          ),
      ];

  City city(
    List<Contribution> done,
    List<CityLot> lots, {
    DateTime? today,
  }) =>
      cityOf(
        'maja',
        contributions: done,
        lots: lots,
        jarEverFull: false,
        today: today ?? DateTime.utc(2026, 12, 1),
      );

  CityLot lot(
    int x,
    int y,
    Zone zone, {
    DateTime? at,
    Service? service,
    Map<Good, int> paid = const {},
    Good? good,
  }) =>
      CityLot(
        x: x,
        y: y,
        zone: zone,
        at: at ?? start,
        service: service,
        paid: paid,
        good: good,
      );

  group('services', () {
    test('apartments wait for power and water', () {
      final home = lot(8, 9, Zone.home);
      final done = chores(City.homeSizes[2]);
      final bare = city(done, [home]);
      expect(bare.sizeOf(8, 9), 1, reason: 'a house, earned apartments');
      expect(bare.missingAt(8, 9), {Service.power, Service.water});

      final served = city(done, [
        home,
        lot(9, 10, Zone.service, service: Service.power),
        lot(10, 10, Zone.service, service: Service.water),
      ]);
      expect(served.sizeOf(8, 9), 2);
      expect(served.missingAt(8, 9), isEmpty);
    });

    test('reach only so far', () {
      final done = chores(City.homeSizes[2]);
      final far = city(done, [
        lot(8, 9, Zone.home),
        lot(8 + City.serviceReach + 1, 9, Zone.service, service: Service.power),
        lot(8, 9 - City.serviceReach, Zone.service, service: Service.water),
      ]);
      expect(far.covered(8, 9, Service.water), isTrue);
      expect(far.covered(8, 9, Service.power), isFalse);
      expect(far.sizeOf(8, 9), 1);
    });

    test('count once finished, like any neighbour', () {
      final done = chores(City.homeSizes[2]);
      final today = DateTime.utc(2026, 11, 2);
      final c = city(done, today: today, [
        lot(8, 9, Zone.home),
        lot(9, 10, Zone.service, service: Service.power, at: today),
        lot(10, 10, Zone.service, service: Service.water, at: today),
      ]);
      expect(c.sizeOf(8, 9), 1, reason: 'still being built');
    });

    test('a tower needs a fire station and a clinic too', () {
      final done = chores(City.homeSizes[3]);
      final lots = [
        lot(8, 9, Zone.home),
        lot(8, 10, Zone.park),
        lot(9, 10, Zone.service, service: Service.power),
        lot(10, 10, Zone.service, service: Service.water),
      ];
      expect(city(done, lots).sizeOf(8, 9), 2);
      expect(city(done, lots).missingAt(8, 9), {Service.fire, Service.clinic});
      final full = city(done, [
        ...lots,
        lot(10, 9, Zone.service, service: Service.fire),
        lot(10, 8, Zone.service, service: Service.clinic),
      ]);
      expect(full.sizeOf(8, 9), 3);
    });

    test('nothing that grew before the town had needs is smaller now', () {
      final old = DateTime.utc(2026, 8, 3, 8);
      final done = [
        for (var i = 0; i < City.homeSizes[2]; i++)
          Contribution(
            memberId: 'maja',
            at: old.add(Duration(hours: i + 1)),
            growsWorld: true,
          ),
      ];
      final c = city(done, [lot(8, 9, Zone.home, at: old)]);
      expect(c.sizeOf(8, 9), 2, reason: 'apartments before any water tower');
    });

    test('take coins, not seeds', () {
      final c = city(chores(3), [
        lot(8, 9, Zone.home),
        lot(9, 10, Zone.service, service: Service.water),
      ]);
      expect(c.waiting, 2);
    });

    test('a bus stop stands by a street', () {
      final c = city(chores(3), const []);
      expect(c.canBuildService(8, 8, Service.bus), isTrue,
          reason: 'beside the main street');
      expect(c.canBuildService(9, 9, Service.bus), isFalse);
      expect(c.canBuildService(9, 9, Service.water), isTrue);
    });
  });

  group('coins', () {
    CityLife life(List<Contribution> done, List<CityLot> lots) =>
        cityLifeOf('maja', contributions: done, lots: lots, dayOf: day);

    Coins coins(
      List<Contribution> done,
      List<CityLot> lots, {
      List<Trade> trades = const [],
      List<Sale> sales = const [],
      GoodsLedger? goods,
    }) =>
        coinsOf(
          'maja',
          contributions: done,
          lots: lots,
          life: _Quiet(life(done, lots)),
          goods: goods ??
              goodsLedger(
                contributions: done,
                lots: {'maja': lots},
                trades: trades,
                sales: sales,
              ),
          trades: trades,
          sales: sales,
          today: DateTime.utc(2026, 12, 1),
        );

    test('one for each thing done', () {
      expect(coins(chores(5), const []).earned, 5);
    });

    test('more once the town trades: shops and a trading house', () {
      final lots = [
        lot(8, 9, Zone.shop),
        lot(9, 8, Zone.shop),
        lot(10, 10, Zone.market, good: Good.fish),
      ];
      expect(coins(chores(4), lots).earned, 4 * 3);
    });

    test('services are paid for', () {
      final c = coins(chores(10), [
        lot(9, 10, Zone.service, service: Service.water),
      ]);
      expect(c.spent, serviceCosts[Service.water]);
      expect(c.balance, 10 - serviceCosts[Service.water]!);
    });

    test('a trade pays both children a coin a good', () {
      final done = [...chores(8), ...chores(8, who: 'olle')];
      final lots = {
        'maja': [lot(10, 10, Zone.market, good: Good.fish)],
        'olle': [lot(10, 10, Zone.market, good: Good.wood)],
      };
      final trade = Trade(
        id: 't',
        from: 'maja',
        to: 'olle',
        give: Good.fish,
        get: Good.wood,
        count: 2,
        state: TradeState.accepted,
        offeredAt: start.add(const Duration(days: 3)),
        answeredAt: start.add(const Duration(days: 3)),
        answeredBy: 'olle',
      );
      final goods =
          goodsLedger(contributions: done, lots: lots, trades: [trade]);
      expect(goods.applied, {'t'});
      final c = coins(done, lots['maja']!, trades: [trade], goods: goods);
      expect(c.earned, 8 * 2 + 2);
    });

    test('selling goods pays two coins each, and only goods there are', () {
      final done = chores(8);
      final lots = [lot(10, 10, Zone.market, good: Good.honey)];
      final later = start.add(const Duration(days: 5));
      final sales = [
        Sale(id: 'a', member: 'maja', good: Good.honey, count: 3, at: later),
        Sale(id: 'b', member: 'maja', good: Good.honey, count: 5, at: later),
      ];
      final goods = goodsLedger(
        contributions: done,
        lots: {'maja': lots},
        trades: const [],
        sales: sales,
      );
      expect(goods.sold, {'a'}, reason: 'four made, three sold');
      expect(goods.of('maja', Good.honey), 1);
      expect(coins(done, lots, sales: sales, goods: goods).earned,
          8 * 2 + 3 * coinsPerGoodSold);
    });
  });

  group('goods', () {
    test('services spend the goods chosen for them', () {
      final done = chores(8);
      final goods = goodsLedger(
        contributions: done,
        lots: {
          'maja': [
            lot(10, 10, Zone.market, good: Good.stone),
            lot(9, 10, Zone.service,
                service: Service.fire,
                paid: {Good.stone: 2},
                at: start.add(const Duration(days: 4))),
          ],
        },
        trades: const [],
      );
      expect(goods.of('maja', Good.stone), 2);
    });

    test('market day makes twice as much', () {
      final done = chores(4);
      final lots = {
        'maja': [lot(10, 10, Zone.market, good: Good.wool)],
      };
      final plain =
          goodsLedger(contributions: done, lots: lots, trades: const []);
      final market = goodsLedger(
        contributions: done,
        lots: lots,
        trades: const [],
        marketDay: (who, at) => true,
      );
      expect(plain.of('maja', Good.wool), 2);
      expect(market.of('maja', Good.wool), 4);
    });
  });

  group('happenings', () {
    CityLife life(List<CityLot> lots, {List<Contribution>? done}) =>
        cityLifeOf('maja',
            contributions: done ?? chores(30), lots: lots, dayOf: day);

    final days = [
      for (var i = 0; i < 400; i++) DateTime.utc(2026, 10, 1 + i),
    ];

    test('are the same every time, and on some days only', () {
      final a = life([lot(8, 9, Zone.park)]);
      final b = life([lot(8, 9, Zone.park)]);
      final on = [for (final d in days) a.on(d)];
      expect([for (final d in days) b.on(d)], on);
      final some = on.whereType<Happening>().length / days.length;
      expect(some, inInclusiveRange(0.2, 0.4));
    });

    test('need something to happen at', () {
      final plain = life(const [], done: const []);
      expect([for (final d in days) plain.on(d)].whereType<Happening>(),
          everyElement(Happening.whale),
          reason: 'no park, no market, no landmark: only the lake');
      final town = life([lot(8, 9, Zone.park)]);
      expect([for (final d in days) town.on(d)],
          isNot(contains(Happening.marketDay)));
    });

    test('never before the town came alive', () {
      final l = life([lot(8, 9, Zone.park)]);
      for (var i = 1; i < 120; i++) {
        expect(l.on(DateTime.utc(2026, 5, i)), isNull);
      }
    });
  });

  group('requests', () {
    test('one a week, granted by building what was asked that week', () {
      final home = lot(8, 9, Zone.home);
      final monday = DateTime.utc(2026, 10, 12);
      final life = cityLifeOf('maja',
          contributions: chores(5), lots: [home], dayOf: day);
      final request = life.requestFor(monday)!;
      expect(request.week, monday);
      expect(residents, contains(request.who));

      final answer = switch (request.kind) {
        RequestKind.parkNear =>
          lot(request.x! + 1, request.y!, Zone.park, at: monday),
        RequestKind.shopNear =>
          lot(request.x! + 1, request.y!, Zone.shop, at: monday),
        RequestKind.home => lot(6, 9, Zone.home, at: monday),
        RequestKind.service =>
          lot(10, 10, Zone.service, service: request.service, at: monday),
      };
      final granted = cityLifeOf('maja',
          contributions: chores(5), lots: [home, answer], dayOf: day);
      expect(granted.grantOf(granted.requestFor(monday)!), isNotNull);

      final late = CityLot(
        x: answer.x,
        y: answer.y,
        zone: answer.zone,
        service: answer.service,
        at: monday.add(const Duration(days: 8)),
      );
      final tooLate = cityLifeOf('maja',
          contributions: chores(5), lots: [home, late], dayOf: day);
      expect(tooLate.grantOf(tooLate.requestFor(monday)!), isNull);
    });

    test('a park far from the home asking does not count', () {
      final r = CityRequest(
        kind: RequestKind.parkNear,
        week: _monday,
        who: 'Lisa',
        x: 4,
        y: 4,
      );
      expect(r.grantedBy(lot(4 + requestReach, 4, Zone.park)), isTrue);
      expect(r.grantedBy(lot(5 + requestReach, 4, Zone.park)), isFalse);
      expect(r.grantedBy(lot(5, 4, Zone.home)), isFalse);
    });
  });

  group('next up', () {
    test('what waits for a service comes first', () {
      final done = chores(City.homeSizes[2]);
      final c = city(done, [lot(8, 9, Zone.home), lot(6, 9, Zone.park)]);
      final ups = nextUps(
        c,
        progress: worldOf('maja', done),
        homeworkSeen: 0,
      );
      expect(ups.first, isA<WaitsFor>());
      expect((ups.first as WaitsFor).missing, contains(Service.power));
      expect(ups.whereType<NextLevel>(), hasLength(1));
      expect(ups.whereType<NextLearning>().single.building, Civic.school);
    });
  });

  group('population', () {
    test('a home on a bare street is half full', () {
      final c = city(const [], [lot(8, 9, Zone.home)]);
      expect(residentsAt(c, 8, 9), homeRoom[0] ~/ 2);
    });

    test('grows with how the child builds round it', () {
      final done = chores(City.homeSizes[1]);
      final bare = city(done, [lot(8, 9, Zone.home)]);
      final lived = city(done, [
        lot(8, 9, Zone.home),
        lot(6, 9, Zone.park),
        lot(9, 10, Zone.shop),
        lot(8, 8, Zone.service, service: Service.bus),
        lot(10, 9, Zone.service, service: Service.clinic),
      ]);
      expect(occupancyAt(lived, 8, 9), closeTo(1, 1e-9));
      expect(populationOf(lived), greaterThan(populationOf(bare)));
      expect(residentsAt(lived, 8, 9), homeRoom[lived.sizeOf(8, 9)]);
    });

    test('pays at each milestone', () {
      final c = coinsOf(
        'maja',
        contributions: const [],
        lots: const [],
        life: _Quiet(cityLifeOf('maja',
            contributions: const [], lots: const [], dayOf: day)),
        goods: const GoodsLedger(balances: {}, applied: {}),
        trades: const [],
        sales: const [],
        today: DateTime.utc(2026, 12, 1),
        population: 60,
      );
      expect(c.earned, 2 * milestoneCoins);
    });
  });

  group('the book', () {
    test('holds every size a building has reached and what was seen', () {
      final done = chores(City.homeSizes[1]);
      final c = city(done, [lot(8, 9, Zone.home)]);
      final book = collected(c, {Happening.whale});
      expect(book,
          containsAll(['home:0', 'home:1', 'civic:hall', 'happening:whale']));
      expect(book, isNot(contains('home:2')));
      expect(allCollectibles, containsAll(book));
    });
  });
}

final _monday = DateTime.utc(2026, 10, 12);

/// A city where nothing happens, so the sums are only what the test adds.
class _Quiet extends CityLife {
  _Quiet(CityLife life)
      : super(
          seed: life.seed,
          lake: life.lake,
          lots: const [],
          mine: const [],
          dayOf: life.dayOf,
        );

  @override
  Happening? on(DateTime day) => null;

  @override
  List<(CityRequest, CityLot?)> requestsUntil(DateTime today) => const [];
}
