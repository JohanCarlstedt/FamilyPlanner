import 'package:domain/domain.dart';
import 'package:family/src/integrations/weather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // The sample family at 11:00 on Thursday 17 September 2026: the school run
  // and dentist are over, piano is cancelled, football has no one responsible,
  // and Anna is booked for swimming and parents' evening at once.

  testWidgets('header shows the date and ISO week number', (tester) async {
    await pumpApp(tester);

    expect(find.text('Thursday 17 September · Week 38'), findsOneWidget);
  });

  testWidgets('warns about a child event with no one responsible', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('No one is responsible for 1 event'), findsOneWidget);
    expect(find.text('17:00  Football training · Maja'), findsOneWidget);
  });

  testWidgets('warns when a parent is double-booked', (tester) async {
    await pumpApp(tester);

    expect(find.text('Double-booked'), findsOneWidget);
    expect(
      find.text(
        "Anna: Swimming 17:30–18:15 overlaps Parents' evening 18:00–19:00",
      ),
      findsOneWidget,
    );
  });

  testWidgets('pins the next event that has not started', (tester) async {
    await pumpApp(tester);

    expect(find.text('Next up · in 6 h'), findsOneWidget);
    expect(find.text('17:00–18:15 · Sportshallen'), findsOneWidget);
  });

  testWidgets('shows cancelled events as cancelled, not hidden', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(find.text('Piano lesson'), 200);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('places the now marker between past and upcoming events', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(find.text('Piano lesson'), 200);
    final dentist = tester.getTopLeft(find.text('Dentist')).dy;
    final now = tester.getTopLeft(find.text('11:00')).dy;
    final piano = tester.getTopLeft(find.text('Piano lesson')).dy;
    expect(dentist < now && now < piano, isTrue);
  });

  testWidgets('event cards carry a visible stripe in the member colour', (
    tester,
  ) async {
    await pumpApp(tester);

    // Leo's colour, on the dentist card. A childless ColoredBox once
    // collapsed to zero width here and the stripe silently vanished.
    final stripe = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == const Color(0xFFCC79A7),
    );
    expect(stripe, findsWidgets);
    expect(tester.getSize(stripe.first).width, 6);
  });

  testWidgets('after the last event there is no next-up card', (tester) async {
    await pumpApp(tester, now: DateTime.utc(2026, 9, 17, 19)); // 21:00 local

    expect(find.textContaining('Next up'), findsNothing);
    expect(find.textContaining('No one is responsible for'), findsNothing);
  });

  testWidgets('today says what the weather is doing', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        weekWeatherProvider.overrideWith(
          (ref) async => {
            // Wall-clock date, as the forecast keys its days.
            DateTime.utc(2026, 9, 17): DayWeather(
              day: DateTime.utc(2026, 9, 17),
              symbol: 'rain',
              high: 14.2,
              low: 8.6,
              millimetres: 3.1,
            ),
          },
        ),
      ],
    );

    // The degrees and the rain, on the screen you look at in the morning
    // while deciding about a coat.
    expect(find.textContaining('14'), findsWidgets);
    expect(find.textContaining('9'), findsWidgets);
  });
}
