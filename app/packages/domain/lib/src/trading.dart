/// Trading houses (spec section 3, "Contributions"): each child's city
/// makes one kind of goods once it has a trading house, siblings swap
/// them one for one, and the special buildings need goods from more than
/// one city — so the only way to build them is to trade.
///
/// Like everything in the city, nothing here is a stored number. What a
/// child has is counted from what they have done, what they built and
/// the trades both children agreed to, so no phone can hand itself goods.
library;

import 'city.dart';
import 'contributions.dart';

/// What a city can make.
enum Good { fish, wood, stone, wool, honey }

/// What goods build: one of each per city.
enum Landmark { harbour, castle, zoo, stadium, bakery }

/// What each special building costs. Every one needs at least two kinds,
/// and a city makes one: none can be built without a sibling.
const landmarkCosts = <Landmark, Map<Good, int>>{
  Landmark.harbour: {Good.fish: 3, Good.wood: 3},
  Landmark.castle: {Good.stone: 4, Good.wool: 2},
  Landmark.zoo: {Good.wood: 2, Good.honey: 2, Good.fish: 2},
  Landmark.stadium: {Good.stone: 3, Good.wool: 3},
  Landmark.bakery: {Good.honey: 3, Good.wood: 2},
};

/// Things done after the trading house was built, for each good it makes.
const doneForAGood = 2;

/// The goods a new trading house makes: the first in this city's own
/// order that no sibling's house makes yet, so children have something
/// to trade. Fixed when the house is built and kept with it: a child
/// joining the family later never changes what anyone already makes.
Good specialtyFor(int seed, {required Set<Good> taken}) {
  final order = [...Good.values]..sort(
      (a, b) => cityNoise(seed, a.index, 0, 51).compareTo(
        cityNoise(seed, b.index, 0, 51),
      ),
    );
  return order.firstWhere((g) => !taken.contains(g), orElse: () => order.first);
}

enum TradeState { offered, accepted, declined, withdrawn }

/// One child offering another [count] of [give] for [count] of [get].
class Trade {
  const Trade({
    required this.id,
    required this.from,
    required this.to,
    required this.give,
    required this.get,
    required this.count,
    required this.state,
    required this.offeredAt,
    this.answeredAt,
    this.answeredBy,
  });

  final String id;

  /// The child offering, and the child asked.
  final String from;
  final String to;

  /// What [from] gives, and what they get back: always [count] of each.
  final Good give;
  final Good get;
  final int count;

  final TradeState state;
  final DateTime offeredAt;
  final DateTime? answeredAt;

  /// The member whose device said yes or no. Only [to]'s yes counts.
  final String? answeredBy;

  /// One for one, two different goods, two different children. The
  /// family chose even trades only: an older sibling cannot talk a
  /// younger one into three of theirs for one.
  bool get fair => count > 0 && give != get && from != to;

  /// Agreed by the child it was offered to.
  bool get agreed =>
      state == TradeState.accepted &&
      answeredBy == to &&
      answeredAt != null &&
      fair;
}

/// A child selling [count] of their [good] to the town at their trading
/// house, for [coinsPerGoodSold] coins each.
class Sale {
  const Sale({
    required this.id,
    required this.member,
    required this.good,
    required this.count,
    required this.at,
  });

  final String id;
  final String member;
  final Good good;
  final int count;
  final DateTime at;
}

/// What the town pays for a good sold at a trading house. Worth more
/// traded for a landmark, which is the point: selling is for when a
/// child has more of something than any plan needs.
const coinsPerGoodSold = 2;

/// Everyone's goods, and which trades and sales went through.
class GoodsLedger {
  const GoodsLedger({
    required this.balances,
    required this.applied,
    this.sold = const {},
  });

  /// By member: every good they have ever had, made, got or spent, with
  /// what is left of it.
  final Map<String, Map<Good, int>> balances;

  /// Trades that moved goods. An agreed trade that one side could no
  /// longer pay for when it was agreed is not in here: two phones
  /// agreeing at once must not leave a child with less than nothing.
  final Set<String> applied;

  /// Sales that went through. One the child could no longer pay for,
  /// sold on two phones at once, is not in here.
  final Set<String> sold;

  int of(String member, Good good) => balances[member]?[good] ?? 0;
}

/// Counts everyone's goods, in the order things happened: what trading
/// houses made, what special buildings and services spent, agreed trades
/// and sales.
///
/// [marketDay] says whether a child's city had market day when a thing
/// was done: then it counts twice towards their goods.
GoodsLedger goodsLedger({
  required List<Contribution> contributions,
  required Map<String, List<CityLot>> lots,
  required List<Trade> trades,
  List<Sale> sales = const [],
  bool Function(String member, DateTime at)? marketDay,
}) {
  final events = <(DateTime, int, void Function())>[];
  final balances = <String, Map<Good, int>>{};
  final applied = <String>{};
  final sold = <String>{};
  void add(String who, Good g, int n) {
    final mine = balances[who] ??= {};
    mine[g] = (mine[g] ?? 0) + n;
  }

  for (final MapEntry(key: who, value: built) in lots.entries) {
    final markets = [
      for (final l in built)
        if (l.zone == Zone.market && l.good != null) l,
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (markets.isNotEmpty) {
      final house = markets.first;
      final after = [
        for (final c in contributions)
          if (c.memberId == who && c.growsWorld && c.at.isAfter(house.at)) c.at,
      ]..sort();
      var counted = 0;
      for (final at in after) {
        final before = counted;
        counted += (marketDay?.call(who, at) ?? false) ? 2 : 1;
        final made = counted ~/ doneForAGood - before ~/ doneForAGood;
        if (made > 0) events.add((at, 0, () => add(who, house.good!, made)));
      }
    }
    for (final l in built) {
      if (l.zone != Zone.service || l.paid.isEmpty) continue;
      events.add((
        l.at,
        1,
        () {
          for (final MapEntry(key: g, value: n) in l.paid.entries) {
            add(who, g, -n);
          }
        },
      ));
    }
    for (final l in built) {
      if (l.zone != Zone.landmark || l.landmark == null) continue;
      // Built is built: a special building stands whatever happened to
      // the goods, and what it cost is taken off.
      events.add((
        l.at,
        1,
        () {
          for (final MapEntry(key: g, value: n)
              in landmarkCosts[l.landmark]!.entries) {
            add(who, g, -n);
          }
        },
      ));
    }
  }

  for (final t in trades) {
    if (!t.agreed) continue;
    events.add((
      t.answeredAt!,
      2,
      () {
        final from = balances[t.from]?[t.give] ?? 0;
        final to = balances[t.to]?[t.get] ?? 0;
        if (from < t.count || to < t.count) return;
        add(t.from, t.give, -t.count);
        add(t.from, t.get, t.count);
        add(t.to, t.get, -t.count);
        add(t.to, t.give, t.count);
        applied.add(t.id);
      },
    ));
  }

  for (final sale in sales) {
    if (sale.count <= 0) continue;
    events.add((
      sale.at,
      3,
      () {
        if ((balances[sale.member]?[sale.good] ?? 0) < sale.count) return;
        add(sale.member, sale.good, -sale.count);
        sold.add(sale.id);
      },
    ));
  }

  events.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  for (final (_, _, apply) in events) {
    apply();
  }
  return GoodsLedger(balances: balances, applied: applied, sold: sold);
}
