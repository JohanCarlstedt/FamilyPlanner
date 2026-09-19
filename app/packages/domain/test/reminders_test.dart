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
  }) => planner.plan(
    events: events,
    memberId: member,
    from: from ?? DateTime.utc(2026, 9, 14),
    until: until ?? DateTime.utc(2026, 9, 28),
  );

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
}
