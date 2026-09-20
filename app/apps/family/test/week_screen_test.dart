import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:domain/domain.dart';
import 'package:family/src/data/store_providers.dart';
import 'package:family/src/features/events/new_event_screen.dart';

import 'support/pump_app.dart';

Future<void> openWeek(
  WidgetTester tester, {
  DevicePreferences? preferences,
}) async {
  // Tall, so the whole week is on screen without scrolling.
  await pumpApp(tester, size: const Size(390, 6000), preferences: preferences);
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
    expect(find.text('14–20 Sept'), findsOneWidget);
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

  testWidgets('the chosen view is remembered on this device', (tester) async {
    final preferences = MemoryPreferences();
    await openWeek(tester, preferences: preferences);
    bool mine() => tester
        .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
        .selected
        .single;
    expect(mine(), isFalse, reason: 'a parent opens on Family');

    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();

    // A fresh start of the app on the same device.
    await tester.pumpWidget(const SizedBox());
    await openWeek(tester, preferences: preferences);
    expect(mine(), isTrue);
  });

  testWidgets('a trip is visible in the week, on every day it covers', (
    tester,
  ) async {
    // Away from Thursday to the Sunday: the sample week runs 14–20
    // September 2026.
    final travelling = Absence(
      id: 'trip',
      title: 'Travelling',
      startsOn: DateTime.utc(2026, 9, 17),
      endsOn: DateTime.utc(2026, 9, 20),
      memberIds: const {'anna'},
      suppressKinds: const {EventKind.routine},
    );

    await pumpApp(
      tester,
      size: const Size(390, 6000),
      absences: [travelling],
    );
    await tester.tap(find.text('Week').last);
    await tester.pumpAndSettle();

    // Four days covered, so four bands: a trip that spans the week should
    // not be a thing you can only see on the day it starts.
    expect(find.textContaining('Travelling'), findsNWidgets(4));
  });

  testWidgets('a new event can be started from the week, on the week in view', (
    tester,
  ) async {
    await openWeek(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // The form itself, not merely something with a text field in it.
    expect(find.byType(NewEventScreen), findsOneWidget);
    final form = tester.widget<NewEventScreen>(find.byType(NewEventScreen));
    // Started on the week in view: the sample week holds today, so today.
    expect(form.at, DateTime.utc(2026, 9, 17, 9));
  });
}
