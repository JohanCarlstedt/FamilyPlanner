import 'package:timezone/timezone.dart' as tz;

/// Occurrence expansion.
///
/// The rule that keeps this correct: a series stores its *local* time and its
/// IANA zone, never a UTC instant. 17:30 training stays 17:30 across a DST
/// boundary, which means the UTC instant moves. Expanding in UTC and converting
/// afterwards gets this wrong twice a year, in opposite directions.

enum Weekday { mo, tu, we, th, fr, sa, su }

enum Frequency { daily, weekly, monthly, yearly }

class RecurrenceRule {
  final Frequency frequency;
  final int interval;
  final Set<Weekday> byWeekday;
  final int? byMonthDay;
  final int? byMonth;
  final DateTime? until;
  final int? count;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byWeekday = const {},
    this.byMonthDay,
    this.byMonth,
    this.until,
    this.count,
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
  /// Expands [series] into occurrences overlapping [windowStart, windowEnd).
  ///
  /// Both window bounds are UTC instants. Occurrences are returned as UTC
  /// instants too; the caller formats them back into the family's zone.
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
      if (ex.type == ExceptionType.cancelled) {
        cancelled.add(ex.originalStart);
      } else {
        overrides[ex.originalStart] = ex;
      }
    }

    if (series.rule == null) {
      final start = _toInstant(series.localStart, location);
      _addIfInWindow(results, series, start, start, windowStart, windowEnd,
          cancelled, overrides);
      return results;
    }

    final rule = series.rule!;
    var localCursor = series.localStart;
    var emitted = 0;
    var guard = 0;

    // A hard iteration guard. A malformed rule should degrade to "no occurrences",
    // never to a hung UI thread.
    const maxIterations = 10000;

    while (guard++ < maxIterations) {
      if (rule.count != null && emitted >= rule.count!) break;
      if (rule.until != null && localCursor.isAfter(rule.until!)) break;
      if (series.recurrenceUntil != null &&
          localCursor.isAfter(series.recurrenceUntil!)) break;

      final instant = _toInstant(localCursor, location);

      // Past the window and moving away from it — nothing further can qualify.
      if (instant.isAfter(windowEnd)) break;

      if (_matchesRule(localCursor, series.localStart, rule)) {
        _addIfInWindow(results, series, instant, instant, windowStart, windowEnd,
            cancelled, overrides);
        emitted++;
      }

      localCursor = _advance(localCursor, rule);
    }

    results.sort((a, b) => a.start.compareTo(b.start));
    return results;
  }

  void _addIfInWindow(
    List<Occurrence> out,
    EventSeries series,
    DateTime originalInstant,
    DateTime instant,
    DateTime windowStart,
    DateTime windowEnd,
    Set<DateTime> cancelled,
    Map<DateTime, ExceptionEntry> overrides,
  ) {
    if (cancelled.contains(originalInstant)) return;

    var start = instant;
    var duration = series.duration;
    var isException = false;

    final override = overrides[originalInstant];
    if (override != null) {
      isException = true;
      if (override.overrideStart != null) start = override.overrideStart!;
      if (override.overrideDuration != null) duration = override.overrideDuration!;
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

  /// Converts a wall-clock local time to a UTC instant.
  ///
  /// Two awkward cases, both real and both tested:
  /// - The hour that does not exist in spring. 02:30 on the changeover night is
  ///   skipped; tz resolves it forward, which is what a calendar should do.
  /// - The hour that happens twice in autumn. tz picks the first, and that is
  ///   the defensible choice — earlier is safer for a reminder than later.
  DateTime _toInstant(DateTime local, tz.Location location) {
    final t = tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    return t.toUtc();
  }

  bool _matchesRule(DateTime candidate, DateTime seriesStart, RecurrenceRule rule) {
    switch (rule.frequency) {
      case Frequency.weekly:
        if (rule.byWeekday.isEmpty) return true;
        return rule.byWeekday.contains(_weekdayOf(candidate));
      case Frequency.monthly:
        if (rule.byMonthDay != null) return candidate.day == rule.byMonthDay;
        return candidate.day == seriesStart.day;
      case Frequency.yearly:
        final monthMatches =
            rule.byMonth == null || candidate.month == rule.byMonth;
        return monthMatches && candidate.day == seriesStart.day;
      case Frequency.daily:
        return true;
    }
  }

  DateTime _advance(DateTime cursor, RecurrenceRule rule) {
    switch (rule.frequency) {
      case Frequency.daily:
        return _addDays(cursor, rule.interval);
      case Frequency.weekly:
        // Step a day at a time when specific weekdays are named, so every named
        // day in the week is visited; the interval applies at week boundaries.
        return rule.byWeekday.isEmpty
            ? _addDays(cursor, 7 * rule.interval)
            : _addDays(cursor, 1);
      case Frequency.monthly:
        return _addMonths(cursor, rule.interval);
      case Frequency.yearly:
        return _addMonths(cursor, 12 * rule.interval);
    }
  }

  /// Adds days in wall-clock terms. Using Duration(days:) here would shift the
  /// time of day by an hour across a DST boundary, which is exactly the bug
  /// this class exists to avoid.
  DateTime _addDays(DateTime d, int days) => DateTime(
      d.year, d.month, d.day + days, d.hour, d.minute, d.second);

  /// Clamps to the end of a short month: 31 January + 1 month is 28 or 29
  /// February, not 2 or 3 March.
  DateTime _addMonths(DateTime d, int months) {
    final totalMonths = d.month - 1 + months;
    final year = d.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(year, month, day, d.hour, d.minute, d.second);
  }

  Weekday _weekdayOf(DateTime d) => switch (d.weekday) {
        DateTime.monday => Weekday.mo,
        DateTime.tuesday => Weekday.tu,
        DateTime.wednesday => Weekday.we,
        DateTime.thursday => Weekday.th,
        DateTime.friday => Weekday.fr,
        DateTime.saturday => Weekday.sa,
        _ => Weekday.su,
      };
}
