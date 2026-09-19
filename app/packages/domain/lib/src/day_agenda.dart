import 'package:timezone/timezone.dart' as tz;

import 'absence.dart';
import 'calendar_event.dart';
import 'family.dart';
import 'recurrence.dart';

/// One occurrence of an event, with the event it came from. The client-side
/// occurrence projection of spec §5, reduced to what the day view needs.
class AgendaEntry {
  final CalendarEvent event;
  final Occurrence occurrence;

  const AgendaEntry(this.event, this.occurrence);

  DateTime get start => occurrence.start;
  DateTime get end => occurrence.end;

  bool overlaps(AgendaEntry other) =>
      start.isBefore(other.end) && other.start.isBefore(end);
}

/// The same responsible adult booked for two overlapping events.
class Conflict {
  final String memberId;
  final AgendaEntry first;
  final AgendaEntry second;

  const Conflict(this.memberId, this.first, this.second);
}

class DayAgenda {
  /// Events other than routines, by start time. Cancelled events stay in so
  /// the UI can show them struck through rather than silently vanished.
  final List<AgendaEntry> entries;

  /// Routine blocks, rendered as background bands rather than cards (§5).
  final List<AgendaEntry> routines;

  /// Upcoming events involving a child with no responsible adult.
  final List<AgendaEntry> unassigned;

  /// Double-bookings whose overlap hasn't ended yet.
  final List<Conflict> conflicts;

  /// The first event that hasn't started yet.
  final AgendaEntry? nextUp;

  /// Absences covering the day, shown as a band: what they suspend isn't in
  /// the lists above.
  final List<Absence> away;

  const DayAgenda({
    this.away = const [],
    required this.entries,
    required this.routines,
    required this.unassigned,
    required this.conflicts,
    required this.nextUp,
  });
}

class DayAgendaBuilder {
  final RecurrenceExpander _expander;

  const DayAgendaBuilder([this._expander = const RecurrenceExpander()]);

  /// Builds the agenda for the calendar date of [day] in [timeZone].
  ///
  /// [now] is a UTC instant; it decides what counts as upcoming.
  DayAgenda build({
    required List<CalendarEvent> events,
    required List<Member> members,
    required DateTime day,
    required String timeZone,
    required DateTime now,
    List<Absence> absences = const [],
  }) {
    final location = tz.getLocation(timeZone);
    // Bounded in the family's zone, so a DST day is 23 or 25 hours long.
    final windowStart =
        tz.TZDateTime(location, day.year, day.month, day.day).toUtc();
    final windowEnd =
        tz.TZDateTime(location, day.year, day.month, day.day + 1).toUtc();

    final all = [
      for (final event in events)
        for (final occurrence
            in _expander.expand(event.series, windowStart, windowEnd))
          if (!absences.any((a) => a.suspends(event, occurrence)))
            AgendaEntry(event.forOccurrence(occurrence), occurrence),
    ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.event.title.compareTo(b.event.title);
      });

    final entries = [
      for (final e in all)
        if (!e.event.isRoutine) e
    ];
    final active = [
      for (final e in entries)
        if (!e.event.isCancelled) e
    ];

    final memberIds = {for (final m in members) m.id};
    final children = {
      for (final m in members)
        if (m.isChild) m.id
    };

    return DayAgenda(
      away: [
        for (final a in absences)
          if (a.coversDay(day)) a,
      ],
      entries: entries,
      routines: [
        for (final e in all)
          if (e.event.isRoutine) e
      ],
      unassigned: [
        for (final e in active)
          // Someone who has left the family is no one (spec §9: their
          // events are flagged unassigned and escalated).
          if (!memberIds.contains(e.event.responsibleMemberId) &&
              e.event.participantIds.any(children.contains) &&
              e.end.isAfter(now))
            e,
      ],
      conflicts: _conflicts(active, now),
      nextUp: active.where((e) => !e.start.isBefore(now)).firstOrNull,
    );
  }

  /// Only conflicts whose overlap is still ahead: one that has played out is
  /// no longer something anyone can act on.
  List<Conflict> _conflicts(List<AgendaEntry> active, DateTime now) {
    final conflicts = <Conflict>[];
    for (var i = 0; i < active.length; i++) {
      final a = active[i];
      final responsible = a.event.responsibleMemberId;
      if (responsible == null) continue;
      for (var j = i + 1; j < active.length; j++) {
        final b = active[j];
        final overlapEnd = a.end.isBefore(b.end) ? a.end : b.end;
        if (b.event.responsibleMemberId == responsible &&
            a.overlaps(b) &&
            overlapEnd.isAfter(now)) {
          conflicts.add(Conflict(responsible, a, b));
        }
      }
    }
    return conflicts;
  }
}
