import 'dart:io';

import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  const zone = 'Europe/Stockholm';

  String feed(String events, {String header = ''}) => [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//test//EN',
    if (header.isNotEmpty) header,
    events,
    'END:VCALENDAR',
  ].join('\r\n');

  group('laget.se', () {
    late List<ImportedEvent> events;
    setUpAll(
      () => events = ICalendar.parse(
        File('test/fixtures/laget-sample.ics').readAsStringSync(),
        timeZone: zone,
      ),
    );

    test('reads every event with its own id', () {
      expect(events, hasLength(3));
      expect(events.map((e) => e.uid).toSet(), hasLength(3));
      expect(events.first.uid, '29640387@laget.se');
    });

    test('the Windows zone name becomes wall-clock Stockholm time', () {
      final training = events.first;
      expect(training.localStart, DateTime.utc(2026, 8, 11, 17));
      expect(training.duration, const Duration(minutes: 90));
      expect(training.allDay, isFalse);
    });

    test('title, place, category and notes come across', () {
      final training = events.first;
      expect(training.title, 'Träning - Landvetter IF 2003 F-2015');
      expect(training.location, 'Konstgräsplan - Landvetter IP B-Plan');
      expect(training.categories, ['Träning']);
      expect(training.description, contains('Samlingstid\n2026-08-11 16:55'));
      expect(training.cancelled, isFalse);
    });
  });

  test('folded lines and escaped characters', () {
    final events = ICalendar.parse(
      feed(
        [
          'BEGIN:VEVENT',
          'UID:a',
          'DTSTART:20260920T100000Z',
          'SUMMARY:Match mot IFK\\, bortalag',
          'DESCRIPTION:Ta med vatten\\;',
          ' och frukt\\nSamling 09:15',
          'END:VEVENT',
        ].join('\r\n'),
      ),
      timeZone: zone,
    );
    expect(events.single.title, 'Match mot IFK, bortalag');
    expect(events.single.description, 'Ta med vatten;och frukt\nSamling 09:15');
  });

  test('UTC times land on the family\'s wall clock', () {
    final e = ICalendar.parse(
      feed('BEGIN:VEVENT\r\nUID:a\r\nDTSTART:20260920T150000Z\r\n'
          'DTEND:20260920T160000Z\r\nEND:VEVENT'),
      timeZone: zone,
    ).single;
    // 15:00 UTC is 17:00 in Stockholm in September.
    expect(e.localStart, DateTime.utc(2026, 9, 20, 17));
    expect(e.duration, const Duration(hours: 1));
  });

  test('an unknown zone name falls back to the calendar\'s own zone', () {
    final e = ICalendar.parse(
      feed(
        'BEGIN:VEVENT\r\nUID:a\r\nDTSTART;TZID=Some Club Zone:20260920T090000\r\n'
            'END:VEVENT',
        header: 'X-WR-TIMEZONE:Europe/London',
      ),
      timeZone: zone,
    ).single;
    // 09:00 in London is 10:00 in Stockholm.
    expect(e.localStart, DateTime.utc(2026, 9, 20, 10));
  });

  test('an all-day event runs midnight to midnight', () {
    final e = ICalendar.parse(
      feed('BEGIN:VEVENT\r\nUID:cup\r\nDTSTART;VALUE=DATE:20261010\r\n'
          'DTEND;VALUE=DATE:20261012\r\nSUMMARY:Cup\r\nEND:VEVENT'),
      timeZone: zone,
    ).single;
    expect(e.allDay, isTrue);
    expect(e.localStart, DateTime.utc(2026, 10, 10));
    expect(e.duration, const Duration(days: 2));
  });

  test('a cancelled event says so', () {
    final e = ICalendar.parse(
      feed('BEGIN:VEVENT\r\nUID:a\r\nDTSTART:20260920T100000Z\r\n'
          'STATUS:CANCELLED\r\nEND:VEVENT'),
      timeZone: zone,
    ).single;
    expect(e.cancelled, isTrue);
  });

  test('a simple weekly rule becomes a recurrence', () {
    final e = ICalendar.parse(
      feed('BEGIN:VEVENT\r\nUID:a\r\nDTSTART;TZID=Europe/Stockholm:20260907T170000\r\n'
          'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261130T230000Z\r\nEND:VEVENT'),
      timeZone: zone,
    ).single;
    expect(e.rule?.frequency, Frequency.weekly);
    expect(e.rule?.byWeekday, {Weekday.mo, Weekday.we});
    expect(e.rule?.until, isNotNull);
  });

  test('a rule this app can\'t repeat faithfully imports the first time only', () {
    final e = ICalendar.parse(
      feed('BEGIN:VEVENT\r\nUID:a\r\nDTSTART:20260907T150000Z\r\n'
          'RRULE:FREQ=MONTHLY;BYDAY=2TU\r\nEND:VEVENT'),
      timeZone: zone,
    ).single;
    expect(e.rule, isNull);
  });

  test('alarms inside an event are skipped, and so are changed instances', () {
    final events = ICalendar.parse(
      feed(
        [
          'BEGIN:VEVENT',
          'UID:a',
          'DTSTART:20260907T150000Z',
          'BEGIN:VALARM',
          'TRIGGER:-PT15M',
          'DESCRIPTION:Not the event',
          'END:VALARM',
          'SUMMARY:The event',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:a',
          'RECURRENCE-ID:20260914T150000Z',
          'DTSTART:20260914T160000Z',
          'SUMMARY:Moved once',
          'END:VEVENT',
        ].join('\r\n'),
      ),
      timeZone: zone,
    );
    expect(events.single.title, 'The event');
  });

  test('rubbish is not an event', () {
    expect(ICalendar.parse('<html>not a calendar</html>', timeZone: zone), isEmpty);
  });
}
