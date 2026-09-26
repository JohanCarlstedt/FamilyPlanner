import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Trouble the child can do something about: an animal out of the zoo,
/// and a fire, thief or animal dealt with by tapping it.
void main() {
  DateTime day(DateTime at) => DateTime.utc(at.year, at.month, at.day);
  final built = DateTime.utc(2026, 9, 1, 8);
  final today = DateTime.utc(2027, 3, 1);
  final homes = [
    for (var i = 0; i < 6; i++)
      CityLot(x: 5 + i, y: 9, zone: Zone.home, at: built),
  ];
  final zoo = CityLot(
    x: 7,
    y: 7,
    zone: Zone.landmark,
    landmark: Landmark.zoo,
    at: built,
  );

  /// The first trouble in [who]'s quiet town.
  Trouble firstIn(
    String who,
    List<CityLot> lots, {
    Map<DateTime, DateTime> handled = const {},
  }) =>
      cityLifeOf(
        who,
        contributions: const [],
        lots: lots,
        dayOf: day,
        handled: handled,
      ).troublesUntil(today).first;

  const children = [
    'maja', 'olle', 'tuva', 'noah', 'ebba', 'liam', 'alva', 'sixten', //
    'wilma', 'hugo', 'selma', 'nils',
  ];

  group('an animal out of the zoo', () {
    test('only in a town with a zoo', () {
      for (final who in children) {
        expect(firstIn(who, homes).kind, isNot(TroubleKind.animal));
      }
    });

    test('happens in towns that have one, and is one of the big ones', () {
      final escaped = [
        for (final who in children)
          if (firstIn(who, [...homes, zoo]) case final t
              when t.kind == TroubleKind.animal)
            t,
      ];
      expect(escaped, isNotEmpty);
      for (final t in escaped) {
        expect(t.animal, isNotNull);
        expect(dangerousAnimals, contains(t.animal));
      }
    });

    test('no service keeps it away: the child or the next thing done', () {
      final t = [
        for (final who in children)
          if (firstIn(who, [...homes, zoo]) case final t
              when t.kind == TroubleKind.animal)
            t,
      ].first;
      expect(t.guard, isNull);
      expect(t.over, isFalse);
    });

    test('fires and thieves carry no animal', () {
      final t = firstIn('maja', homes);
      expect(t.animal, isNull);
    });
  });

  group('dealt with by the child', () {
    test('a tap ends it then, and says so', () {
      final first = firstIn('maja', homes);
      final at = first.day.add(const Duration(hours: 15));
      final handled = firstIn('maja', homes, handled: {first.day: at});
      expect(handled.day, first.day);
      expect(handled.endedAt, at);
      expect(handled.handled, isTrue);
      expect(first.handled, isFalse);
    });

    test('a tap after it was already over changes nothing', () {
      final first = firstIn('maja', homes);
      final done = [
        Contribution(
          memberId: 'maja',
          at: first.day.add(const Duration(hours: 9)),
          growsWorld: true,
        ),
      ];
      final life = cityLifeOf(
        'maja',
        contributions: done,
        lots: homes,
        dayOf: day,
        handled: {first.day: first.day.add(const Duration(hours: 20))},
      );
      final t = life.troublesUntil(today).first;
      expect(t.endedAt, first.day.add(const Duration(hours: 9)));
      expect(t.handled, isFalse);
    });

    test('pays a coin more than waiting for it to end', () {
      final first = firstIn('maja', homes);
      Coins coins(Map<DateTime, DateTime> handled) => coinsOf(
            'maja',
            contributions: const [],
            lots: homes,
            life: cityLifeOf(
              'maja',
              contributions: const [],
              lots: homes,
              dayOf: day,
              handled: handled,
            ),
            goods: const GoodsLedger(balances: {}, applied: {}),
            trades: const [],
            sales: const [],
            today: today,
          );
      final waiting = coins(const {});
      final tapped =
          coins({first.day: first.day.add(const Duration(hours: 15))});
      // Over, so the town's thank-you, and one more for being quick.
      expect(tapped.earned - waiting.earned, troubleReward + quickReward);
    });
  });
}
