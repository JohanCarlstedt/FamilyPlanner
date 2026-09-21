import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Today shows the next forty-eight hours.
///
/// At six in the evening the useful question is not "what is left today"
/// but "what is tonight and tomorrow morning" — the packing, the early
/// start, who is driving. Today's day ends before the answer does.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('tomorrow appears under its own heading', (tester) async {
    await pumpApp(tester);

    // The sample family repeats its week, so Friday has the same shape as
    // Thursday. What matters is that the day after is on the screen at
    // all, and that it is labelled rather than run together with today's.
    await tester.dragUntilVisible(
      find.text('Tomorrow'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );

    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Friday 18 September'), findsOneWidget);
  });

  testWidgets('today comes first, tomorrow after it', (tester) async {
    await pumpApp(tester);

    final heading = tester.getTopLeft(
      find.text('Thursday 17 September · Week 38'),
    );
    await tester.dragUntilVisible(
      find.text('Tomorrow'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );

    // The header is pinned in the app bar, so this only checks the
    // ordering is not reversed — tomorrow is reached by scrolling down.
    expect(heading.dy, lessThan(tester.getTopLeft(find.text('Tomorrow')).dy));
  });
}
