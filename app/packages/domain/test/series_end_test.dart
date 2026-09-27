import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A repeating event's last day, as a person sets it: "until the 14th of
/// December" means the practice on the 14th happens too.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  const weekly = RecurrenceRule(
    frequency: Frequency.weekly,
    byWeekday: {Weekday.mo},
    count: 10,
  );

  List<DateTime> mondays(RecurrenceRule rule) => [
        for (final o in RecurrenceExpander().expand(
          EventSeries(
            eventId: 'training',
            localStart: DateTime.utc(2026, 11, 2, 18),
            duration: const Duration(hours: 1),
            timeZone: 'Europe/Stockholm',
            rule: rule,
          ),
          DateTime.utc(2026, 10, 1),
          DateTime.utc(2027, 6, 1),
        ))
          o.start,
      ];

  test('the last day is included, evening practice and all', () {
    // Monday 14 December 2026, 18:00.
    final rule = endingOn(weekly, DateTime(2026, 12, 14));
    final all = mondays(rule);
    expect(all, hasLength(7));
    expect(all.last, DateTime.utc(2026, 12, 14, 17));
  });

  test('an end date replaces an end after so many times', () {
    expect(endingOn(weekly, DateTime(2026, 12, 14)).count, isNull);
  });

  test('no end date: on for ever, or as many times as it said', () {
    final open = endingOn(weekly, null);
    expect(open.until, isNull);
    expect(open.count, 10);
  });

  test('everything else about the rule is kept', () {
    const every2 = RecurrenceRule(
      frequency: Frequency.weekly,
      interval: 2,
      byWeekday: {Weekday.tu, Weekday.th},
      skip: RecurrenceSkip.backward,
    );
    final ended = endingOn(every2, DateTime(2027, 1, 31));
    expect(ended.interval, 2);
    expect(ended.byWeekday, {Weekday.tu, Weekday.th});
    expect(ended.skip, RecurrenceSkip.backward);
    expect(ended.until, DateTime.utc(2027, 1, 31, 23, 59));
  });
}
