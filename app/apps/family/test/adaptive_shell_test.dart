import 'package:family/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAppAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: FamilyApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone width uses bottom navigation and opens on Today', (
    tester,
  ) async {
    await pumpAppAt(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);
  });

  testWidgets('tablet portrait uses a compact navigation rail', (tester) async {
    await pumpAppAt(tester, const Size(700, 1000));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('tablet landscape extends the rail', (tester) async {
    await pumpAppAt(tester, const Size(1200, 800));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('tapping a destination switches screen', (tester) async {
    await pumpAppAt(tester, const Size(390, 844));

    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Shopping'), findsOneWidget);
  });
}
