import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);
  const family = [anna, maja];

  CalendarEvent weekly(String id, EventKind kind, List<String> going,
          {String? driver}) =>
      CalendarEvent(
        series: EventSeries(
          eventId: id,
          localStart: DateTime.utc(2026, 10, 1, 17),
          duration: const Duration(hours: 1),
          timeZone: zone,
          rule: const RecurrenceRule(frequency: Frequency.daily),
        ),
        title: id,
        kind: kind,
        participantIds: going,
        responsibleMemberId: driver,
      );

  // Höstlov, week 44: Maja's school routine and activities pause.
  final hostlov = Absence(
    id: 'lov',
    title: 'Höstlov',
    memberIds: const {'maja'},
    startsOn: DateTime.utc(2026, 10, 26),
    endsOn: DateTime.utc(2026, 10, 30),
    suppressKinds: const {EventKind.routine, EventKind.activity},
  );

  test('an absence suspends what it covers, only in its range', () {
    final school = weekly('school', EventKind.routine, ['maja']);
    final gym = weekly('gym', EventKind.activity, ['anna']);
    DayAgenda day(DateTime d) => const DayAgendaBuilder().build(
          events: [school, gym],
          members: family,
          day: d,
          timeZone: zone,
          now: DateTime.utc(2026, 10, 1),
          absences: [hostlov],
        );
    final during = day(DateTime.utc(2026, 10, 27));
    expect(during.routines, isEmpty);
    expect(during.entries.map((e) => e.event.title), ['gym'],
        reason: 'Anna isn\'t on holiday');
    expect(during.away.single.title, 'Höstlov');
    final after = day(DateTime.utc(2026, 10, 31));
    expect(after.routines.map((e) => e.event.title), ['school']);
    expect(after.away, isEmpty);
  });

  test('suspended occurrences remind nobody, and aren\'t unassigned', () {
    final training = weekly('training', EventKind.activity, ['maja']);
    List<DueReminder> plan(List<Absence> absences) =>
        const ReminderPlanner().plan(
          events: [training],
          memberId: 'anna',
          from: DateTime.utc(2026, 10, 26),
          // Not into the 30th's afternoon, when the 31st, after the holiday,
          // rightly asks who's taking her.
          until: DateTime.utc(2026, 10, 30, 12),
          members: family,
          absences: absences,
        );
    expect(plan(const []), isNotEmpty);
    expect(plan([hostlov]), isEmpty);
  });

  test('a whole-family trip with reminders off silences everything', () {
    final trip = Absence(
      id: 'trip',
      title: 'Fjällen',
      startsOn: DateTime.utc(2026, 10, 26),
      endsOn: DateTime.utc(2026, 10, 27),
      suppressKinds: const {},
      suppressReminders: true,
    );
    final dentist = CalendarEvent(
      series: EventSeries(
        eventId: 'd',
        localStart: DateTime.utc(2026, 10, 27, 9),
        duration: const Duration(minutes: 30),
        timeZone: zone,
      ),
      title: 'Tandläkare',
      kind: EventKind.appointment,
      participantIds: const ['anna'],
      responsibleMemberId: 'anna',
    );
    expect(
      const ReminderPlanner()
          .plan(
            events: [dentist],
            memberId: 'anna',
            from: DateTime.utc(2026, 10, 20),
            until: DateTime.utc(2026, 10, 28),
            members: family,
            absences: [trip],
          )
          .where((r) => r.fireAt.isAfter(DateTime.utc(2026, 10, 25, 23))),
      isEmpty,
    );
  });
}
