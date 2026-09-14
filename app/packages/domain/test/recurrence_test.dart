import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The golden suite. These are the cases every calendar product gets wrong at
/// least once. They run in milliseconds and should run on every commit.

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  final expander = RecurrenceExpander();

  /// Wall-clock hour in Stockholm, for asserting "stays 17:30 local".
  int stockholmHour(DateTime utc) =>
      tz.TZDateTime.from(utc, tz.getLocation('Europe/Stockholm')).hour;

  List<DateTime> starts(List<Occurrence> os) => os.map((o) => o.start).toList();

  group('weekly training across the spring DST change', () {
    // Sweden moves to summer time on the last Sunday in March.
    // Training at 17:30 must stay 17:30 local — so the UTC instant moves
    // from 16:30 to 15:30.
    test('keeps local wall-clock time, moves the UTC instant', () {
      final series = EventSeries(
        eventId: 'training',
        localStart: DateTime(2026, 3, 19, 17, 30), // Thursday before
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.th},
        ),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 4, 15),
      );

      final before = occurrences
          .firstWhere((o) => o.start.isBefore(DateTime.utc(2026, 3, 29)));
      final after = occurrences
          .firstWhere((o) => o.start.isAfter(DateTime.utc(2026, 3, 30)));

      expect(before.start.hour, 16, reason: '17:30 CET is 16:30 UTC');
      expect(after.start.hour, 15, reason: '17:30 CEST is 15:30 UTC');
    });
  });

  group('autumn DST change', () {
    // Sweden returns to standard time on 25 October 2026.
    test('weekly series keeps 18:00 local through the repeated hour', () {
      final series = EventSeries(
        eventId: 'scouts',
        localStart: DateTime(2026, 10, 15, 18, 0),
        duration: const Duration(hours: 2),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.th},
        ),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 11, 15),
      );

      // The series starts 15 October: 15, 22, 29 Oct and 5, 12 Nov.
      expect(occurrences.length, 5);
      expect(occurrences.map((o) => o.originalStart).toSet().length, 5,
          reason: 'no duplicate occurrences');
      expect(occurrences.map((o) => stockholmHour(o.start)), everyElement(18),
          reason: 'wall-clock time never moves');
      expect(occurrences.map((o) => o.start.hour), [16, 16, 17, 17, 17],
          reason: '18:00 CEST is 16:00 UTC, 18:00 CET is 17:00 UTC');
    });
  });

  group('02:30 on the changeover nights', () {
    // Daily 02:30 — the hour that doesn't exist in March and happens twice in
    // October. These also fail if wall-clock arithmetic passes through the
    // machine's own zone, which on a Swedish computer shifts 02:30 to 03:30.
    dailyAt230(DateTime start) => EventSeries(
          eventId: 'night',
          localStart: start,
          duration: const Duration(minutes: 15),
          timeZone: 'Europe/Stockholm',
          rule: const RecurrenceRule(frequency: Frequency.daily),
        );

    test(
        'spring: the missing 02:30 resolves forward, and the next days are 02:30 again',
        () {
      final occurrences = expander.expand(
        dailyAt230(DateTime(2026, 3, 28, 2, 30)),
        DateTime.utc(2026, 3, 27),
        DateTime.utc(2026, 4, 1),
      );

      expect(starts(occurrences), [
        DateTime.utc(2026, 3, 28, 1, 30), // 02:30 CET
        DateTime.utc(2026, 3, 29, 1, 30), // 02:30 doesn't exist → 03:30 CEST
        DateTime.utc(2026, 3, 30, 0, 30), // 02:30 CEST
        DateTime.utc(2026, 3, 31, 0, 30), // 02:30 CEST — no drift to 03:30
      ]);
    });

    test('autumn: the repeated 02:30 occurs once, at the first of the two', () {
      final occurrences = expander.expand(
        dailyAt230(DateTime(2026, 10, 24, 2, 30)),
        DateTime.utc(2026, 10, 23),
        DateTime.utc(2026, 10, 27),
      );

      expect(starts(occurrences), [
        DateTime.utc(2026, 10, 24, 0, 30), // 02:30 CEST
        DateTime.utc(2026, 10, 25, 0, 30), // first 02:30, still CEST
        DateTime.utc(2026, 10, 26, 1, 30), // 02:30 CET
      ]);
    });
  });

  group('invalid dates follow RFC 5545 by default', () {
    // RFC 5545: a recurrence instance on a date that doesn't exist is skipped.
    // Imported club and school feeds are expanded this way by every other
    // calendar, so ours must agree.
    test('monthly on the 31st skips short months', () {
      final series = EventSeries(
        eventId: 'rent',
        localStart: DateTime(2026, 1, 31, 9, 0),
        duration: const Duration(minutes: 30),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(frequency: Frequency.monthly),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 8, 1),
      );

      expect(occurrences.map((o) => o.start.month), [1, 3, 5, 7]);
      expect(occurrences.map((o) => o.start.day), everyElement(31));
    });

    test('COUNT counts instances that exist, not months visited', () {
      final series = EventSeries(
        eventId: 'rent',
        localStart: DateTime(2026, 1, 31, 9, 0),
        duration: const Duration(minutes: 30),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(frequency: Frequency.monthly, count: 3),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2027, 1, 1),
      );

      expect(occurrences.map((o) => o.start.month), [1, 3, 5]);
    });

    test('29 February yearly occurs only in leap years', () {
      final series = EventSeries(
        eventId: 'leap',
        localStart: DateTime(2024, 2, 29, 12, 0),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(frequency: Frequency.yearly),
      );

      expect(
        expander.expand(
            series, DateTime.utc(2027, 1, 1), DateTime.utc(2028, 1, 1)),
        isEmpty,
      );
      expect(
        starts(expander.expand(
            series, DateTime.utc(2028, 1, 1), DateTime.utc(2029, 1, 1))),
        [DateTime.utc(2028, 2, 29, 11, 0)],
      );
    });
  });

  group('celebrations clamp instead (RFC 7529 SKIP=BACKWARD)', () {
    // A birthday is a celebration the family expects every year. A 29 February
    // birthdate generates its rule with skip: backward — the spec records why.
    final birthday = EventSeries(
      eventId: 'birthday',
      localStart: DateTime(2024, 2, 29, 0, 0),
      duration: const Duration(days: 1),
      timeZone: 'Europe/Stockholm',
      rule: const RecurrenceRule(
        frequency: Frequency.yearly,
        skip: RecurrenceSkip.backward,
      ),
    );

    test('29 February birthday falls on 28 February in a common year', () {
      final occurrences = expander.expand(
        birthday,
        DateTime.utc(2027, 1, 1),
        DateTime.utc(2028, 1, 1),
      );

      expect(occurrences.length, 1);
      expect(stockholmHour(occurrences.single.start), 0);
      expect(occurrences.single.start, DateTime.utc(2027, 2, 27, 23, 0),
          reason: 'midnight 28 Feb in Stockholm');
    });

    test('and returns to 29 February in the next leap year — no drift', () {
      final occurrences = expander.expand(
        birthday,
        DateTime.utc(2028, 1, 1),
        DateTime.utc(2029, 1, 1),
      );

      expect(starts(occurrences), [DateTime.utc(2028, 2, 28, 23, 0)],
          reason: 'midnight 29 Feb in Stockholm');
    });

    test('monthly on the 31st clamps to month end, then recovers', () {
      final series = EventSeries(
        eventId: 'month-end',
        localStart: DateTime(2026, 1, 31, 9, 0),
        duration: const Duration(minutes: 30),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.monthly,
          skip: RecurrenceSkip.backward,
        ),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 6, 1),
      );

      expect(occurrences.map((o) => o.start.day), [31, 28, 31, 30, 31],
          reason: 'March is the 31st again, not a carried-forward 28th');
    });
  });

  group('weekly interval', () {
    test('every other Thursday', () {
      final series = EventSeries(
        eventId: 'piano',
        localStart: DateTime(2026, 5, 7, 17, 30),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          interval: 2,
          byWeekday: {Weekday.th},
        ),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
      );

      expect(starts(occurrences), [
        DateTime.utc(2026, 5, 7, 15, 30),
        DateTime.utc(2026, 5, 21, 15, 30),
      ]);
    });

    test('every other week on two days, skipping days before the start', () {
      final series = EventSeries(
        eventId: 'swim',
        localStart: DateTime(2026, 5, 7, 17, 30), // a Thursday
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          interval: 2,
          byWeekday: {Weekday.th, Weekday.tu},
        ),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
      );

      expect(occurrences.map((o) => o.start.day), [7, 19, 21],
          reason: 'Tuesday 5 May is before the series starts');
    });
  });

  group('exceptions', () {
    final base = EventSeries(
      eventId: 'training',
      localStart: DateTime(2026, 5, 7, 17, 30),
      duration: const Duration(hours: 1),
      timeZone: 'Europe/Stockholm',
      rule: const RecurrenceRule(
        frequency: Frequency.weekly,
        byWeekday: {Weekday.th},
      ),
    );

    test('a cancelled occurrence disappears and the rest survive', () {
      final secondWeek = DateTime.utc(2026, 5, 14, 15, 30);

      final series = EventSeries(
        eventId: base.eventId,
        localStart: base.localStart,
        duration: base.duration,
        timeZone: base.timeZone,
        rule: base.rule,
        exceptions: [
          ExceptionEntry(
            originalStart: secondWeek,
            type: ExceptionType.cancelled,
          ),
        ],
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
      );

      // Exact list, so the assertion can't pass vacuously.
      expect(
        occurrences.map((o) => o.originalStart),
        [
          DateTime.utc(2026, 5, 7, 15, 30),
          DateTime.utc(2026, 5, 21, 15, 30),
          DateTime.utc(2026, 5, 28, 15, 30),
        ],
        reason: 'cancelled occurrence must not appear — '
            'this is the case that must also cancel its reminders',
      );
    });

    test('a moved occurrence keeps its original identity', () {
      final original = DateTime.utc(2026, 5, 14, 15, 30);
      final moved = DateTime.utc(2026, 5, 15, 15, 30);

      final series = EventSeries(
        eventId: base.eventId,
        localStart: base.localStart,
        duration: base.duration,
        timeZone: base.timeZone,
        rule: base.rule,
        exceptions: [
          ExceptionEntry(
            originalStart: original,
            type: ExceptionType.moved,
            overrideStart: moved,
          ),
        ],
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
      );

      final match = occurrences.firstWhere((o) => o.originalStart == original);
      expect(match.start, moved);
      expect(match.isException, isTrue);
    });
  });

  group('output instants', () {
    // TZDateTime's == is false against any plain DateTime, so leaking it makes
    // every caller's equality check silently fail.
    test('are plain UTC DateTimes that compare equal by value', () {
      final series = EventSeries(
        eventId: 'training',
        localStart: DateTime(2026, 5, 7, 17, 30),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      );

      final o = expander
          .expand(series, DateTime.utc(2026, 5, 1), DateTime.utc(2026, 6, 1))
          .single;

      expect(o.start.isUtc, isTrue);
      expect(o.start == DateTime.utc(2026, 5, 7, 15, 30), isTrue);
      expect(o.originalStart == DateTime.utc(2026, 5, 7, 15, 30), isTrue);
      expect(o.end == DateTime.utc(2026, 5, 7, 16, 30), isTrue);
    });
  });

  group('window semantics', () {
    test('an event straddling the window edge is included', () {
      final series = EventSeries(
        eventId: 'sleepover',
        localStart: DateTime(2026, 6, 5, 18, 0),
        duration: const Duration(hours: 20),
        timeZone: 'Europe/Stockholm',
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2026, 6, 6),
        DateTime.utc(2026, 6, 7),
      );

      expect(occurrences.length, 1,
          reason: 'overlap, not containment — it is on screen, so return it');
    });
  });

  group('robustness', () {
    test('a rule that matches nothing terminates instead of hanging', () {
      final series = EventSeries(
        eventId: 'broken',
        localStart: DateTime(2026, 1, 1, 9, 0),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.monthly,
          byMonthDay: 31,
        ),
      );

      expect(
        () => expander.expand(
          series,
          DateTime.utc(2026, 2, 1),
          DateTime.utc(2026, 2, 28),
        ),
        returnsNormally,
      );
    });
  });
}
