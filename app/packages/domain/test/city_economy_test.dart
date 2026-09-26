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

  /// [l] taken up [n] sizes by the child, along [path].
  CityLot up(CityLot l, int n, [UpgradePath path = UpgradePath.moreFlats]) {
    var out = l;
    for (var i = 0; i < n; i++) {
      out = out.upgraded(path, start.add(Duration(hours: 1, minutes: i)));
    }
    return out;
  }

  group('services', () {
    test('apartments wait for power and water', () {
      final home = up(lot(8, 9, Zone.home), 1);
      final done = chores(City.homeSizes[2]);
      final bare = city(done, [home]);
      expect(bare.sizeOf(8, 9), 1, reason: 'a house, earned apartments');
      expect(bare.missingAt(8, 9), {Service.power, Service.water});
      expect(bare.canUpgrade(8, 9), isFalse);

      final services = [
        lot(9, 10, Zone.service, service: Service.power),
        lot(10, 10, Zone.service, service: Service.water),
      ];
      final served = city(done, [home, ...services]);
      expect(served.canUpgrade(8, 9), isTrue);
      expect(served.missingAt(8, 9), isEmpty);
      expect(city(done, [up(home, 1), ...services]).sizeOf(8, 9), 2);
    });

    test('reach only so far', () {
      final done = chores(City.homeSizes[2]);
      final far = city(done, [
        up(lot(8, 9, Zone.home), 1),
        lot(8 + City.serviceReach + 1, 9, Zone.service, service: Service.power),
        lot(8, 9 - City.serviceReach, Zone.service, service: Service.water),
      ]);
      expect(far.covered(8, 9, Service.water), isTrue);
      expect(far.covered(8, 9, Service.power), isFalse);
      expect(far.canUpgrade(8, 9), isFalse);
    });

    test('count once finished, like any neighbour', () {
      final done = chores(City.homeSizes[2]);
      final today = DateTime.utc(2026, 11, 2);
      final c = city(done, today: today, [
        up(lot(8, 9, Zone.home), 1),
        lot(9, 10, Zone.service, service: Service.power, at: today),
        lot(10, 10, Zone.service, service: Service.water, at: today),
      ]);
      expect(c.canUpgrade(8, 9), isFalse, reason: 'still being built');
    });

    test('a tower needs a fire station and a clinic too', () {
      final done = chores(City.homeSizes[3]);
      final lots = [
        up(lot(8, 9, Zone.home), 2),
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
      expect(full.canUpgrade(8, 9), isTrue);
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
    test('what waits for a service comes before the rest', () {
      final done = chores(City.homeSizes[2]);
      final c = city(done, [up(lot(8, 9, Zone.home), 1), lot(6, 9, Zone.park)]);
      final ups = nextUps(
        c,
        progress: worldOf('maja', done),
        homeworkSeen: 0,
      );
      // The park has grown ready to upgrade: a tap, so before everything.
      expect(ups.first, isA<ReadyToUpgrade>());
      final waits = ups.whereType<WaitsFor>().first;
      expect(waits.missing, contains(Service.power));
      expect(ups.indexOf(waits),
          lessThan(ups.indexOf(ups.whereType<NextLevel>().single)));
      expect(ups.whereType<NextLevel>(), hasLength(1));
      expect(ups.whereType<NextLearning>().single.building, Civic.school);
    });
  });

  group('upgrades', () {
    test('a building grows only when the child chooses how', () {
      final done = chores(City.homeSizes[1]);
      final c = city(done, [lot(8, 9, Zone.home)]);
      expect(c.sizeOf(8, 9), 0);
      expect(c.canUpgrade(8, 9), isTrue);
      final chosen = city(done, [up(lot(8, 9, Zone.home), 1)]);
      expect(chosen.sizeOf(8, 9), 1);
      expect(chosen.canUpgrade(8, 9), isFalse, reason: 'nothing more earned');
      expect(nextUps(c, progress: worldOf('maja', done), homeworkSeen: 0).first,
          isA<ReadyToUpgrade>());
    });

    test('what grew by itself before stays, and needs no choosing', () {
      final old = DateTime.utc(2026, 8, 3, 8);
      final done = [
        for (var i = 0; i < City.homeSizes[1]; i++)
          Contribution(
            memberId: 'maja',
            at: old.add(Duration(hours: i + 1)),
            growsWorld: true,
          ),
      ];
      final c = city(done, [lot(8, 9, Zone.home, at: old)]);
      expect(c.sizeOf(8, 9), 1);
      expect(c.canUpgrade(8, 9), isFalse);
    });

    test('a garden works like a park for the neighbours', () {
      final garden = city(const [], [
        up(lot(8, 9, Zone.home), 1, UpgradePath.garden),
        lot(9, 9, Zone.home),
      ]);
      final flats = city(const [], [
        up(lot(8, 9, Zone.home), 1),
        lot(9, 9, Zone.home),
      ]);
      expect(garden.canUpgrade(9, 9), isTrue, reason: 'as if beside a park');
      expect(flats.canUpgrade(9, 9), isFalse);
    });

    test('woodland reaches homes two plots away', () {
      final woods = city(const [], [
        lot(8, 9, Zone.home),
        up(lot(10, 9, Zone.park), 1, UpgradePath.woodland),
      ]);
      final playground = city(const [], [
        lot(8, 9, Zone.home),
        up(lot(10, 9, Zone.park), 1, UpgradePath.playground),
      ]);
      expect(woods.canUpgrade(8, 9), isTrue);
      expect(playground.canUpgrade(8, 9), isFalse);
    });

    test('more flats hold more people, a shop downstairs earns', () {
      final done = chores(City.homeSizes[1]);
      final flats = city(done, [up(lot(8, 9, Zone.home), 1)]);
      final house =
          city(done, [up(lot(8, 9, Zone.home), 1, UpgradePath.garden)]);
      expect(residentsAt(flats, 8, 9), greaterThan(homeRoom[1] ~/ 2));
      final shop = up(lot(8, 9, Zone.home), 1, UpgradePath.shopDownstairs);
      final lots = [
        shop,
        up(lot(9, 9, Zone.home), 1, UpgradePath.shopDownstairs)
      ];
      final later = start.add(const Duration(days: 3));
      expect(
        coinsFor(later, lots: lots, dayOf: day),
        2,
        reason: 'two homes with shops earn like two shops',
      );
      expect(residentsAt(house, 8, 9), greaterThanOrEqualTo(homeRoom[1] ~/ 2));
    });

    test('never past the biggest size', () {
      final done = chores(City.homeSizes[3] + 5);
      final top = city(done, [
        up(lot(8, 9, Zone.home), 3),
        lot(8, 10, Zone.park),
      ]);
      expect(top.sizeOf(8, 9), City.maxSize(Zone.home));
      expect(top.canUpgrade(8, 9), isFalse);
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

  group('the family project', () {
    test('takes goods the children have, and finishes in order', () {
      final done = [...chores(8), ...chores(8, who: 'olle')];
      final later = start.add(const Duration(days: 5));
      final goods = goodsLedger(
        contributions: done,
        lots: {
          'maja': [lot(10, 10, Zone.market, good: Good.fish)],
          'olle': [lot(10, 10, Zone.market, good: Good.wood)],
        },
        trades: const [],
        gifts: [
          Gift(member: 'maja', good: Good.fish, count: 4, at: later),
          Gift(member: 'olle', good: Good.wood, count: 4, at: later),
          Gift(
              member: 'olle',
              good: Good.wood,
              count: 9,
              at: later.add(const Duration(minutes: 1))),
        ],
      );
      expect(goods.givenInAll, 8, reason: 'olle had only four to give');
      final family = familyProjects(goods.givenInAll);
      expect(family.done, [FamilyProject.statue]);
      expect(family.building, FamilyProject.clockTower);
      expect(family.given, 0);
    });

    test('stands on a free plot in every city, and keeps it', () {
      final c = cityOf(
        'maja',
        contributions: chores(5),
        lots: [lot(8, 9, Zone.home)],
        jarEverFull: false,
        today: DateTime.utc(2026, 12, 1),
        projects: [FamilyProject.statue],
      );
      final (x, y) = c.projectPlots[FamilyProject.statue]!;
      expect(c.lotAt(x, y), isNull);
      expect(c.isRoad(x, y), isFalse);
      expect(c.canBuild(x, y, Zone.home), isFalse);
      expect(collected(c, const {}), contains('project:statue'));
    });
  });

  group('a parent\'s present', () {
    test('adds coins or goods, up to a limit, and helps the project', () {
      final at = start.add(const Duration(days: 2));
      final presents = [
        CityGift(from: 'mamma', to: 'maja', at: at, coins: 50),
        CityGift(
            from: 'mamma',
            to: 'maja',
            at: at.add(const Duration(minutes: 1)),
            good: Good.honey,
            count: 2),
        CityGift(
            from: 'pappa',
            to: CityGift.family,
            at: at,
            good: Good.wood,
            count: 3),
      ];
      final goods = goodsLedger(
        contributions: const [],
        lots: const {},
        trades: const [],
        presents: presents,
      );
      expect(goods.of('maja', Good.honey), 2);
      expect(goods.givenInAll, 3);
      final c = coinsOf(
        'maja',
        contributions: const [],
        lots: const [],
        life: _Quiet(cityLifeOf('maja',
            contributions: const [], lots: const [], dayOf: day)),
        goods: goods,
        trades: const [],
        sales: const [],
        today: DateTime.utc(2026, 12, 1),
        presents: presents,
      );
      expect(c.earned, maxGiftCoins);
    });
  });

  group('trouble', () {
    // A town with plenty of homes, and nothing done after they were built.
    final built = DateTime.utc(2026, 9, 1, 8);
    final homes = [
      for (var i = 0; i < 6; i++) lot(5 + i, 9, Zone.home, at: built),
    ];
    final days = DateTime.utc(2026, 9, 28);
    final today = DateTime.utc(2027, 3, 1);

    CityLife quietTown(List<CityLot> lots,
            {List<Contribution> done = const []}) =>
        cityLifeOf('maja', contributions: done, lots: lots, dayOf: day);

    test('never before it could, and one at a time', () {
      final all = quietTown(homes).troublesUntil(today);
      expect(all, isNotEmpty);
      expect(all.first.day.isBefore(days), isFalse);
      expect(all, hasLength(1),
          reason: 'nothing done since, so the first is still going on');
      expect(all.single.over, isFalse);
      expect(
          homes.map((h) => (h.x, h.y)), contains((all.single.x, all.single.y)));
    });

    test('the next thing done ends it, and then another can come', () {
      final first = quietTown(homes).troublesUntil(today).single;
      final done = [
        for (var i = 0; i < 40; i++)
          Contribution(
            memberId: 'maja',
            at: first.day.add(Duration(days: i * 3, hours: 12)),
            growsWorld: true,
          ),
      ];
      final all = quietTown(homes, done: done).troublesUntil(today);
      expect(all.first.endedAt, first.day.add(const Duration(hours: 12)));
      expect(all.length, greaterThan(1));
      expect(all.where((t) => !t.over).length, lessThanOrEqualTo(1));
    });

    test('a fire station and a police station keep it away', () {
      final guards = [
        lot(7, 9, Zone.service, service: Service.fire, at: built),
        lot(8, 9, Zone.service, service: Service.police, at: built),
      ];
      final safe = quietTown([
        for (final h in homes)
          if (h.x != 7 && h.x != 8) h,
        ...guards,
      ]);
      expect(safe.troublesUntil(today), isEmpty,
          reason: 'every home is within reach of both');
    });

    test('a thief hides coins until caught, then they come back', () {
      final kinds = <TroubleKind>{};
      for (final who in ['maja', 'olle', 'tuva', 'noah', 'ebba', 'liam']) {
        final mine = [
          for (final h in homes)
            CityLot(x: h.x, y: h.y, zone: Zone.home, at: h.at),
        ];
        final done = [
          for (var i = 0; i < 10; i++)
            Contribution(
              memberId: who,
              at: built.add(Duration(hours: i + 1)),
              growsWorld: true,
            ),
        ];
        final life =
            cityLifeOf(who, contributions: done, lots: mine, dayOf: day);
        Coins coinsOn(DateTime when) => coinsOf(
              who,
              contributions: done,
              lots: mine,
              life: life,
              goods: const GoodsLedger(balances: {}, applied: {}),
              trades: const [],
              sales: const [],
              today: when,
            );
        final now = life.troubleNow(today)!;
        kinds.add(now.kind);
        final during = coinsOn(today);
        if (now.kind == TroubleKind.thief) {
          expect(during.hidden, thiefHides);
          expect(during.balance, 10 - thiefHides);
        } else {
          expect(during.hidden, 0);
        }
        // Caught (or put out) by the next thing done: all back, and one
        // coin more.
        final caught = coinsOf(
          who,
          contributions: [
            ...done,
            Contribution(
              memberId: who,
              at: now.day.add(const Duration(hours: 9)),
              growsWorld: true,
            ),
          ],
          lots: mine,
          life: cityLifeOf(who,
              contributions: [
                ...done,
                Contribution(
                  memberId: who,
                  at: now.day.add(const Duration(hours: 9)),
                  growsWorld: true,
                ),
              ],
              lots: mine,
              dayOf: day),
          goods: const GoodsLedger(balances: {}, applied: {}),
          trades: const [],
          sales: const [],
          today: now.day,
        );
        expect(caught.hidden, 0);
        expect(caught.earned, greaterThanOrEqualTo(11 + troubleReward));
      }
      expect(kinds, TroubleKind.values.toSet(),
          reason: 'six towns see both kinds');
    });
  });

  group('the book', () {
    test('holds every size a building has reached and what was seen', () {
      final done = chores(City.homeSizes[1]);
      final c = city(done, [up(lot(8, 9, Zone.home), 1, UpgradePath.garden)]);
      final book = collected(c, {Happening.whale});
      expect(
        book,
        containsAll([
          'home:0',
          'home:1',
          'civic:hall',
          'happening:whale',
          'path:garden',
        ]),
      );
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
