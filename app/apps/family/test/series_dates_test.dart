import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'week_screen_test.dart' show openWeek;

/// A repeating event's first and last day, set in the form: "football on
/// Mondays from the 5th of October until the 14th of December".
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('weekly: from, until, and the end taken off again', (
    tester,
  ) async {
    await openWeek(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Not repeating: no series dates to set.
    expect(find.text('No end date'), findsNothing);
    await tester.tap(find.text('Repeats every week'));
    await tester.pumpAndSettle();
    expect(find.textContaining('From '), findsOneWidget);
    expect(find.text('No end date'), findsOneWidget);

    // An end date, picked from the calendar.
    await tester.tap(find.text('No end date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Until '), findsOneWidget);
    expect(find.byTooltip('Remove the end date'), findsOneWidget);

    // And off again.
    await tester.tap(find.byTooltip('Remove the end date'));
    await tester.pumpAndSettle();
    expect(find.text('No end date'), findsOneWidget);
  });
}
