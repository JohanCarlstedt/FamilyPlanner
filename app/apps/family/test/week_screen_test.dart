import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

Future<void> openWeek(WidgetTester tester) async {
  // Tall, so the whole week is on screen without scrolling.
  await pumpApp(tester, size: const Size(390, 6000));
  await tester.tap(find.text('Week').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // The sample family's recurring events repeat daily or on Thursdays, the
  // sample day; its one-off dentist and parents' evening are on Thursday.

  testWidgets('shows the ISO week, Monday first', (tester) async {
    await openWeek(tester);

    expect(find.text('Week 38'), findsOneWidget);
    expect(find.text('14–20 Sep'), findsOneWidget);
    final monday = tester.getTopLeft(find.text('Monday 14 September')).dy;
    final sunday = tester.getTopLeft(find.text('Sunday 20 September')).dy;
    expect(monday < sunday, isTrue);
  });

  testWidgets('weekly events land on their day only', (tester) async {
    await openWeek(tester);

    // Football is weekly on Thursdays; the dentist is a one-off that day.
    expect(find.text('Football training'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
    final thursday = tester.getTopLeft(find.text('Thursday 17 September')).dy;
    final friday = tester.getTopLeft(find.text('Friday 18 September')).dy;
    final football = tester.getTopLeft(find.text('Football training')).dy;
    expect(thursday < football && football < friday, isTrue);
  });

  testWidgets('a member filter hides other members\' events and warnings', (
    tester,
  ) async {
    await openWeek(tester);
    expect(find.textContaining('with no one responsible'), findsOneWidget);

    // Leo only: Maja's unassigned football, and its warning, disappear.
    final leo = find.widgetWithText(FilterChip, 'Leo');
    await tester.ensureVisible(leo);
    await tester.pumpAndSettle();
    await tester.longPress(leo);
    await tester.pumpAndSettle();

    expect(find.text('Football training'), findsNothing);
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.textContaining('with no one responsible'), findsNothing);
    // Family-wide routines stay.
    expect(find.text('Dinner'), findsWidgets);
  });

  testWidgets('next week has the weekly events again', (tester) async {
    await openWeek(tester);
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();

    expect(find.text('Week 39'), findsOneWidget);
    expect(find.text('Football training'), findsOneWidget);
    expect(
      find.text('Dentist'),
      findsNothing,
      reason: 'the dentist was a one-off',
    );
  });
}
