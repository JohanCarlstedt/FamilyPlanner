import 'package:family/src/common/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('a Swedish device gets Swedish, dates included', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('sv', 'SE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await pumpApp(tester);

    expect(find.text('torsdag 17 september · Vecka 38'), findsOneWidget);
    expect(find.text('Ny händelse'), findsOneWidget);
    expect(find.text('Idag'), findsWidgets);
  });

  test('any other language falls back to British English', () {
    expect(
      resolveAppLocale(const Locale('de'), appLocales),
      const Locale('en', 'GB'),
    );
    expect(
      resolveAppLocale(const Locale('en', 'US'), appLocales),
      const Locale('en', 'GB'),
    );
    expect(
      resolveAppLocale(const Locale('sv', 'FI'), appLocales),
      const Locale('sv'),
    );
    expect(resolveAppLocale(null, appLocales), const Locale('en', 'GB'));
  });
}
