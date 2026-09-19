import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  const zone = 'Europe/Stockholm';
  const builder = DayAgendaBuilder();

  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const erik = Member(id: 'erik', displayName: 'Erik', role: MemberRole.parent);
  const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);
  const members = [anna, erik, maja];

  // Thursday 17 September 2026. Stockholm is UTC+2 (summer time).
  final day = DateTime(2026, 9, 17);

  CalendarEvent event(
    String id, {
    required DateTime localStart,
    Duration duration = const Duration(hours: 1),
    EventKind kind = EventKind.appointment,
    List<String> participants = const ['maja'],
    String? responsible = 'anna',
    EventStatus status = EventStatus.confirmed,
    RecurrenceRule? rule,
    List<ExceptionEntry> exceptions = const [],
  }) {
    return CalendarEvent(
      series: EventSeries(
        eventId: id,
        localStart: localStart,
        duration: duration,
        timeZone: zone,
        rule: rule,
        exceptions: exceptions,
      ),
      title: id,
      kind: kind,
      status: status,
      participantIds: participants,
      responsibleMemberId: responsible,
    );
  }

  DayAgenda build(List<CalendarEvent> events, {DateTime? now}) {
    return builder.build(
      events: events,
      members: members,
      day: day,
      timeZone: zone,
      now: now ?? DateTime.utc(2026, 9, 17, 4), // 06:00 local
    );
  }

  group('window', () {
    test('includes only occurrences on the local day, sorted by start', () {
      final agenda = build([
        event('late', localStart: DateTime(2026, 9, 17, 19)),
        event('early', localStart: DateTime(2026, 9, 17, 8)),
        event('yesterday', localStart: DateTime(2026, 9, 16, 19)),
        event('tomorrow', localStart: DateTime(2026, 9, 18, 8)),
      ]);

      expect(agenda.entries.map((e) => e.event.title), ['early', 'late']);
    });

    test('the local day is bounded in the family zone, not UTC', () {
      // 00:30 local on the 17th is 22:30 UTC on the 16th. It belongs to the
      // 17th; 23:30 local on the 16th does not.
      final agenda = build([
        event('just after midnight', localStart: DateTime(2026, 9, 17, 0, 30)),
        event('just before midnight',
            localStart: DateTime(2026, 9, 16, 23, 30),
            duration: const Duration(minutes: 20)),
      ]);

      expect(agenda.entries.map((e) => e.event.title), ['just after midnight']);
    });

    test('expands recurring series through the recurrence engine', () {
      final agenda = build([
        event(
          'training',
          localStart:
              DateTime(2026, 9, 3, 17, 30), // a Thursday, two weeks back
          kind: EventKind.activity,
          rule: const RecurrenceRule(
            frequency: Frequency.weekly,
            byWeekday: {Weekday.th},
          ),
        ),
      ]);

      expect(agenda.entries, hasLength(1));
      expect(agenda.entries.single.occurrence.start,
          DateTime.utc(2026, 9, 17, 15, 30));
    });
  });

  group('routines', () {
    test('render separately from events and never raise warnings', () {
      final agenda = build([
        event('dinner',
            localStart: DateTime(2026, 9, 17, 18),
            kind: EventKind.routine,
            participants: ['anna', 'erik', 'maja'],
            responsible: null),
        event('dentist', localStart: DateTime(2026, 9, 17, 10)),
      ]);

      expect(agenda.routines.map((e) => e.event.title), ['dinner']);
      expect(agenda.entries.map((e) => e.event.title), ['dentist']);
      expect(agenda.unassigned, isEmpty);
    });
  });

  group('unassigned responsibility', () {
    test('flags an event involving a child with no responsible adult', () {
      final agenda = build([
        event('football',
            localStart: DateTime(2026, 9, 17, 17), responsible: null),
      ]);

      expect(agenda.unassigned.map((e) => e.event.title), ['football']);
    });

    test('ignores adults-only events without a responsible member', () {
      final agenda = build([
        event('date night',
            localStart: DateTime(2026, 9, 17, 20),
            participants: ['anna', 'erik'],
            responsible: null),
      ]);

      expect(agenda.unassigned, isEmpty);
    });

    test('ignores events that have already ended', () {
      final agenda = build(
        [
          event('school run',
              localStart: DateTime(2026, 9, 17, 8), responsible: null)
        ],
        now: DateTime.utc(2026, 9, 17, 10), // 12:00 local
      );

      expect(agenda.unassigned, isEmpty);
    });

    test('ignores cancelled events', () {
      final agenda = build([
        event('football',
            localStart: DateTime(2026, 9, 17, 17),
            responsible: null,
            status: EventStatus.cancelled),
      ]);

      expect(agenda.unassigned, isEmpty);
    });
  });

  group('conflicts', () {
    test('flags overlapping events with the same responsible adult', () {
      final agenda = build([
        event('swimming', localStart: DateTime(2026, 9, 17, 17, 30)),
        event('parents evening',
            localStart: DateTime(2026, 9, 17, 18), participants: ['anna']),
      ]);

      expect(agenda.conflicts, hasLength(1));
      final conflict = agenda.conflicts.single;
      expect(conflict.memberId, 'anna');
      expect([conflict.first.event.title, conflict.second.event.title],
          ['swimming', 'parents evening']);
    });

    test('back-to-back events do not conflict', () {
      final agenda = build([
        event('swimming', localStart: DateTime(2026, 9, 17, 17)),
        event('piano', localStart: DateTime(2026, 9, 17, 18)),
      ]);

      expect(agenda.conflicts, isEmpty);
    });

    test('different responsible adults do not conflict', () {
      final agenda = build([
        event('swimming', localStart: DateTime(2026, 9, 17, 17)),
        event('football',
            localStart: DateTime(2026, 9, 17, 17), responsible: 'erik'),
      ]);

      expect(agenda.conflicts, isEmpty);
    });

    test('a conflict whose overlap is over is no longer reported', () {
      final agenda = build(
        [
          event('swimming', localStart: DateTime(2026, 9, 17, 17, 30)),
          event(
            'parents evening',
            localStart: DateTime(2026, 9, 17, 18),
            participants: ['anna'],
          ),
        ],
        now: DateTime.utc(2026, 9, 17, 16, 30), // 18:30 local, overlap ended
      );

      expect(agenda.conflicts, isEmpty);
    });

    test('cancelled events do not conflict', () {
      final agenda = build([
        event('swimming', localStart: DateTime(2026, 9, 17, 17)),
        event('piano',
            localStart: DateTime(2026, 9, 17, 17),
            status: EventStatus.cancelled),
      ]);

      expect(agenda.conflicts, isEmpty);
    });
  });

  group('next up', () {
    test('is the first event that has not started yet', () {
      final agenda = build(
        [
          event('dentist', localStart: DateTime(2026, 9, 17, 10)),
          event('football', localStart: DateTime(2026, 9, 17, 17)),
        ],
        now: DateTime.utc(2026, 9, 17, 9), // 11:00 local, dentist in progress
      );

      expect(agenda.nextUp?.event.title, 'football');
    });

    test('skips cancelled events and routines', () {
      final agenda = build([
        event('breakfast',
            localStart: DateTime(2026, 9, 17, 7), kind: EventKind.routine),
        event('dentist',
            localStart: DateTime(2026, 9, 17, 10),
            status: EventStatus.cancelled),
        event('football', localStart: DateTime(2026, 9, 17, 17)),
      ]);

      expect(agenda.nextUp?.event.title, 'football');
    });

    test('is null once the day is done', () {
      final agenda = build(
        [event('dentist', localStart: DateTime(2026, 9, 17, 10))],
        now: DateTime.utc(2026, 9, 17, 20),
      );

      expect(agenda.nextUp, isNull);
    });
  });

  group('ISO week number', () {
    // Swedish calendars number weeks by ISO 8601: Monday start, and week 1 is
    // the week containing the year's first Thursday.
    test('mid-year', () => expect(isoWeekNumber(DateTime(2026, 9, 17)), 38));

    test('1 January on a Thursday is week 1',
        () => expect(isoWeekNumber(DateTime(2026, 1, 1)), 1));

    test('1 January on a Friday belongs to the previous year\'s week 53',
        () => expect(isoWeekNumber(DateTime(2027, 1, 1)), 53));

    test('29 December on a Monday is week 1 of the next year',
        () => expect(isoWeekNumber(DateTime(2025, 12, 29)), 1));

    test('Sunday closes the week, it does not open the next',
        () => expect(isoWeekNumber(DateTime(2026, 9, 20)), 38));
  });

  group('occurrence exceptions', () {
    // Weekly on Thursdays from 3 September, 17:30 local (15:30 UTC).
    const weekly = RecurrenceRule(
      frequency: Frequency.weekly,
      byWeekday: {Weekday.th},
    );
    final thisThursday = DateTime.utc(2026, 9, 17, 15, 30);

    test('a title override shows for that occurrence only', () {
      final agenda = build([
        event(
          'Training',
          localStart: DateTime.utc(2026, 9, 3, 17, 30),
          rule: weekly,
          exceptions: [
            ExceptionEntry(
              originalStart: thisThursday,
              type: ExceptionType.modified,
              overrideTitle: 'Away match',
            ),
          ],
        ),
      ]);

      expect(agenda.entries.single.event.title, 'Away match');
      expect(agenda.entries.single.event.id, 'Training',
          reason: 'still the same series');
    });

    test('a responsible override counts for warnings and conflicts', () {
      final agenda = build([
        event(
          'Training',
          localStart: DateTime.utc(2026, 9, 3, 17, 30),
          rule: weekly,
          responsible: null,
          exceptions: [
            ExceptionEntry(
              originalStart: thisThursday,
              type: ExceptionType.modified,
              overrideResponsibleMemberId: 'erik',
            ),
          ],
        ),
        event(
          'Dinner',
          localStart: DateTime.utc(2026, 9, 17, 17, 45),
          participants: const ['erik'],
          responsible: 'erik',
        ),
      ]);

      expect(agenda.unassigned, isEmpty,
          reason: 'Erik drives this week, so it is covered');
      expect(agenda.conflicts.single.memberId, 'erik');
    });

    test('a moved occurrence lands on its new day', () {
      final events = [
        event(
          'Training',
          localStart: DateTime.utc(2026, 9, 3, 17, 30),
          rule: weekly,
          exceptions: [
            ExceptionEntry(
              originalStart: DateTime.utc(2026, 9, 10, 15, 30),
              type: ExceptionType.moved,
              // Wednesday 16 September, 18:00 local.
              overrideStart: DateTime.utc(2026, 9, 16, 16),
            ),
          ],
        ),
      ];

      final wednesday = builder.build(
        events: events,
        members: members,
        day: DateTime(2026, 9, 16),
        timeZone: zone,
        now: DateTime.utc(2026, 9, 16, 4),
      );

      expect(wednesday.entries.single.start, DateTime.utc(2026, 9, 16, 16));
    });

    test('an occurrence moved earlier shows before its original date', () {
      final agenda = build([
        event(
          'Training',
          localStart: DateTime.utc(2026, 9, 3, 17, 30),
          rule: weekly,
          exceptions: [
            ExceptionEntry(
              // Next week's training, pulled forward to today at 19:00.
              originalStart: DateTime.utc(2026, 9, 24, 15, 30),
              type: ExceptionType.moved,
              overrideStart: DateTime.utc(2026, 9, 17, 17),
            ),
          ],
        ),
      ]);

      expect(
        agenda.entries.map((e) => e.start),
        [thisThursday, DateTime.utc(2026, 9, 17, 17)],
      );
    });
  });

  test('copies of an event keep every field', () {
    const reminders = [EventReminder(minutesBefore: 30)];
    final original = CalendarEvent(
      series: EventSeries(
        eventId: 'e',
        localStart: DateTime.utc(2026, 9, 3, 17, 30),
        duration: const Duration(hours: 1),
        timeZone: zone,
        rule: const RecurrenceRule(frequency: Frequency.weekly),
      ),
      title: 'Training',
      kind: EventKind.activity,
      status: EventStatus.tentative,
      participantIds: const ['maja'],
      responsibleMemberId: 'anna',
      location: 'Sportshallen',
      placeId: 'hall',
      reminders: reminders,
    );
    final occurrence = Occurrence(
      eventId: 'e',
      originalStart: DateTime.utc(2026, 9, 3, 15, 30),
      start: DateTime.utc(2026, 9, 3, 15, 30),
      end: DateTime.utc(2026, 9, 3, 16, 30),
      exception: ExceptionEntry(
        originalStart: DateTime.utc(2026, 9, 3, 15, 30),
        type: ExceptionType.modified,
        overrideTitle: 'Away match',
      ),
    );

    for (final copy in [
      original.withExceptions(const []),
      original.forOccurrence(occurrence),
    ]) {
      expect(copy.kind, original.kind);
      expect(copy.status, original.status);
      expect(copy.participantIds, original.participantIds);
      expect(copy.responsibleMemberId, original.responsibleMemberId);
      expect(copy.location, original.location);
      expect(copy.placeId, original.placeId);
      expect(copy.reminders, same(reminders));
    }
  });

  test('a responsible adult who has left counts as no one', () {
    final agenda = build([
      event('Swimming',
          localStart: DateTime(2026, 9, 17, 16), responsible: 'gone'),
    ]);
    expect(agenda.unassigned.single.event.title, 'Swimming');
  });
}
