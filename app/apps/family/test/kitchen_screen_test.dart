import 'package:family/src/features/kitchen/kitchen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('the kitchen display shows the day, dinner and the list', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 800));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Kitchen display'),
      find.byType(ListView).first,
      const Offset(0, -120),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen display'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(KitchenScreen), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Dinner'), findsWidgets);
    expect(find.text('Shopping'), findsWidgets);
  });

  testWidgets('and fits a phone-sized screen too', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Kitchen display'),
      find.byType(ListView).first,
      const Offset(0, -120),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen display'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // One column on a phone: the day is at the top, the rest below it.
    expect(find.byType(KitchenScreen), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
