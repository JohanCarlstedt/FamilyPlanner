import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// The morning summary, kept on the screen.
///
/// It was only ever a notification: read at seven, gone by five past, and
/// the one person who most needed it — whoever unlocked their phone at
/// four in the afternoon — had no way back to it.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('the day is summarised above everything else', (tester) async {
    await pumpApp(tester);

    expect(find.text('Your day'), findsOneWidget);

    // The sample family has a full Thursday, so the summary says how many
    // things and when the next one is — not a row of zeroes.
    expect(find.textContaining('things today'), findsOneWidget);
    expect(find.textContaining('next at'), findsOneWidget);
  });

  testWidgets('it sits above the timeline, not inside it', (tester) async {
    await pumpApp(tester);

    final summary = tester.getTopLeft(find.text('Your day'));
    final header = tester.getTopLeft(
      find.text('Thursday 17 September · Week 38'),
    );
    expect(summary.dy, greaterThan(header.dy));
  });
}
