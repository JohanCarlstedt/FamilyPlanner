import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  ListedItem need(String name) => ListedItem(name: name);
  ListedItem got(String name) => ListedItem(name: name, bought: true);

  test('what is needed here and missing there gets added', () {
    final push = planShopPush(
      [need('Mjölk'), need('Ägg'), need('Smör')],
      [const ShopRow(id: 'r1', name: 'Ägg', ours: true)],
    );

    expect(push.add.map((i) => i.name), ['Mjölk', 'Smör']);
    expect(push.strike, isEmpty);
  });

  test('a name is matched whatever its case and spacing', () {
    final push = planShopPush(
      [need('  ägg '), need('MJÖLK')],
      [
        const ShopRow(id: 'r1', name: 'Ägg', ours: true),
        const ShopRow(id: 'r2', name: 'mjölk', ours: true),
      ],
    );

    expect(push.isEmpty, isTrue, reason: 'both are already there');
  });

  test('a different word is a different thing', () {
    // Folding case must not turn into guessing. "ägg" and "äggula" are
    // not the same shopping trip.
    final push = planShopPush(
      [need('äggula')],
      [const ShopRow(id: 'r1', name: 'ägg', ours: true)],
    );

    expect(push.add.map((i) => i.name), ['äggula']);
  });

  group('rows we did not create', () {
    // The rule that matters. Someone types milk into ICA's own app while
    // standing at the fridge; a sync that quietly removes it is worse
    // than no sync at all.
    test('are never struck through, even when we have bought that item', () {
      final push = planShopPush(
        [got('Mjölk')],
        [const ShopRow(id: 'theirs', name: 'Mjölk', ours: false)],
      );

      expect(push.isEmpty, isTrue);
    });

    test('and are never added again as a duplicate', () {
      final push = planShopPush(
        [need('Mjölk')],
        [const ShopRow(id: 'theirs', name: 'mjölk', ours: false)],
      );

      expect(push.add, isEmpty);
    });
  });

  group('something bought here', () {
    test('strikes through our own row', () {
      final push = planShopPush(
        [got('Mjölk')],
        [const ShopRow(id: 'r1', name: 'Mjölk', ours: true)],
      );

      expect(push.strike, ['r1']);
      expect(push.add, isEmpty);
    });

    test('is not struck twice', () {
      final push = planShopPush(
        [got('Mjölk')],
        [
          const ShopRow(id: 'r1', name: 'Mjölk', ours: true, struckThrough: true),
        ],
      );

      expect(push.isEmpty, isTrue);
    });

    test('is not re-added just because it is gone from their list', () {
      // Bought and already cleared away in the shop's app. Putting it
      // back would be a ghost appearing in someone's trolley.
      final push = planShopPush([got('Mjölk')], []);

      expect(push.isEmpty, isTrue);
    });
  });

  test('a row struck through by someone else is left alone', () {
    // They ticked it off in the shop; we still need it. Unticking is
    // presumptuous, and the name is on the list either way.
    final push = planShopPush(
      [need('Mjölk')],
      [const ShopRow(id: 'r1', name: 'Mjölk', ours: true, struckThrough: true)],
    );

    expect(push.isEmpty, isTrue);
  });

  test('quantity and unit travel with an added item', () {
    final push = planShopPush(
      [const ListedItem(name: 'Mjölk', quantity: 2, unit: 'l')],
      [],
    );

    expect(push.add.single.quantity, 2);
    expect(push.add.single.unit, 'l');
  });

  test('nothing to do is nothing to send', () {
    expect(planShopPush([], []).isEmpty, isTrue);
    expect(planShopPush([got('Mjölk')], []).count, 0);
  });
}
