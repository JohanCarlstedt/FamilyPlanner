import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const zone = 'Europe/Stockholm';

  CalendarEvent event(
    String title, {
    List<String> participants = const [],
    String? responsible,
    EventKind kind = EventKind.activity,
    DateTime? start,
    RecurrenceRule? rule,
  }) =>
      CalendarEvent(
        series: EventSeries(
          eventId: title,
          localStart: start ?? DateTime.utc(2026, 9, 17, 17),
          duration: const Duration(hours: 1),
          timeZone: zone,
          rule: rule,
        ),
        title: title,
        kind: kind,
        participantIds: participants,
        responsibleMemberId: responsible,
      );

  group('family scope', () {
    final football =
        event('football', participants: ['maja'], responsible: 'anna');
    final piano = event('piano', participants: ['leo'], responsible: 'erik');
    final dinner = event('dinner', kind: EventKind.routine);
    final events = [football, piano, dinner];

    List<String> shown(CalendarFilter f) => [
          for (final e in events)
            if (f.matches(e)) e.title
        ];

    test('everyone by default', () {
      expect(shown(const CalendarFilter.family()),
          ['football', 'piano', 'dinner']);
    });

    test('filtering to a child shows their events and family-wide ones', () {
      expect(
        shown(const CalendarFilter.family(members: {'maja'})),
        ['football', 'dinner'],
      );
    });

    test('filtering to a parent includes what they drive, by default', () {
      expect(
        shown(const CalendarFilter.family(members: {'anna'})),
        ['football', 'dinner'],
      );
    });

    test('responsible-for can be switched off', () {
      expect(
        shown(const CalendarFilter.family(
          members: {'anna'},
          includeResponsibleFor: false,
        )),
        ['dinner'],
      );
    });

    test('routines can be hidden to declutter', () {
      expect(
        shown(const CalendarFilter.family(showRoutines: false)),
        ['football', 'piano'],
      );
    });
  });

  group('mine scope', () {
    test('my events, what I drive, and family-wide events and routines', () {
      final events = [
        event('my football', participants: ['maja']),
        event('sibling piano', participants: ['leo']),
        event('dinner', kind: EventKind.routine),
        event('my bedtime', kind: EventKind.routine, participants: ['maja']),
        event('sibling bedtime',
            kind: EventKind.routine, participants: ['leo']),
        event('school trip'),
        event('I drive', participants: ['leo'], responsible: 'maja'),
      ];
      const mine = CalendarFilter.mine('maja');

      expect(
        [
          for (final e in events)
            if (mine.matches(e)) e.title
        ],
        ['my football', 'dinner', 'my bedtime', 'school trip', 'I drive'],
      );
    });
  });

  group('ISO weeks', () {
    test('start on Monday', () {
      expect(isoWeekStart(DateTime(2026, 9, 17)), DateTime(2026, 9, 14));
      expect(isoWeekStart(DateTime(2026, 9, 14)), DateTime(2026, 9, 14));
      expect(isoWeekStart(DateTime(2026, 9, 20)), DateTime(2026, 9, 14),
          reason: 'Sunday closes the week');
    });

    test('cross months and years', () {
      expect(isoWeekStart(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });
  });

  group('week agenda', () {
    const builder = WeekAgendaBuilder();
    const members = [
      Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent),
      Member(id: 'maja', displayName: 'Maja', role: MemberRole.child),
      Member(id: 'leo', displayName: 'Leo', role: MemberRole.child),
    ];

    test('seven days, Monday first, recurring events on their day', () {
      final week = builder.build(
        events: [
          event(
            'training',
            participants: ['maja'],
            responsible: 'anna',
            start: DateTime.utc(2026, 9, 3, 17, 30), // a Thursday
            rule: const RecurrenceRule(
              frequency: Frequency.weekly,
              byWeekday: {Weekday.th},
            ),
          ),
        ],
        members: members,
        date: DateTime(2026, 9, 18),
        timeZone: zone,
        now: DateTime.utc(2026, 9, 14, 6),
      );

      expect(week.start, DateTime(2026, 9, 14));
      expect(week.days, hasLength(7));
      expect(week.number, 38);
      final counts = [for (final d in week.days) d.entries.length];
      expect(counts, [0, 0, 0, 1, 0, 0, 0]);
    });

    test('warnings follow the filter, so the summary matches the list', () {
      final events = [
        event('maja football', participants: ['maja']), // no one responsible
        event('leo piano', participants: ['leo']), // no one responsible
      ];
      final all = builder.build(
        events: events,
        members: members,
        date: DateTime(2026, 9, 17),
        timeZone: zone,
        now: DateTime.utc(2026, 9, 14, 6),
      );
      final onlyMaja = builder.build(
        events: events,
        members: members,
        date: DateTime(2026, 9, 17),
        timeZone: zone,
        now: DateTime.utc(2026, 9, 14, 6),
        filter: const CalendarFilter.family(members: {'maja'}),
      );

      expect(all.unassigned, hasLength(2));
      expect(onlyMaja.unassigned.map((e) => e.event.title), ['maja football']);
    });
  });
}
