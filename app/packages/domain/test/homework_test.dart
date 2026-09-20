import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';

  CalendarEvent activity(String id, DateTime local, int minutes,
          {List<String> going = const ['maja'],
          EventKind kind = EventKind.activity}) =>
      CalendarEvent(
        series: EventSeries(
          eventId: id,
          localStart: local,
          duration: Duration(minutes: minutes),
          timeZone: zone,
        ),
        title: id,
        kind: kind,
        participantIds: going,
      );

  List<(DateTime, DateTime)> slots(List<CalendarEvent> events,
          {DateTime? now, int minutes = 45}) =>
      [
        for (final s in HomeworkPlanner.freeSlots(
          events: events,
          memberId: 'maja',
          // Tuesday 22 September, 12:00 local.
          now: now ?? DateTime.utc(2026, 9, 22, 10),
          // Due Friday morning.
          due: DateTime.utc(2026, 9, 25, 6),
          minutes: minutes,
          timeZone: zone,
        ))
          (s.start, s.end),
      ];

  test('an afternoon slot each day before it\'s due, around activities', () {
    final found = slots([
      // Football Tuesday 17:00–18:30; school every weekday till 15:00 is a
      // routine, which counts as busy too.
      activity('football', DateTime.utc(2026, 9, 22, 17), 90),
      activity('school', DateTime.utc(2026, 9, 23, 8), 7 * 60,
          kind: EventKind.routine),
    ]);
    expect(found, [
      // Tuesday 15:30 local, before football.
      (DateTime.utc(2026, 9, 22, 13, 30), DateTime.utc(2026, 9, 22, 14, 15)),
      // Wednesday 15:30, after school.
      (DateTime.utc(2026, 9, 23, 13, 30), DateTime.utc(2026, 9, 23, 14, 15)),
      // Thursday.
      (DateTime.utc(2026, 9, 24, 13, 30), DateTime.utc(2026, 9, 24, 14, 15)),
    ]);
  });

  test('someone else\'s activities don\'t get in the way', () {
    final found = slots([
      activity('erik-gym', DateTime.utc(2026, 9, 22, 15, 30), 120,
          going: ['erik']),
    ]);
    expect(found.first.$1, DateTime.utc(2026, 9, 22, 13, 30));
  });

  test('no slot starts in the past or runs past bedtime', () {
    final found = slots(
      [],
      // Tuesday 19:30 local.
      now: DateTime.utc(2026, 9, 22, 17, 30),
      minutes: 60,
    );
    // 19:30 + 60 would end after 20:00: Tuesday is out.
    expect(found.first.$1, DateTime.utc(2026, 9, 23, 13, 30));
  });


  group('homework that repeats', () {
    // Glosor every Friday, due at eight in the morning.
    HomeworkTemplate weekly({DateTime? until}) => HomeworkTemplate(
      id: 'glosor',
      memberId: 'maja',
      title: 'Glosor',
      subjectId: 'svenska',
      estimatedMinutes: 20,
      schedule: EventSeries(
        eventId: 'glosor',
        localStart: DateTime.utc(2026, 9, 18, 8),
        duration: Duration.zero,
        timeZone: zone,
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.fr},
        ),
        recurrenceUntil: until,
      ),
    );

    List<DateTime> dueDates(List<PlannedHomework> planned) =>
        [for (final p in planned) p.dueAt];

    test('plans one piece of homework a week, and no more', () {
      final planned = planHomework(
        template: weekly(),
        from: DateTime.utc(2026, 9, 18),
        until: DateTime.utc(2026, 10, 10),
      );

      // Four Fridays fall in the window; the fifth is outside it.
      expect(dueDates(planned), [
        DateTime.utc(2026, 9, 18, 6), // 08:00 in Stockholm is 06:00 UTC
        DateTime.utc(2026, 9, 25, 6),
        DateTime.utc(2026, 10, 2, 6),
        DateTime.utc(2026, 10, 9, 6),
      ]);
    });

    test('each week has an identity of its own, so one can be done', () {
      final planned = planHomework(
        template: weekly(),
        from: DateTime.utc(2026, 9, 18),
        until: DateTime.utc(2026, 10, 3),
      );

      // The key is what the id is derived from: same everywhere, every time,
      // so two devices planning the same week write one piece of homework.
      expect(planned.map((p) => p.key).toSet(), hasLength(planned.length));
      expect(planned.first.key, 'glosor/2026-09-18T06:00:00.000Z');

      final again = planHomework(
        template: weekly(),
        from: DateTime.utc(2026, 9, 20),
        until: DateTime.utc(2026, 10, 3),
      );
      expect(again.first.key, planned[1].key);
    });

    test('stays at eight in the morning across the clock change', () {
      // Sweden goes off summer time on 25 October 2026.
      final planned = planHomework(
        template: weekly(),
        from: DateTime.utc(2026, 10, 20),
        until: DateTime.utc(2026, 11, 7),
      );

      expect(dueDates(planned), [
        DateTime.utc(2026, 10, 23, 6), // summer time: 08:00 is 06:00 UTC
        DateTime.utc(2026, 10, 30, 7), // winter time: 08:00 is 07:00 UTC
        DateTime.utc(2026, 11, 6, 7),
      ]);
    });

    test('ends when the arrangement does', () {
      final planned = planHomework(
        template: weekly(until: DateTime.utc(2026, 10, 1)),
        from: DateTime.utc(2026, 9, 18),
        until: DateTime.utc(2026, 10, 31),
      );

      expect(dueDates(planned), [
        DateTime.utc(2026, 9, 18, 6),
        DateTime.utc(2026, 9, 25, 6),
      ]);
    });
  });
}
