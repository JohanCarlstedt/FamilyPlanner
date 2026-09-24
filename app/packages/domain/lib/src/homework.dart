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

/// Homework that comes back every week: glosor every Friday, a reading log
/// every Monday, handing in the practice book each Thursday.
///
/// Spec §3 gives a piece of homework one `due_at`, which is right for most
/// of it — one assignment, one deadline. A standing weekly arrangement is a
/// different thing: it produces a *new* piece of homework each week, and
/// last Friday's being done says nothing about this Friday's. So it is
/// modelled as a template that plans them, the way an action template plans
/// chores (actions.dart), rather than as a recurrence on the homework
/// itself. Each week is its own object, with its own state, and the
/// template can be stopped without touching the weeks already done.
class HomeworkTemplate {
  const HomeworkTemplate({
    required this.id,
    required this.memberId,
    required this.title,
    required this.schedule,
    this.subjectId,
    this.description,
    this.type = HomeworkType.assignment,
    this.estimatedMinutes,
  });

  final String id;
  final String memberId;
  final String title;

  /// When it is due, and how often. The occurrence start is the deadline:
  /// homework has a moment it is due, not a span it occupies, so the
  /// series' duration is not used.
  final EventSeries schedule;

  final String? subjectId;
  final String? description;
  final HomeworkType type;
  final int? estimatedMinutes;
}

/// One week's homework, as a template calls for it.
class PlannedHomework {
  const PlannedHomework({
    required this.templateId,
    required this.occurrenceStart,
    required this.dueAt,
  });

  final String templateId;

  /// The occurrence as the unmodified series has it: its identity, which is
  /// what keeps the id stable when the window moves.
  final DateTime occurrenceStart;

  /// The deadline itself.
  final DateTime dueAt;

  /// The same on every device, so any of them can create it once and no
  /// child ends up with two copies of Friday's glosor.
  String get key => '$templateId/${occurrenceStart.toUtc().toIso8601String()}';
}

/// The homework [template] calls for, one per occurrence due between [from]
/// and [until].
///
/// A window, never the whole term: a year of Fridays is fifty objects
/// nobody asked for, and the school year changes under them anyway.
List<PlannedHomework> planHomework({
  required HomeworkTemplate template,
  required DateTime from,
  required DateTime until,
  RecurrenceExpander expander = const RecurrenceExpander(),
}) =>
    [
      for (final o in expander.expand(template.schedule, from, until))
        PlannedHomework(
          templateId: template.id,
          occurrenceStart: o.originalStart.toUtc(),
          dueAt: o.start.toUtc(),
        ),
    ];
