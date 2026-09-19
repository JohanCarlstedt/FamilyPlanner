import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() => tzdata.initializeTimeZones());

  const zone = 'Europe/Stockholm';
  const planner = ReminderPlanner();

  // Thursdays 17:30 local (15:30 UTC in September), Maja going, Anna driving.
  CalendarEvent training({
    List<EventReminder> reminders = const [
      EventReminder(minutesBefore: 60),
    ],
    List<String> participants = const ['maja'],
    String? responsible = 'anna',
    EventStatus status = EventStatus.confirmed,
    List<ExceptionEntry> exceptions = const [],
  }) => CalendarEvent(
    series: EventSeries(
      eventId: 'training',
      localStart: DateTime.utc(2026, 9, 3, 17, 30),
      duration: const Duration(hours: 1),
      timeZone: zone,
      rule: const RecurrenceRule(
        frequency: Frequency.weekly,
        byWeekday: {Weekday.th},
      ),
      exceptions: exceptions,
    ),
    title: 'Training',
    kind: EventKind.activity,
    status: status,
    participantIds: participants,
    responsibleMemberId: responsible,
    reminders: reminders,
  );

  List<DueReminder> plan(
    List<CalendarEvent> events, {
    String member = 'maja',
    DateTime? from,
    DateTime? until,
  }) => [
    // These tests are about the event's own reminders; the defaults have
    // their own group below.
    for (final r in planner.plan(
      events: events,
      memberId: member,
      from: from ?? DateTime.utc(2026, 9, 14),
      until: until ?? DateTime.utc(2026, 9, 28),
    ))
      if (r.kind == ReminderKind.custom) r,
  ];

  test('one reminder per occurrence in the window, at its lead', () {
    final due = plan([training()]);

    expect(due.map((r) => r.fireAt), [
      DateTime.utc(2026, 9, 17, 14, 30),
      DateTime.utc(2026, 9, 24, 14, 30),
    ]);
    expect(due.first.originalStart, DateTime.utc(2026, 9, 17, 15, 30));
    expect(due.first.event.title, 'Training');
  });

  test('the window is on the firing time, not the occurrence', () {
    // A day-before reminder for Monday's occurrence fires inside the window
    // even though the occurrence itself is after it.
    final due = plan(
      [training(reminders: const [EventReminder(minutesBefore: 24 * 60)])],
      from: DateTime.utc(2026, 9, 16),
      until: DateTime.utc(2026, 9, 17),
    );
    expect(due.single.fireAt, DateTime.utc(2026, 9, 16, 15, 30));
  });

  test('reaches the people going and whoever drives', () {
    final events = [training()];
    expect(plan(events, member: 'maja'), hasLength(2));
    expect(plan(events, member: 'anna'), hasLength(2));
    expect(plan(events, member: 'erik'), isEmpty);
  });

  test('an event for the whole family reaches everyone', () {
    expect(plan([training(participants: const [])], member: 'erik'), hasLength(2));
  });

  test('targets narrow who is reminded', () {
    final driverOnly = training(
      reminders: const [
        EventReminder(minutesBefore: 10, target: ReminderTarget.responsible),
      ],
    );
    expect(plan([driverOnly], member: 'maja'), isEmpty);
    expect(plan([driverOnly], member: 'anna'), hasLength(2));

    final everyone = training(
      reminders: const [
        EventReminder(minutesBefore: 10, target: ReminderTarget.allFamily),
      ],
    );
    expect(plan([everyone], member: 'erik'), hasLength(2));
  });

  test('a driver swapped for one week moves that week\'s reminder', () {
    final events = [
      training(
        reminders: const [
          EventReminder(minutesBefore: 10, target: ReminderTarget.responsible),
        ],
        exceptions: [
          ExceptionEntry(
            originalStart: DateTime.utc(2026, 9, 24, 15, 30),
            type: ExceptionType.modified,
            overrideResponsibleMemberId: 'erik',
          ),
        ],
      ),
    ];
    expect(
      plan(events, member: 'anna').map((r) => r.originalStart),
      [DateTime.utc(2026, 9, 17, 15, 30)],
    );
    expect(
      plan(events, member: 'erik').map((r) => r.originalStart),
      [DateTime.utc(2026, 9, 24, 15, 30)],
    );
  });

  test('nothing for a cancelled occurrence or a cancelled event', () {
    // The case that must not fail: training cancelled on Thursday.
    final oneCancelled = training(
      exceptions: [
        ExceptionEntry(
          originalStart: DateTime.utc(2026, 9, 17, 15, 30),
          type: ExceptionType.cancelled,
        ),
      ],
    );
    expect(
      plan([oneCancelled]).map((r) => r.originalStart),
      [DateTime.utc(2026, 9, 24, 15, 30)],
    );
    expect(plan([training(status: EventStatus.cancelled)]), isEmpty);
  });

  test('a moved occurrence reminds before its new time', () {
    final due = plan([
      training(
        exceptions: [
          ExceptionEntry(
            originalStart: DateTime.utc(2026, 9, 17, 15, 30),
            type: ExceptionType.moved,
            overrideStart: DateTime.utc(2026, 9, 17, 16),
          ),
        ],
      ),
    ]);
    expect(due.first.fireAt, DateTime.utc(2026, 9, 17, 15));
    expect(due.first.start, DateTime.utc(2026, 9, 17, 16));
  });

  test('every reminder has a stable key per occurrence and lead', () {
    final twice = training(
      reminders: const [
        EventReminder(minutesBefore: 24 * 60),
        EventReminder(minutesBefore: 60),
      ],
    );
    final keys = [for (final r in plan([twice])) r.key];
    expect(keys.toSet(), hasLength(4));
    expect(
      [for (final r in plan([twice])) r.key],
      keys,
      reason: 'planning again gives the same keys',
    );
  });

  group('default rules (spec §8)', () {
    const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
    const erik = Member(id: 'erik', displayName: 'Erik', role: MemberRole.parent);
    const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);
    const family = [anna, erik, maja];
    const hall = Place(id: 'hall', name: 'Sportshallen', parkingBufferMinutes: 10);

    // Thursday 17 September, 17:30 local (15:30 UTC), at the sports hall.
    CalendarEvent event({
      EventKind kind = EventKind.activity,
      String? responsible = 'anna',
      List<String> participants = const ['maja'],
      DateTime? localStart,
    }) => CalendarEvent(
      series: EventSeries(
        eventId: 'e',
        localStart: localStart ?? DateTime.utc(2026, 9, 17, 17, 30),
        duration: const Duration(hours: 1),
        timeZone: zone,
      ),
      title: 'Training',
      kind: kind,
      participantIds: participants,
      responsibleMemberId: responsible,
      placeId: 'hall',
    );

    List<DueReminder> defaults(
      CalendarEvent e,
      String member, {
      FamilySettings settings = FamilySettings.defaults,
    }) => planner.plan(
      events: [e],
      memberId: member,
      from: DateTime.utc(2026, 9, 10),
      until: DateTime.utc(2026, 9, 20),
      members: family,
      settings: settings,
      places: const {'hall': hall},
    );

    Map<ReminderKind, DateTime> byKind(List<DueReminder> due) => {
      for (final r in due) r.kind: r.fireAt,
    };

    test('the driver of an activity: departure and the evening before', () {
      expect(byKind(defaults(event(), 'anna')), {
        // 17:30 less 30 min travel, 10 parking, 10 getting ready: 16:40.
        ReminderKind.departure: DateTime.utc(2026, 9, 17, 14, 40),
        // 20:00 the day before.
        ReminderKind.prep: DateTime.utc(2026, 9, 16, 18),
      });
    });

    test('the child going: a prep reminder an hour before', () {
      expect(byKind(defaults(event(), 'maja')), {
        ReminderKind.prep: DateTime.utc(2026, 9, 17, 14, 30),
      });
    });

    test('a parent not involved hears nothing', () {
      expect(defaults(event(), 'erik'), isEmpty);
    });

    test('an appointment: 18:00 the day before, and departure for the driver', () {
      expect(byKind(defaults(event(kind: EventKind.appointment), 'anna')), {
        ReminderKind.dayBefore: DateTime.utc(2026, 9, 16, 16),
        ReminderKind.departure: DateTime.utc(2026, 9, 17, 14, 40),
      });
      expect(
        byKind(defaults(event(kind: EventKind.appointment), 'maja')).keys,
        [ReminderKind.dayBefore],
      );
    });

    test('routines stay silent', () {
      expect(defaults(event(kind: EventKind.routine), 'anna'), isEmpty);
    });

    test('a child\'s event with no one responsible pings every parent', () {
      final unassigned = event(responsible: null);
      for (final parent in ['anna', 'erik']) {
        expect(byKind(defaults(unassigned, parent)), {
          ReminderKind.unassigned: DateTime.utc(2026, 9, 16, 15, 30),
        });
      }
      expect(
        defaults(unassigned, 'maja').map((r) => r.kind),
        isNot(contains(ReminderKind.unassigned)),
      );
    });

    test('quiet hours move a prep reminder to the evening before', () {
      // 06:30 football: the child's prep at 05:30 is inside quiet hours.
      final early = event(localStart: DateTime.utc(2026, 9, 17, 6, 30));
      final prep = defaults(early, 'maja').single;
      expect(prep.kind, ReminderKind.prep);
      // 20:45 on the 16th, a quarter before quiet hours begin.
      expect(prep.fireAt, DateTime.utc(2026, 9, 16, 18, 45));
      expect(prep.silent, isFalse);
    });

    test('a departure inside quiet hours keeps its time, silently', () {
      // 06:30 football: leave at 05:40. Earlier is safe; later is useless.
      final early = event(localStart: DateTime.utc(2026, 9, 17, 6, 30));
      final departure = defaults(early, 'anna')
          .firstWhere((r) => r.kind == ReminderKind.departure);
      expect(departure.fireAt, DateTime.utc(2026, 9, 17, 3, 40));
      expect(departure.silent, isTrue);
    });
  });

  test('a child without a device: their reminders reach the driver', () {
    const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
    const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);
    final swim = CalendarEvent(
      series: EventSeries(
        eventId: 'swim',
        localStart: DateTime.utc(2026, 9, 17, 16),
        duration: const Duration(hours: 1),
        timeZone: zone,
      ),
      title: 'Swimming',
      kind: EventKind.activity,
      participantIds: const ['maja'],
      responsibleMemberId: 'anna',
    );
    List<DueReminder> forAnna(Set<String> withDevices) => planner.plan(
      events: [swim],
      memberId: 'anna',
      from: DateTime.utc(2026, 9, 14),
      until: DateTime.utc(2026, 9, 20),
      members: const [anna, maja],
      withDevices: withDevices,
    );

    final routed = forAnna({'anna'}).where((r) => r.forMember == 'maja');
    expect(routed.single.kind, ReminderKind.prep);
    expect(routed.single.fireAt, DateTime.utc(2026, 9, 17, 13));
    expect(forAnna({'anna', 'maja'}).where((r) => r.forMember != null), isEmpty,
        reason: 'with a tablet of her own, Maja hears it herself');
  });
}
