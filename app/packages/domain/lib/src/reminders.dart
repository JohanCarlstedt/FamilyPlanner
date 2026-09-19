import 'calendar_event.dart';
import 'recurrence.dart';

/// Who an event's reminder reaches (spec §8 `event_reminder.target`).
enum ReminderTarget {
  /// The people going and whoever is responsible. An event with no named
  /// participants is the whole family's, so it reaches everyone.
  participants,

  /// Only the responsible adult: the departure reminder's audience.
  responsible,

  /// Everyone in the family, going or not.
  allFamily,
}

/// "Remind … N minutes before", set on the event and inherited by every
/// occurrence (spec §8 `event_reminder`).
class EventReminder {
  final int minutesBefore;
  final ReminderTarget target;

  const EventReminder({
    required this.minutesBefore,
    this.target = ReminderTarget.participants,
  });
}

/// One reminder one member is owed.
class DueReminder {
  /// The occurrence as it will happen: its own title and responsible adult.
  final CalendarEvent event;

  /// Identifies the occurrence, as in [Occurrence.originalStart].
  final DateTime originalStart;

  /// When the occurrence starts, after any move. UTC.
  final DateTime start;

  /// When to remind. UTC.
  final DateTime fireAt;

  final EventReminder reminder;

  const DueReminder({
    required this.event,
    required this.originalStart,
    required this.start,
    required this.fireAt,
    required this.reminder,
  });

  /// The same for the same occurrence and lead every time it's planned: the
  /// dedupe key of spec §8, so planning twice never schedules twice.
  String get key =>
      '${event.id}|${originalStart.toUtc().toIso8601String()}|'
      '${reminder.minutesBefore}|${reminder.target.name}';
}

class ReminderPlanner {
  final RecurrenceExpander _expander;

  const ReminderPlanner([this._expander = const RecurrenceExpander()]);

  /// Reminders [memberId] is owed that fire in [from, until), in firing
  /// order. Cancelled events and cancelled occurrences owe nothing.
  List<DueReminder> plan({
    required List<CalendarEvent> events,
    required String memberId,
    required DateTime from,
    required DateTime until,
  }) {
    final due = <DueReminder>[];
    for (final event in events) {
      if (event.isCancelled || event.reminders.isEmpty) continue;
      final longest = event.reminders
          .map((r) => r.minutesBefore)
          .reduce((a, b) => a > b ? a : b);
      // Occurrences whose reminders can fire in the window start up to the
      // longest lead after it.
      final occurrences = _expander.expand(
        event.series,
        from,
        until.add(Duration(minutes: longest)),
      );
      for (final occurrence in occurrences) {
        final shown = event.forOccurrence(occurrence);
        for (final reminder in event.reminders) {
          final fireAt = occurrence.start.subtract(
            Duration(minutes: reminder.minutesBefore),
          );
          if (fireAt.isBefore(from) || !fireAt.isBefore(until)) continue;
          if (!_reaches(reminder.target, shown, memberId)) continue;
          due.add(DueReminder(
            event: shown,
            originalStart: occurrence.originalStart,
            start: occurrence.start,
            fireAt: fireAt,
            reminder: reminder,
          ));
        }
      }
    }
    return due..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  }

  static bool _reaches(
    ReminderTarget target,
    CalendarEvent event,
    String memberId,
  ) =>
      switch (target) {
        ReminderTarget.allFamily => true,
        ReminderTarget.responsible => event.responsibleMemberId == memberId,
        ReminderTarget.participants => event.participantIds.isEmpty ||
            event.participantIds.contains(memberId) ||
            event.responsibleMemberId == memberId,
      };
}
