import 'package:family/src/features/homework/homework_screen.dart';
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Homework on the week's lines.
///
/// The week is the screen a week gets planned on, and it was the one
/// screen that did not know homework existed: Thursday showed football
/// and said nothing about Friday's test.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  // Friday 18 September 2026, 08:00 Stockholm — the day after the sample
  // family's today.
  final friday = DateTime.utc(2026, 9, 18, 6);

  List<(String, HomeworkPayload)> homework() => [
    (
      'hw-1',
      HomeworkPayload.write(
        memberId: 'maja',
        title: 'Glosor',
        subjectId: null,
        type: HomeworkType.test,
        dueAt: friday,
      ),
    ),
  ];

  Future<void> openWeek(WidgetTester tester) async {
    await pumpApp(
      tester,
      overrides: [
        homeworkProvider.overrideWith((ref) => Stream.value(homework())),
      ],
    );
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
  }

  testWidgets('a test due that day is on that day\'s line', (tester) async {
    await openWeek(tester);

    await tester.scrollUntilVisible(find.text('Glosor · Maja'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Glosor · Maja'), findsOneWidget);

    // The same icon the homework screen uses. A test is not a different
    // kind of thing to look at; what changes is the name under it.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Glosor · Maja'),
          matching: find.byType(Row),
        ).first,
        matching: find.byIcon(Icons.menu_book),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping it says what is due, without leaving the week', (
    tester,
  ) async {
    await openWeek(tester);

    await tester.scrollUntilVisible(find.text('Glosor · Maja'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Glosor · Maja'));
    await tester.pumpAndSettle();

    expect(find.text('Homework due that day'), findsOneWidget);
    // Which kind it is belongs in the detail, not in the icon.
    expect(find.textContaining('Test'), findsOneWidget);
  });

  testWidgets('it sits on the day it is due, and only that day', (
    tester,
  ) async {
    await openWeek(tester);
    await tester.scrollUntilVisible(
      find.text('Friday 18 September'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    // Directly under Friday's heading, and nowhere else in the week.
    expect(find.textContaining('Glosor'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Friday 18 September')).dy,
      lessThan(tester.getTopLeft(find.text('Glosor · Maja')).dy),
    );
  });
}
