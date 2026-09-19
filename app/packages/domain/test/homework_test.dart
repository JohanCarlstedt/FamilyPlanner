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
}
