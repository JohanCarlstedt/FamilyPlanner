import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';
import 'recurrence.dart';

/// Spec §3 `homework.type`.
enum HomeworkType { assignment, reading, test, project, handIn }

/// Spec §3 `homework.state`. Overdue is never stored: it's derived.
enum HomeworkState { notStarted, inProgress, done, handedIn }

/// A time to do homework in.
class HomeworkSlot {
  const HomeworkSlot(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// Spec §3 "Scheduling assistance, not automation": free slots the child
/// can pick from, never a plan made for them.
class HomeworkPlanner {
  HomeworkPlanner._();

  /// When homework time starts and ends on a day (local wall clock).
  static const dayStart = (15, 30);
  static const dayEnd = (20, 0);

  /// The earliest free slot of [minutes] on each day from [now] until
  /// [due], between [dayStart] and [dayEnd], clear of everything
  /// [memberId] is in (their routines included).
  static List<HomeworkSlot> freeSlots({
    required List<CalendarEvent> events,
    required String memberId,
    required DateTime now,
    required DateTime due,
    required int minutes,
    required String timeZone,
    RecurrenceExpander expander = const RecurrenceExpander(),
  }) {
    final location = tz.getLocation(timeZone);
    final length = Duration(minutes: minutes);
    final busy = [
      for (final e in events)
        if (!e.isCancelled &&
            (e.participantIds.contains(memberId) ||
                e.responsibleMemberId == memberId))
          for (final o in expander.expand(e.series, now, due)) (o.start, o.end),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final slots = <HomeworkSlot>[];
    var day = tz.TZDateTime.from(now, location);
    day = tz.TZDateTime(location, day.year, day.month, day.day);
    while (day.isBefore(due)) {
      final open = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        dayStart.$1,
        dayStart.$2,
      ).toUtc();
      final close = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        dayEnd.$1,
        dayEnd.$2,
      ).toUtc();
      var start = open.isBefore(now) ? _roundUp(now) : open;
      for (final (b0, b1) in busy) {
        if (!b1.isAfter(start)) continue;
        if (!b0.isBefore(start.add(length))) break;
        // Overlaps: try right after it.
        start = b1;
      }
      final end = start.add(length);
      if (!end.isAfter(close) && !end.isAfter(due)) {
        slots.add(HomeworkSlot(start, end));
      }
      day = tz.TZDateTime(location, day.year, day.month, day.day + 1);
    }
    return slots;
  }

  /// To the next quarter hour.
  static DateTime _roundUp(DateTime t) {
    final extra = (15 - t.minute % 15) % 15;
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute)
        .add(Duration(minutes: extra));
  }
}
