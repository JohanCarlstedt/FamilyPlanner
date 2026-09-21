import 'package:family/src/features/homework/homework_screen.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Homework on Today.
///
/// The strip existed but returned nothing at all for a parent, which left
/// the one person who might do something about Thursday's glosor as the
/// only one in the house not told about them.
void main() {
  // Today computes its agenda in the family's zone.
  setUpAll(tzdata.initializeTimeZones);

  // The sample family's children (lib/src/data/sample_family.dart).
  const leo = 'leo';
  const maja = 'maja';

  List<(String, HomeworkPayload)> homework(DateTime soon) => [
    (
      'hw-1',
      HomeworkPayload.write(
        memberId: maja,
        title: 'Glosor',
        subjectId: null,
        dueAt: soon,
      ),
    ),
    (
      'hw-2',
      HomeworkPayload.write(
        memberId: leo,
        title: 'Läsläxa',
        subjectId: null,
        dueAt: soon.add(const Duration(hours: 24)),
      ),
    ),
  ];

  testWidgets('a parent sees the children\'s, with whose it is', (
    tester,
  ) async {
    final soon = DateTime.utc(2026, 9, 18, 8);
    await pumpApp(
      tester,
      overrides: [
        homeworkProvider.overrideWith((ref) => Stream.value(homework(soon))),
      ],
    );

    expect(find.text('Homework: 2 due soon'), findsOneWidget);
    // A title alone does not say whose it is.
    expect(find.textContaining('Maja: Glosor'), findsOneWidget);
    expect(find.textContaining('Leo: Läsläxa'), findsOneWidget);
  });

  testWidgets('soonest first', (tester) async {
    final soon = DateTime.utc(2026, 9, 18, 8);
    await pumpApp(
      tester,
      overrides: [
        homeworkProvider.overrideWith((ref) => Stream.value(homework(soon))),
      ],
    );

    final line = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.contains('Glosor'));
    expect(
      line.indexOf('Glosor') < line.indexOf('Läsläxa'),
      isTrue,
      reason: 'Maja\'s is due first: $line',
    );
  });

  testWidgets('nothing due soon shows nothing at all', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        homeworkProvider.overrideWith(
          (ref) => Stream.value(const <(String, HomeworkPayload)>[]),
        ),
      ],
    );

    expect(find.textContaining('Homework:'), findsNothing);
  });
}
