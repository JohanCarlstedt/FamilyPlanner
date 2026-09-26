import 'city.dart';

/// Something that makes a child's own home theirs, bought with coins and
/// drawn on and beside it.
enum HomeTouch { flowers, flag, lantern, lights }

/// What each touch costs. Small sums: a child should be able to afford
/// the first one the day they choose their home.
const homeTouchCosts = <HomeTouch, int>{
  HomeTouch.flowers: 1,
  HomeTouch.flag: 1,
  HomeTouch.lantern: 2,
  HomeTouch.lights: 3,
};

/// The child in their own town ("That's me!"): which of the town's people
/// they are, which home is theirs, and what they have bought for it.
///
/// Nothing here counts towards the town's size; it is the child's own
/// corner of it. What was bought belongs to the child, not to a plot: a
/// child who moves home takes it with them.
class CityMe {
  const CityMe({this.look, this.home, this.touches = const {}});

  /// The pictures of people there are (`person_{look}_…`): eight people
  /// and one in a wheelchair.
  static const looks = ['0', '1', '2', '3', '4', '5', '6', '7', 'w'];

  final String? look;
  final (int, int)? home;
  final Set<HomeTouch> touches;

  /// The chosen look, if this version has a picture of it.
  String? get lookIn => looks.contains(look) ? look : null;

  /// Where the child lives in [city]: the chosen plot while a home stands
  /// on it.
  (int, int)? homeIn(City city) => switch (home) {
        (final x, final y) when canBeMyHome(city, x, y) => (x, y),
        _ => null,
      };

  /// Coins spent on touches.
  int get spent => touches.fold(0, (sum, t) => sum + homeTouchCosts[t]!);

  /// Whether [touch] can be bought now: not yet had, a home to put it on,
  /// and [coins] enough.
  bool canBuy(City city, HomeTouch touch, {required int coins}) =>
      !touches.contains(touch) &&
      homeIn(city) != null &&
      coins >= homeTouchCosts[touch]!;
}

/// Whether the child can live at (x, y): a home stands there.
bool canBeMyHome(City city, int x, int y) =>
    city.lotAt(x, y)?.zone == Zone.home;
