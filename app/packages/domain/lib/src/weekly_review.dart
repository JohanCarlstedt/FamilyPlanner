import 'calendar_event.dart';
import 'day_agenda.dart';
import 'family.dart';
import 'week_number.dart';

/// Spec §10 "The weekly review": the week ahead as the family sits down to
/// it, built only from what's already there.
class WeeklyReview {
  const WeeklyReview({
    required this.weekStart,
    required this.days,
    required this.unassigned,
    required this.conflicts,
    required this.drives,
  });

  /// The Monday, as `DateTime.utc` date fields.
  final DateTime weekStart;

  /// Monday to Sunday.
  final List<DayAgenda> days;

  /// Children's events with no one responsible.
  final List<AgendaEntry> unassigned;

  /// One adult responsible for two things at once.
  final List<Conflict> conflicts;

  /// How many events each member is responsible for.
  final Map<String, int> drives;

  int get weekNumber => isoWeekNumber(weekStart);

  int get eventCount => days.fold(
        0,
        (n, d) => n + d.entries.where((e) => !e.event.isCancelled).length,
      );

  /// What someone has to decide before the week starts.
  int get needsAttention => unassigned.length + conflicts.length;
}

class WeeklyReviewBuilder {
  const WeeklyReviewBuilder([this._days = const DayAgendaBuilder()]);

  final DayAgendaBuilder _days;

  /// The week to review from [today] (a local date): from Friday on, the
  /// week ahead; earlier, the one under way.
  WeeklyReview build({
    required List<CalendarEvent> events,
    required List<Member> members,
    required DateTime today,
    required String timeZone,
    required DateTime now,
  }) {
    final date = DateTime.utc(today.year, today.month, today.day);
    final monday = date.weekday >= DateTime.friday
        ? date.add(Duration(days: 8 - date.weekday))
        : date.subtract(Duration(days: date.weekday - 1));
    final days = [
      for (var i = 0; i < 7; i++)
        _days.build(
          events: events,
          members: members,
          day: DateTime.utc(monday.year, monday.month, monday.day + i),
          timeZone: timeZone,
          now: now,
        ),
    ];
    final drives = <String, int>{};
    for (final d in days) {
      for (final e in d.entries) {
        if (e.event.isCancelled) continue;
        if (e.event.responsibleMemberId case final who?) {
          drives[who] = (drives[who] ?? 0) + 1;
        }
      }
    }
    return WeeklyReview(
      weekStart: monday,
      days: days,
      unassigned: [for (final d in days) ...d.unassigned],
      conflicts: [for (final d in days) ...d.conflicts],
      drives: drives,
    );
  }
}
