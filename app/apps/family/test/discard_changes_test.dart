import 'package:family/src/features/events/new_event_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'week_screen_test.dart' show openWeek;

/// Changing something can always be given up: a close button, and a
/// question before what was typed is thrown away.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  Future<void> openForm(WidgetTester tester) async {
    await openWeek(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(NewEventScreen), findsOneWidget);
  }

  testWidgets('nothing changed: the close button just closes', (tester) async {
    await openForm(tester);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewEventScreen), findsNothing);
    expect(find.text('Discard your changes?'), findsNothing);
  });

  testWidgets('something typed: asked first, and can keep editing', (
    tester,
  ) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Football');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(NewEventScreen), findsOneWidget);
    expect(find.text('Football'), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(NewEventScreen), findsNothing);
  });
}
