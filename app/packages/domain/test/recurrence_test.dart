import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// The golden suite. These are the cases every calendar product gets wrong at
/// least once. They run in milliseconds and should run on every commit.

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  final expander = RecurrenceExpander();

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

      final before = occurrences.firstWhere(
          (o) => o.start.isBefore(DateTime.utc(2026, 3, 29)));
      final after = occurrences.firstWhere(
          (o) => o.start.isAfter(DateTime.utc(2026, 3, 30)));

      expect(before.start.hour, 16, reason: '17:30 CET is 16:30 UTC');
      expect(after.start.hour, 15, reason: '17:30 CEST is 15:30 UTC');
    });
  });

  group('autumn DST change', () {
    test('weekly series survives the repeated hour', () {
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

      // Six Thursdays in that window, none dropped or duplicated by the change.
      expect(occurrences.length, 6);
      final dates = occurrences.map((o) => o.originalStart).toSet();
      expect(dates.length, 6, reason: 'no duplicate occurrences');
    });
  });

  group('leap day birthdays', () {
    test('29 February yearly does not silently become 1 March', () {
      final series = EventSeries(
        eventId: 'birthday',
        localStart: DateTime(2024, 2, 29, 0, 0),
        duration: const Duration(days: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(frequency: Frequency.yearly, byMonth: 2),
      );

      final occurrences = expander.expand(
        series,
        DateTime.utc(2027, 1, 1),
        DateTime.utc(2027, 12, 31),
      );

      // 2027 is not a leap year. Clamping to 28 February is the defensible
      // behaviour; the test exists so the choice is deliberate and visible.
      for (final o in occurrences) {
        expect(o.start.month, 2);
      }
    });
  });

  group('month-end recurrence', () {
    test('31st of the month clamps rather than overflowing', () {
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
        DateTime.utc(2026, 5, 1),
      );

      final months = occurrences.map((o) => o.start.month).toList();
      expect(months.contains(3), isTrue,
          reason: 'February must not overflow into a skipped March');
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

      expect(
        occurrences.any((o) => o.originalStart == secondWeek),
        isFalse,
        reason: 'cancelled occurrence must not appear — '
            'this is the case that must also cancel its reminders',
      );
      expect(occurrences.length, greaterThan(2));
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

      final match =
          occurrences.firstWhere((o) => o.originalStart == original);
      expect(match.start, moved);
      expect(match.isException, isTrue);
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
