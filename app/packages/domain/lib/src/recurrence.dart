import 'package:timezone/timezone.dart' as tz;

/// Occurrence expansion.
///
/// The rule that keeps this correct: a series stores its *local* time and its
/// IANA zone, never a UTC instant. 17:30 training stays 17:30 across a DST
/// boundary, which means the UTC instant moves. Expanding in UTC and converting
/// afterwards gets this wrong twice a year, in opposite directions.

enum Weekday { mo, tu, we, th, fr, sa, su }

enum Frequency { daily, weekly, monthly, yearly }

/// What happens when a rule lands on a date that doesn't exist — the 31st of a
/// short month, or 29 February in a common year. RFC 7529 `SKIP`.
enum RecurrenceSkip {
  /// RFC 5545 behaviour: the instance does not occur. The default, so imported
  /// feeds expand the way every other calendar expands them.
  omit,

  /// Clamp to the last valid day of that month. Celebrations use this, so a
  /// 29 February birthday falls on 28 February in a common year.
  backward,

  /// Roll to the first day of the following month.
  forward,
}

class RecurrenceRule {
  final Frequency frequency;
  final int interval;
  final Set<Weekday> byWeekday;
  final int? byMonthDay;
  final int? byMonth;
  final DateTime? until;
  final int? count;
  final RecurrenceSkip skip;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byWeekday = const {},
    this.byMonthDay,
    this.byMonth,
    this.until,
    this.count,
    this.skip = RecurrenceSkip.omit,
  });
}

class ExceptionEntry {
  /// Identifies the occurrence by the instant the unmodified series would produce.
  final DateTime originalStart;
  final ExceptionType type;
  final DateTime? overrideStart;
  final Duration? overrideDuration;

  const ExceptionEntry({
    required this.originalStart,
    required this.type,
    this.overrideStart,
    this.overrideDuration,
  });
}

enum ExceptionType { cancelled, moved, modified }

class EventSeries {
  final String eventId;

  /// Local wall-clock start. Not UTC — see the note at the top of this file.
  final DateTime localStart;
  final Duration duration;
  final String timeZone;
  final RecurrenceRule? rule;
  final DateTime? recurrenceUntil;
  final List<ExceptionEntry> exceptions;

  const EventSeries({
    required this.eventId,
    required this.localStart,
    required this.duration,
    required this.timeZone,
    this.rule,
    this.recurrenceUntil,
    this.exceptions = const [],
  });
}

class Occurrence {
  final String eventId;

  /// What the unmodified series produced. Stable identity across edits.
  final DateTime originalStart;
  final DateTime start;
  final DateTime end;
  final bool isException;

  const Occurrence({
    required this.eventId,
    required this.originalStart,
    required this.start,
    required this.end,
    this.isException = false,
  });
}

class RecurrenceExpander {
  /// How many consecutive periods may produce nothing before the rule is
  /// treated as matching nothing. The worst legitimate gap is 29 February with
  /// a large interval — a handful of periods. A malformed rule should degrade
  /// to "no occurrences", never to a hung UI thread.
  static const _maxEmptyPeriods = 1000;

  const RecurrenceExpander();

  /// Expands [series] into occurrences overlapping [windowStart, windowEnd).
  ///
  /// Both window bounds are UTC instants. Occurrences are returned as plain UTC
  /// [DateTime]s too; the caller formats them back into the family's zone.
  List<Occurrence> expand(
    EventSeries series,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final location = tz.getLocation(series.timeZone);
    final results = <Occurrence>[];

    final cancelled = <DateTime>{};
    final overrides = <DateTime, ExceptionEntry>{};
    for (final ex in series.exceptions) {
      final key = _utc(ex.originalStart);
      if (ex.type == ExceptionType.cancelled) {
        cancelled.add(key);
      } else {
        overrides[key] = ex;
      }
    }

    final origin = _wall(series.localStart);
    final rule = series.rule;

    if (rule == null) {
      _addIfInWindow(results, series, _toInstant(origin, location), windowStart,
          windowEnd, cancelled, overrides);
      return results;
    }

    final until = rule.until == null ? null : _wall(rule.until!);
    final seasonEnd =
        series.recurrenceUntil == null ? null : _wall(series.recurrenceUntil!);
    var emitted = 0;

    for (final local in _instances(origin, rule)) {
      if (rule.count != null && emitted >= rule.count!) break;
      if (until != null && local.isAfter(until)) break;
      if (seasonEnd != null && local.isAfter(seasonEnd)) break;

      final instant = _toInstant(local, location);

      // Instances arrive in order, so once one starts after the window nothing
      // later can qualify.
      if (instant.isAfter(windowEnd)) break;

      _addIfInWindow(results, series, instant, windowStart, windowEnd,
          cancelled, overrides);
      emitted++;
    }

    results.sort((a, b) => a.start.compareTo(b.start));
    return results;
  }

  /// Every instance of [rule], as wall-clock times in ascending order, none
  /// before [origin].
  ///
  /// Each period is computed from the origin — period n of a monthly rule is
  /// origin month + n × interval — rather than by stepping from the previous
  /// instance. Stepping lets a clamped 28 February become the day-of-month for
  /// every month after it, which is how a 31st-of-the-month series used to
  /// collapse to a single occurrence.
  Iterable<DateTime> _instances(DateTime origin, RecurrenceRule rule) sync* {
    final interval = rule.interval < 1 ? 1 : rule.interval;
    var emptyPeriods = 0;

    for (var period = 0; emptyPeriods < _maxEmptyPeriods; period++) {
      final step = period * interval;
      final found = <DateTime>[];

      switch (rule.frequency) {
        case Frequency.daily:
          found.add(_at(origin.year, origin.month, origin.day + step, origin));

        case Frequency.weekly:
          // RFC 5545 weeks start on Monday. Interval counts weeks; the named
          // days are all visited within each week that counts.
          final days = rule.byWeekday.isEmpty
              ? {Weekday.values[origin.weekday - 1]}
              : rule.byWeekday;
          final monday = origin.day - (origin.weekday - 1) + 7 * step;
          for (final day in Weekday.values) {
            if (days.contains(day)) {
              found.add(
                  _at(origin.year, origin.month, monday + day.index, origin));
            }
          }

        case Frequency.monthly:
          final d = _resolve(origin.year, origin.month + step,
              rule.byMonthDay ?? origin.day, origin, rule.skip);
          if (d != null) found.add(d);

        case Frequency.yearly:
          final month = rule.byMonth ?? origin.month;
          if (month < 1 || month > 12) break; // malformed: never matches
          final d = _resolve(origin.year + step, month,
              rule.byMonthDay ?? origin.day, origin, rule.skip);
          if (d != null) found.add(d);
      }

      final valid = found.where((d) => !d.isBefore(origin));
      if (valid.isEmpty) {
        emptyPeriods++;
        continue;
      }
      emptyPeriods = 0;
      yield* valid;
    }
  }

  /// The date [day] of [month] in [year], or what [skip] says to use when that
  /// date doesn't exist. Month overflow (month 14) rolls into the next year.
  DateTime? _resolve(
      int year, int month, int day, DateTime time, RecurrenceSkip skip) {
    // Negative BYMONTHDAY ("last day") isn't supported yet; treat as no match
    // rather than letting DateTime roll it into the previous month.
    if (day < 1) return null;
    final first = DateTime.utc(year, month);
    final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
    if (day <= lastDay) return _at(first.year, first.month, day, time);

    return switch (skip) {
      RecurrenceSkip.omit => null,
      RecurrenceSkip.backward => _at(first.year, first.month, lastDay, time),
      RecurrenceSkip.forward => _at(first.year, first.month + 1, 1, time),
    };
  }

  void _addIfInWindow(
    List<Occurrence> out,
    EventSeries series,
    DateTime originalInstant,
    DateTime windowStart,
    DateTime windowEnd,
    Set<DateTime> cancelled,
    Map<DateTime, ExceptionEntry> overrides,
  ) {
    if (cancelled.contains(originalInstant)) return;

    var start = originalInstant;
    var duration = series.duration;
    var isException = false;

    final override = overrides[originalInstant];
    if (override != null) {
      isException = true;
      final overrideStart = override.overrideStart;
      final overrideDuration = override.overrideDuration;
      if (overrideStart != null) start = _utc(overrideStart);
      if (overrideDuration != null) duration = overrideDuration;
    }

    final end = start.add(duration);

    // Overlap, not containment: an event starting before the window but running
    // into it is on screen and must be returned.
    if (end.isAfter(windowStart) && start.isBefore(windowEnd)) {
      out.add(Occurrence(
        eventId: series.eventId,
        originalStart: originalInstant,
        start: start,
        end: end,
        isException: isException,
      ));
    }
  }

  /// Converts a wall-clock time to a UTC instant in [location], following
  /// RFC 5545 §3.3.5 for the two awkward cases. Both are tested.
  /// - The hour that does not exist in spring. 02:30 on the changeover night is
  ///   read with the offset from before the gap, so it lands at 03:30 summer
  ///   time. tz already does this.
  /// - The hour that happens twice in autumn. RFC 5545 says the first, and it's
  ///   the defensible choice — earlier is safer for a reminder than later. tz
  ///   picks the second, so look for an earlier instant with the same wall time.
  DateTime _toInstant(DateTime wall, tz.Location location) {
    final t = tz.TZDateTime(location, wall.year, wall.month, wall.day,
        wall.hour, wall.minute, wall.second);

    // Largest shift first, so the earliest matching instant wins. 30 minutes
    // and two hours both exist in the tz database.
    for (final shift in const [
      Duration(hours: 2),
      Duration(hours: 1),
      Duration(minutes: 30),
    ]) {
      final earlier = tz.TZDateTime.fromMillisecondsSinceEpoch(
          location, t.millisecondsSinceEpoch - shift.inMilliseconds);
      if (_sameWallTime(earlier, wall)) return _utc(earlier);
    }
    return _utc(t);
  }

  bool _sameWallTime(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute &&
      a.second == b.second;

  /// Wall-clock fields held in a UTC DateTime, so day arithmetic never passes
  /// through the machine's own zone. `DateTime(2026, 3, 29, 2, 30)` on a
  /// computer set to Stockholm time silently becomes 03:30.
  DateTime _wall(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);

  /// A wall-clock date with [time]'s time of day. Day and month overflow roll
  /// over, which is what the weekly and daily steps rely on.
  DateTime _at(int year, int month, int day, DateTime time) =>
      DateTime.utc(year, month, day, time.hour, time.minute, time.second);

  /// A plain UTC DateTime for the same instant. TZDateTime's == is false
  /// against any plain DateTime, so it must never leak out of this class or
  /// into a set or map key.
  DateTime _utc(DateTime d) =>
      DateTime.fromMicrosecondsSinceEpoch(d.microsecondsSinceEpoch,
          isUtc: true);
}
