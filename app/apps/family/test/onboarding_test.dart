import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('a fresh install opens on the welcome screen', (tester) async {
    await pumpApp(tester, membership: null);

    expect(find.text('Start a new family'), findsOneWidget);
    expect(find.text('Join my family'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a device in a family opens on Today', (tester) async {
    await pumpApp(tester);

    expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);
    expect(find.text('Start a new family'), findsNothing);
  });

  testWidgets('parents see Add a device under More', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Add a device'), findsOneWidget);
  });

  testWidgets('choosing to start a family asks for its name', (tester) async {
    await pumpApp(tester, membership: null);
    await tester.tap(find.text('Start a new family'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Family name'), findsOneWidget);
    expect(
      find.textContaining('the one thing our server can read'),
      findsOneWidget,
    );
  });
}
