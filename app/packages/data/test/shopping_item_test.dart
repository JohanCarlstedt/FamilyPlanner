import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Changing a line on the shopping list.
void main() {
  ShoppingItemPayload item() => ShoppingItemPayload.write(
    listId: 'list',
    name: 'mjölk',
    key: 'milk',
    quantity: 1,
    unit: Unit.l,
    category: Aisle.dairy,
    state: ItemState.bought,
    checkedBy: 'anna',
    sources: const [
      ItemSource(
        type: 'recipe',
        id: 'r1',
        quantity: 1,
        unit: Unit.l,
        label: 'Pannkakor',
      ),
    ],
  );

  ShoppingLine typed(String text) => ShoppingLine.fromIngredient(
    IngredientLine.parse(text),
    IngredientCatalogue.swedish,
  );

  test('a new amount becomes the line, and the line becomes yours', () {
    final before = item();
    before.payload.setText('fromLaterVersion', 'kept');
    final after = before.edited(typed('2 l mjölk'));
    expect(after.describe(), before.edited(typed('2 l mjölk')).describe());
    expect((after.quantity, after.unit), (2.0, Unit.l));
    // Taking the recipe off the menu must not subtract from an amount
    // someone set by hand.
    expect([for (final s in after.sources) s.type], ['manual']);
    expect(after.state, ItemState.bought, reason: 'ticked stays ticked');
    expect(after.listId, 'list');
    expect(after.payload.text('fromLaterVersion'), 'kept');
  });

  test('another aisle or a note keeps where it came from', () {
    final after = item().edited(
      typed('1 l mjölk'),
      category: Aisle.frozen,
      note: 'laktosfri',
    );
    expect(after.category, Aisle.frozen);
    expect(after.note, 'laktosfri');
    expect([for (final s in after.sources) s.label], ['Pannkakor']);
  });

  test('something else entirely is matched to the catalogue afresh', () {
    final after = item().edited(typed('smör'));
    expect(after.name.toLowerCase(), contains('smör'));
    expect(after.quantity, isNull);
    expect(after.category, isNot(Aisle.other));
  });
}
