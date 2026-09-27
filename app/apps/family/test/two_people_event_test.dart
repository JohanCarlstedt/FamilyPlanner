import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'week_screen_test.dart' show openWeek;

/// An event for more than one person, entered in the form.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('a child responsible for their own thing, then a second '
      'person added: the form lets the child go rather than break', (
    tester,
  ) async {
    await openWeek(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // Maja alone, and Maja herself responsible: something only hers.
    await tester.tap(find.widgetWithText(FilterChip, 'Maja'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maja').last);
    await tester.pumpAndSettle();
    // Then Leo too.
    await tester.tap(find.widgetWithText(FilterChip, 'Leo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No one yet'), findsOneWidget);
  });
}
