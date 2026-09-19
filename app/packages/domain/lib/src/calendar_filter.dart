import 'absence.dart';
import 'calendar_event.dart';
import 'day_agenda.dart';
import 'family.dart';
import 'week_number.dart';

/// Which events a calendar view shows: spec §5 "Filtering" and "Scope".
///
/// Applied before any agenda is built, so conflict badges and the
/// unassigned-responsibility warning describe what is on screen (§5 "Filter at
/// the data layer, not the render layer").
class CalendarFilter {
  /// The household view. [members] empty means everyone.
  const CalendarFilter.family({
    this.members = const {},
    this.includeResponsibleFor = true,
    this.showRoutines = true,
  }) : mineOf = null;

  /// One member's own view. Never empty: family-wide events and routines, and
  /// whatever the member is responsible for, are theirs too.
  const CalendarFilter.mine(String memberId, {this.showRoutines = true})
      : mineOf = memberId,
        members = const {},
        includeResponsibleFor = true;

  /// Set for the `mine` scope.
  final String? mineOf;

  /// Members to show in the family scope; empty is everyone.
  final Set<String> members;

  /// Also show events a visible member is responsible for but not attending:
  /// filtering to yourself must not hide the pickups you're doing. On by default.
  final bool includeResponsibleFor;

  final bool showRoutines;

  bool matches(CalendarEvent event) {
    if (event.isRoutine && !showRoutines) return false;

    final visible = mineOf == null ? members : {mineOf!};
    if (visible.isEmpty) return true;

    // Family-wide: no participants means everyone, in any scope.
    if (event.participantIds.isEmpty) return true;
    if (event.participantIds.any(visible.contains)) return true;
    return includeResponsibleFor &&
        event.responsibleMemberId != null &&
        visible.contains(event.responsibleMemberId);
  }
}

/// The Monday starting the ISO week that contains [date] (calendar date only).
DateTime isoWeekStart(DateTime date) => DateTime(
    date.year, date.month, date.day - (date.weekday - DateTime.monday));

/// Seven day agendas, Monday first, plus the week's warnings.
class WeekAgenda {
  const WeekAgenda({required this.start, required this.days});

  /// The Monday this week starts on.
  final DateTime start;

  /// Monday to Sunday.
  final List<DayAgenda> days;

  int get number => isoWeekNumber(start);

  List<AgendaEntry> get unassigned => [for (final d in days) ...d.unassigned];

  List<Conflict> get conflicts => [for (final d in days) ...d.conflicts];
}

class WeekAgendaBuilder {
  const WeekAgendaBuilder([this._day = const DayAgendaBuilder()]);

  final DayAgendaBuilder _day;

  /// The week containing [date], in [timeZone], through [filter].
  WeekAgenda build({
    required List<CalendarEvent> events,
    required List<Member> members,
    required DateTime date,
    required String timeZone,
    required DateTime now,
    CalendarFilter filter = const CalendarFilter.family(),
    List<Absence> absences = const [],
  }) {
    final start = isoWeekStart(date);
    final shown = [
      for (final e in events)
        if (filter.matches(e)) e
    ];
    return WeekAgenda(
      start: start,
      days: [
        for (var i = 0; i < 7; i++)
          _day.build(
            events: shown,
            members: members,
            day: DateTime(start.year, start.month, start.day + i),
            timeZone: timeZone,
            now: now,
            absences: absences,
          ),
      ],
    );
  }
}
