import 'day_agenda.dart';

/// The day in one line: what the morning notification says, and what the
/// dashboard then shows for the rest of the day.
///
/// Counts, not sentences — the wording is the UI layer's, in whichever
/// language the phone is in. What this decides is the harder half: which
/// things count as the day having something in it.
class DaySummary {
  const DaySummary({
    required this.events,
    required this.nextStart,
    required this.unassigned,
    required this.conflicts,
    required this.todos,
    required this.awayMemberIds,
    required this.wholeFamilyAway,
  });

  /// Things happening today. Routines are left out — a number that counts
  /// breakfast and bedtime is not one anyone acts on — and so are
  /// cancellations, which are shown struck through on the timeline but are
  /// not things that are on.
  final int events;

  /// When the next one starts, or null if none is still to come. Not the
  /// day's first: read at six in the evening, "first at 08:00" is about a
  /// morning that has been and gone.
  final DateTime? nextStart;

  /// A child's event with no responsible adult: the one thing here that is
  /// a question rather than information.
  final int unassigned;
  final int conflicts;
  final int todos;

  /// Who is away today, in the order the absences name them, each once.
  /// Empty when nobody is — or when the absence covers everybody, which
  /// [wholeFamilyAway] says instead.
  final List<String> awayMemberIds;
  final bool wholeFamilyAway;

  /// Nothing to tell anyone about. Said plainly rather than shown as a
  /// row of zeroes.
  bool get isQuiet =>
      events == 0 && todos == 0 && awayMemberIds.isEmpty && !wholeFamilyAway;

  /// Something wants a person, not just their attention.
  bool get needsAttention => unassigned > 0 || conflicts > 0;
}

/// Reduces a built day to what the summary says about it.
DaySummary summariseDay({
  required DayAgenda agenda,
  required int todos,
  required DateTime now,
}) {
  final on = [
    for (final e in agenda.entries)
      if (!e.event.isCancelled && !e.event.isRoutine) e,
  ];
  final away = <String>[];
  var everyone = false;
  for (final a in agenda.away) {
    if (a.memberIds.isEmpty) {
      everyone = true;
      continue;
    }
    for (final id in a.memberIds) {
      if (!away.contains(id)) away.add(id);
    }
  }
  return DaySummary(
    events: on.length,
    nextStart:
        on.where((e) => e.start.isAfter(now)).map((e) => e.start).firstOrNull,
    unassigned: agenda.unassigned.length,
    conflicts: agenda.conflicts.length,
    todos: todos,
    awayMemberIds: away,
    wholeFamilyAway: everyone,
  );
}
