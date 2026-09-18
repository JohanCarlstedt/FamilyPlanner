import 'package:domain/domain.dart';
import 'package:family/src/features/events/occurrence_editing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const zone = 'Europe/Stockholm';
  const expander = RecurrenceExpander();

  // Thursdays at 17:30 from 3 September 2026, across the October change to
  // winter time.
  final training = EventSeries(
    eventId: 'training',
    localStart: DateTime.utc(2026, 9, 3, 17, 30),
    duration: const Duration(hours: 1),
    timeZone: zone,
    rule: const RecurrenceRule(
      frequency: Frequency.weekly,
      byWeekday: {Weekday.th},
    ),
  );

  List<DateTime> starts(EventSeries s) => [
    for (final o in expander.expand(
      s,
      DateTime.utc(2026, 9, 1),
      DateTime.utc(2026, 11, 30),
    ))
      o.originalStart,
  ];

  test('ending before an occurrence keeps every one before it', () {
    // 5 November, after the change: 17:30 local is 16:30 UTC.
    final at = DateTime.utc(2026, 11, 5, 16, 30);
    final ended = EventSeries(
      eventId: training.eventId,
      localStart: training.localStart,
      duration: training.duration,
      timeZone: zone,
      rule: endingBefore(training.rule!, wallClock(at, zone)),
    );

    final kept = starts(ended);
    expect(kept.last, DateTime.utc(2026, 10, 29, 16, 30));
    expect(kept, everyElement(isNot(at)));
    expect(kept, hasLength(9));
  });

  test('an earlier end the series already had is kept', () {
    final seasonEnd = DateTime.utc(2026, 10, 1, 23, 59);
    final rule = RecurrenceRule(
      frequency: Frequency.weekly,
      byWeekday: const {Weekday.th},
      until: seasonEnd,
    );
    final ended = endingBefore(rule, DateTime.utc(2026, 11, 5, 17, 30));
    expect(ended.until, seasonEnd);
  });

  test('wall clock and instant round-trip in the family zone', () {
    final wall = DateTime.utc(2026, 10, 29, 17, 30);
    final instant = instantOf(wall, zone);
    expect(instant, DateTime.utc(2026, 10, 29, 16, 30));
    // In this direction too: a TZDateTime on the left is never equal, which
    // made every edited occurrence look moved.
    expect(instant == DateTime.utc(2026, 10, 29, 16, 30), isTrue);
    expect(wallClock(instant, zone), wall);
  });

  test('from the first occurrence on is the whole series', () {
    expect(
      hasOccurrenceBefore(training, DateTime.utc(2026, 9, 3, 15, 30)),
      isFalse,
    );
    expect(
      hasOccurrenceBefore(training, DateTime.utc(2026, 9, 10, 15, 30)),
      isTrue,
    );
  });
}
