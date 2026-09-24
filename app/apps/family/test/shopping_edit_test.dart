import 'package:domain/domain.dart';
import 'package:family/src/features/shopping/shopping_providers.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// The shopping list can be changed after the fact: a line opened and
/// edited, several picked and removed together.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  final items = [
    (
      'i1',
      ShoppingItemPayload.write(
        listId: 'list-1',
        name: 'mjölk',
        quantity: 1,
        unit: Unit.l,
        category: Aisle.dairy,
      ),
    ),
    (
      'i2',
      ShoppingItemPayload.write(
        listId: 'list-1',
        name: 'bröd',
        category: Aisle.bakery,
      ),
    ),
  ];

  Future<void> openShopping(WidgetTester tester) async {
    await pumpApp(
      tester,
      overrides: [
        shoppingListsProvider.overrideWith(
          (ref) => Stream.value([
            ('list-1', ShoppingListPayload.write(name: 'Veckohandling')),
          ]),
        ),
        shoppingItemsProvider.overrideWith((ref) => Stream.value(items)),
        currentListProvider.overrideWith(_FixedList.new),
      ],
    );
    await tester.tap(find.text('Shopping').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a line opens with what it says, ready to change', (
    tester,
  ) async {
    await openShopping(tester);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Change item'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(field.controller!.text, isNotEmpty);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('several lines are picked and removed together', (
    tester,
  ) async {
    await openShopping(tester);
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.checklist), findsOneWidget);
  });

  testWidgets('holding a line starts picking with it', (tester) async {
    await openShopping(tester);
    await tester.longPress(find.textContaining('bröd'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('the list itself can be renamed or deleted', (tester) async {
    await openShopping(tester);
    await tester.tap(find.text('Veckohandling'));
    await tester.pumpAndSettle();
    expect(find.text('Rename list'), findsOneWidget);
    expect(find.text('Delete list'), findsOneWidget);
  });
}

class _FixedList extends CurrentListNotifier {
  @override
  Future<String?> build() async => 'list-1';
}
