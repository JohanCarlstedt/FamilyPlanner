import 'package:domain/domain.dart';
import 'package:family/src/features/onboarding/first_week.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const school = WeekBlock(
    title: 'Skola',
    from: TimeOfDay(hour: 8, minute: 0),
    to: TimeOfDay(hour: 14, minute: 30),
    memberId: 'maja',
  );
  const dinner = WeekBlock(
    title: 'Middag',
    from: TimeOfDay(hour: 17, minute: 30),
    to: TimeOfDay(hour: 18, minute: 0),
    weekdaysOnly: false,
  );

  List<({DateTime? start, int minutes, Frequency? freq, List<String> who})>
  seed(DateTime today) => [
    for (final e in firstWeekEvents(
      today: today,
      timeZone: 'Europe/Stockholm',
      blocks: [school, dinner],
    ))
      (
        start: e.localStart,
        minutes: e.duration.inMinutes,
        freq: e.rule?.frequency,
        who: e.participantIds,
      ),
  ];

  test('school on weekdays from the next one, dinner every day from today', () {
    // Saturday 19 September.
    final [s, d] = seed(DateTime.utc(2026, 9, 19));
    expect(s.start, DateTime.utc(2026, 9, 21, 8));
    expect(s.minutes, 390);
    expect(s.freq, Frequency.weekly);
    expect(s.who, ['maja']);
    expect(d.start, DateTime.utc(2026, 9, 19, 17, 30));
    expect(d.freq, Frequency.daily);
    expect(d.who, isEmpty);
  });

  test('everything seeded is a routine: no reminders, no nagging', () {
    final events = firstWeekEvents(
      today: DateTime.utc(2026, 9, 16),
      timeZone: 'Europe/Stockholm',
      blocks: [school, dinner],
    );
    expect(events.map((e) => e.kind), everyElement(EventKind.routine));
    expect(events.first.localStart, DateTime.utc(2026, 9, 16, 8));
  });
}
