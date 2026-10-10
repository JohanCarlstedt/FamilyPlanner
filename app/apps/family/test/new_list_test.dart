import 'dart:async';

import 'package:family/src/features/members/sizes_screen.dart';
import 'package:family/src/features/shopping/shopping_providers.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Making a new list, food or things, and the screen switching to it.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  final lists = StreamController<List<(String, ShoppingListPayload)>>();
  final food = ('food', ShoppingListPayload.write(name: 'Veckohandling'));
  final things = (
    'things',
    ShoppingListPayload.write(name: 'Saker', kind: ShoppingListKind.things),
  );

  testWidgets('switching from a food list to a new things list', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        shoppingListsProvider.overrideWith((ref) => lists.stream),
        shoppingItemsProvider.overrideWith((ref) => Stream.value(const [])),
        sizeCardsProvider.overrideWith((ref) => Stream.value(const {})),
      ],
    );
    lists.add([food]);
    await tester.tap(find.text('Shopping').last);
    await tester.pumpAndSettle();
    expect(find.text('Veckohandling'), findsOneWidget);

    // The dialog, as someone fills it in.
    await tester.tap(find.text('Veckohandling'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Things'));
    await tester.pumpAndSettle();
    expect(find.text('Things to buy'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // What saving leads to: the new list arrives and is chosen.
    lists.add([food, things]);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await container.read(currentListProvider.notifier).choose('things');
    await tester.pumpAndSettle();
    expect(find.text('By person'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
