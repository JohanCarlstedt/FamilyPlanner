import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// The things list: a list's kind, a thing's own fields, a child's sizes.
void main() {
  test('a list is food unless it says it is for things', () {
    final food = ShoppingListPayload.write(name: 'Veckohandling');
    expect(food.kind, ShoppingListKind.food);
    final things = ShoppingListPayload.write(
      name: 'Saker',
      kind: ShoppingListKind.things,
    );
    expect(things.kind, ShoppingListKind.things);
    // Renaming keeps the kind.
    final renamed = ShoppingListPayload.write(
      existing: things.payload,
      name: 'Att köpa',
    );
    expect(renamed.kind, ShoppingListKind.things);
  });

  test('a thing keeps who, size, when, where and who buys', () {
    final thing = ShoppingItemPayload.thing(
      listId: 'saker',
      name: 'Fotbollsskor',
      category: ThingCategory.sport,
      forMember: 'oliver',
      size: '36',
      neededBy: DateTime.utc(2026, 11, 1),
      link: 'https://example.com/skor',
      buyer: 'anna',
    );
    final read = ShoppingItemPayload.read(
      Payload.decode(thing.payload.encode()),
    );
    expect(read.name, 'Fotbollsskor');
    expect(read.thing, ThingCategory.sport);
    expect(read.forMember, 'oliver');
    expect(read.size, '36');
    expect(read.neededBy, DateTime.utc(2026, 11, 1));
    expect(read.link, 'https://example.com/skor');
    expect(read.buyer, 'anna');
    expect(read.state, ItemState.needed);
    // An older app files it with the rest.
    expect(read.category, Aisle.other);
  });

  test('changing a thing keeps what a later version wrote', () {
    final thing = ShoppingItemPayload.thing(
      listId: 'saker',
      name: 'Vantar',
      category: ThingCategory.clothes,
      forMember: 'junie',
    );
    thing.payload.setText('fromLaterVersion', 'kept');
    final changed = thing.withThing(
      name: 'Tumvantar',
      category: ThingCategory.clothes,
      forMember: null,
      size: '6',
      neededBy: null,
      link: null,
      buyer: 'petra',
      note: 'vattentäta',
    );
    expect(changed.name, 'Tumvantar');
    expect(changed.forMember, isNull);
    expect(changed.size, '6');
    expect(changed.buyer, 'petra');
    expect(changed.note, 'vattentäta');
    expect(changed.payload.text('fromLaterVersion'), 'kept');
    expect(changed.copyWith(state: ItemState.ordered).state, ItemState.ordered);
  });

  test('a size card travels on the profile and keeps the diet', () {
    final profile =
        MemberProfile.write(
          displayName: 'Oliver',
          role: MemberRole.child,
        ).withDiet(const [
          DietNote(memberId: 'o', type: DietType.allergy, value: 'nuts'),
        ]);
    final sized = profile.withSizes([
      SizeEntry(
        kind: SizeKind.shoe,
        value: '35',
        measuredAt: DateTime.utc(2026, 8, 12),
      ),
      const SizeEntry(kind: SizeKind.custom, label: 'Hjälm', value: '52–56'),
    ]);
    final read = MemberProfile.read(Payload.decode(sized.payload.encode()));
    expect(
      [for (final s in read.sizes) (s.kind, s.label, s.value)],
      [(SizeKind.shoe, null, '35'), (SizeKind.custom, 'Hjälm', '52–56')],
    );
    expect(read.sizes.first.measuredAt, DateTime.utc(2026, 8, 12));
    expect(read.dietNotes('o'), hasLength(1));
  });
}
