import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Trading houses: each child's city makes one kind of goods, siblings
/// swap them one for one, and the special buildings need goods a city
/// does not make itself.
void main() {
  final aug = DateTime.utc(2026, 8, 1, 8);
  DateTime day(int n) => aug.add(Duration(days: n));

  List<Contribution> done(String who, int n, {int from = 1}) => [
        for (var i = 0; i < n; i++)
          Contribution(
            memberId: who,
            at: day(from).add(Duration(minutes: i)),
            growsWorld: true,
          ),
      ];

  CityLot market(Good good, {int on = 0}) => CityLot(
        x: 9,
        y: 9,
        zone: Zone.market,
        at: day(on),
        good: good,
      );

  Trade trade(
    String id, {
    String from = 'maja',
    String to = 'tuva',
    Good give = Good.fish,
    Good get = Good.wood,
    int count = 2,
    TradeState state = TradeState.accepted,
    String? answeredBy,
    int on = 5,
  }) =>
      Trade(
        id: id,
        from: from,
        to: to,
        give: give,
        get: get,
        count: count,
        state: state,
        offeredAt: day(on),
        answeredAt: state == TradeState.offered ? null : day(on),
        answeredBy: state == TradeState.offered ? null : (answeredBy ?? to),
      );

  Map<String, Map<Good, int>> ledger({
    List<Contribution> contributions = const [],
    Map<String, List<CityLot>> lots = const {},
    List<Trade> trades = const [],
  }) =>
      goodsLedger(
        contributions: contributions,
        lots: lots,
        trades: trades,
      ).balances;

  group('what a city makes', () {
    test('nothing until it has a trading house', () {
      expect(ledger(contributions: done('maja', 10))['maja'] ?? {}, isEmpty);
    });

    test('one of its own goods for every two things done after', () {
      final b = ledger(
        contributions: [...done('maja', 3, from: -1), ...done('maja', 7)],
        lots: {
          'maja': [market(Good.fish, on: 0)],
        },
      );
      // The three done before the house was built made nothing.
      expect(b['maja'], {Good.fish: 3});
    });

    test('siblings get goods nobody else in the family makes yet', () {
      const goods = Good.values;
      final taken = <Good>{};
      for (final seed in [11, 12, 13, 14, 15]) {
        final g = specialtyFor(seed, taken: taken);
        expect(taken, isNot(contains(g)));
        taken.add(g);
      }
      expect(taken, goods.toSet());
      // Once every kind is taken, a sixth child still makes something.
      expect(Good.values, contains(specialtyFor(16, taken: taken)));
    });
  });

  group('trades', () {
    final both = {
      'maja': [market(Good.fish)],
      'tuva': [market(Good.wood)],
    };
    final busy = [...done('maja', 10), ...done('tuva', 10)];

    test('an accepted trade moves the same number both ways', () {
      final b = ledger(
        contributions: busy,
        lots: both,
        trades: [trade('t1')],
      );
      expect(b['maja'], {Good.fish: 3, Good.wood: 2});
      expect(b['tuva'], {Good.wood: 3, Good.fish: 2});
    });

    test('only one for one: an uneven trade is not a trade', () {
      expect(
        Trade(
          id: 'x',
          from: 'maja',
          to: 'tuva',
          give: Good.fish,
          get: Good.wood,
          count: 0,
          state: TradeState.accepted,
          offeredAt: day(5),
        ).fair,
        isFalse,
      );
      expect(trade('same', get: Good.fish).fair, isFalse);
      expect(trade('self', to: 'maja').fair, isFalse);
    });

    test('offered, declined or taken back: nothing moves', () {
      for (final state in [
        TradeState.offered,
        TradeState.declined,
        TradeState.withdrawn,
      ]) {
        final b = ledger(
          contributions: busy,
          lots: both,
          trades: [trade('t', state: state)],
        );
        expect(b['maja'], {Good.fish: 5});
      }
    });

    test('only the child asked can say yes to it', () {
      final b = ledger(
        contributions: busy,
        lots: both,
        trades: [trade('t', answeredBy: 'maja')],
      );
      expect(b['maja'], {Good.fish: 5});
    });

    test('nobody gives what they do not have', () {
      final result = goodsLedger(
        contributions: busy,
        lots: both,
        trades: [trade('big', count: 6)],
      );
      expect(result.balances['maja'], {Good.fish: 5});
      expect(result.applied, isEmpty);
    });
  });

  group('special buildings', () {
    test('each needs goods from more than one city', () {
      for (final costs in landmarkCosts.values) {
        expect(costs.length, greaterThanOrEqualTo(2));
      }
    });

    test('building one spends its goods', () {
      final b = ledger(
        contributions: [...done('maja', 20), ...done('tuva', 20)],
        lots: {
          'maja': [
            market(Good.fish),
            CityLot(
              x: 5,
              y: 9,
              zone: Zone.landmark,
              at: day(9),
              landmark: Landmark.harbour,
            ),
          ],
          'tuva': [market(Good.wood)],
        },
        trades: [trade('t', count: 3)],
      );
      expect(b['maja'], {Good.fish: 4, Good.wood: 0});
    });
  });
}
