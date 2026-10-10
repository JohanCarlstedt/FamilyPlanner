import 'package:family/src/features/shopping/recipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Recipes from More, not only from the Shopping tab.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('More has the family\'s recipes', (tester) async {
    await pumpApp(tester, size: const Size(390, 2400));
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipesScreen), findsOneWidget);
  });
}
