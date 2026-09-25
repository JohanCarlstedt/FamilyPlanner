import 'package:family/src/common/day_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The weather's and the electricity price's sheets swipe from day to day.
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDayPager(
                context,
                first: DateTime.utc(2026, 9, 24),
                last: DateTime.utc(2026, 9, 26),
                initial: DateTime.utc(2026, 9, 25),
                title: (day) => 'Day: $day',
                page: (_, d) => SizedBox(
                  height: 300,
                  child: Center(child: Text('page ${d.day}')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the day asked for, and swipes to the next', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('page 25'), findsOneWidget);
    expect(find.textContaining('25 September'), findsOneWidget);
    await tester.fling(find.text('page 25'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('page 26'), findsOneWidget);
    expect(find.textContaining('26 September'), findsOneWidget);
    // The last day: nothing further to go to.
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('the arrows go back a day', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('page 24'), findsOneWidget);
    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(back.onPressed, isNull);
  });
}
