import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Two homes explains itself: a parent setting a schedule up is told what
/// it changes elsewhere in the app, not left to guess.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('the (?) on Two homes says how it works', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Two homes'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.tap(find.text('Two homes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('How two homes works'), findsOneWidget);
    expect(find.textContaining('A parent from the other home'), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('How two homes works'), findsNothing);
  });
}
