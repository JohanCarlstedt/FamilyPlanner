import 'package:domain/domain.dart';
import 'package:family/src/features/members/sizes_screen.dart';
import 'package:family/src/features/shopping/shopping_providers.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// A things list: shoes, clothes and kit, grouped by kind or by person,
/// each with who it is for, the size and when it is needed.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  final items = [
    (
      't1',
      ShoppingItemPayload.thing(
        listId: 'things',
        name: 'Fotbollsskor',
        category: ThingCategory.sport,
        forMember: 'leo',
        size: '36',
        neededBy: DateTime.utc(2026, 9, 19),
        buyer: 'anna',
      ),
    ),
    (
      't2',
      ShoppingItemPayload.thing(
        listId: 'things',
        name: 'Regnbyxor',
        category: ThingCategory.clothes,
        forMember: 'maja',
      ).copyWith(state: ItemState.ordered),
    ),
    (
      't3',
      ShoppingItemPayload.thing(
        listId: 'things',
        name: 'Glödlampor',
        category: ThingCategory.home,
      ),
    ),
  ];

  Future<void> openThings(WidgetTester tester) async {
    await pumpApp(
      tester,
      overrides: [
        shoppingListsProvider.overrideWith(
          (ref) => Stream.value([
            (
              'things',
              ShoppingListPayload.write(
                name: 'Saker att köpa',
                kind: ShoppingListKind.things,
              ),
            ),
          ]),
        ),
        shoppingItemsProvider.overrideWith((ref) => Stream.value(items)),
        currentListProvider.overrideWith(_FixedList.new),
        sizeCardsProvider.overrideWith(
          (ref) => Stream.value({
            'leo': [const SizeEntry(kind: SizeKind.shoe, value: '36')],
          }),
        ),
      ],
    );
    await tester.tap(find.text('Shopping').last);
    await tester.pumpAndSettle();
  }

  testWidgets('grouped by kind, with who, size, date and buyer', (
    tester,
  ) async {
    await openThings(tester);
    expect(find.text('Sport and leisure'), findsOneWidget);
    expect(find.text('Clothes'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Leo · size 36 · by 19 Sept · Anna buys'), findsOneWidget);
    expect(find.text('Ordered · Maja'), findsOneWidget);
    // Food's aisles, staples and the shop's app are not here.
    expect(find.text('Dairy'), findsNothing);
    expect(find.text('Add staples'), findsNothing);
  });

  testWidgets('grouped by person, with their sizes in the heading', (
    tester,
  ) async {
    await openThings(tester);
    await tester.tap(find.text('By person'));
    await tester.pumpAndSettle();
    expect(find.text('Leo · Shoes 36'), findsOneWidget);
    expect(find.text('Maja'), findsOneWidget);
    expect(find.text('For the family'), findsOneWidget);
  });

  testWidgets('a thing opens with its fields', (tester) async {
    await openThings(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Change thing'), findsOneWidget);
    expect(find.text('Needed by'), findsOneWidget);
    expect(find.text('Who buys it'), findsOneWidget);
    expect(find.text('Ordered'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);
  });
}

class _FixedList extends CurrentListNotifier {
  @override
  Future<String?> build() async => 'things';
}
