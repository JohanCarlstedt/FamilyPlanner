import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';

  // Football every Saturday 10:00 from 5 September.
  EventSeries saturdays({List<ExceptionEntry> exceptions = const []}) =>
      EventSeries(
        eventId: 'football',
        localStart: DateTime.utc(2026, 9, 5, 10),
        duration: const Duration(hours: 1),
        timeZone: zone,
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.sa},
        ),
        exceptions: exceptions,
      );

  CalendarEvent football({
    List<ExceptionEntry> exceptions = const [],
    EventStatus status = EventStatus.confirmed,
  }) =>
      CalendarEvent(
        series: saturdays(exceptions: exceptions),
        title: 'Football',
        kind: EventKind.activity,
        status: status,
      );

  const washKit = ActionTemplate(
    id: 'kit',
    title: 'Wash the kit',
    offsetMinutes: -2 * 24 * 60,
    rotateAmong: ['anna', 'erik'],
    eventId: 'football',
  );

  List<PlannedAction> plan(ActionTemplate t, {CalendarEvent? event}) =>
      planActions(
        template: t,
        event: event,
        from: DateTime.utc(2026, 9, 19),
        until: DateTime.utc(2026, 10, 11),
      );

  test('prep is due relative to each occurrence, and turns rotate', () {
    final planned = plan(washKit, event: football());
    expect([
      for (final p in planned) p.dueAt
    ], [
      // Saturday 10:00 Stockholm is 08:00 UTC; two days before.
      DateTime.utc(2026, 9, 17, 8),
      DateTime.utc(2026, 9, 24, 8),
      DateTime.utc(2026, 10, 1, 8),
      DateTime.utc(2026, 10, 8, 8),
    ]);
    // 5 Sep was Anna's (index 0), 12 Sep Erik's, 19 Sep Anna's …
    expect([
      for (final p in planned) p.assignee
    ], [
      'anna',
      'erik',
      'anna',
      'erik',
    ]);
    expect(planned.first.key, 'kit/2026-09-19T08:00:00.000Z');
  });

  test('a cancelled occurrence cancels its prep; a moved one moves it', () {
    final planned = plan(
      washKit,
      event: football(
        exceptions: [
          ExceptionEntry(
            originalStart: DateTime.utc(2026, 9, 26, 8),
            type: ExceptionType.cancelled,
          ),
          ExceptionEntry(
            originalStart: DateTime.utc(2026, 10, 3, 8),
            type: ExceptionType.moved,
            overrideStart: DateTime.utc(2026, 10, 4, 8),
          ),
        ],
      ),
    );
    final byKey = {for (final p in planned) p.occurrenceStart: p};
    expect(byKey[DateTime.utc(2026, 9, 26, 8)]!.cancelled, isTrue);
    expect(
      byKey[DateTime.utc(2026, 10, 3, 8)]!.dueAt,
      DateTime.utc(2026, 10, 2, 8),
    );
    expect(
      byKey[DateTime.utc(2026, 10, 3, 8)]!.assignee,
      'anna',
      reason: 'turns follow the unmoved series, so moving never shuffles them',
    );
  });

  test('a cancelled event cancels all its prep', () {
    expect(
      plan(
        washKit,
        event: football(status: EventStatus.cancelled),
      ).every((p) => p.cancelled),
      isTrue,
    );
  });

  test('a chore on its own schedule: bins every other Tuesday', () {
    final bins = ActionTemplate(
      id: 'bins',
      title: 'Bins out',
      assignee: 'erik',
      schedule: EventSeries(
        eventId: 'bins',
        localStart: DateTime.utc(2026, 9, 8, 7),
        duration: Duration.zero,
        timeZone: zone,
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          interval: 2,
          byWeekday: {Weekday.tu},
        ),
      ),
    );
    final planned = plan(bins);
    expect([
      for (final p in planned) p.dueAt
    ], [
      DateTime.utc(2026, 9, 22, 5),
      DateTime.utc(2026, 10, 6, 5),
    ]);
    expect(planned.every((p) => p.assignee == 'erik'), isTrue);
  });

  test('prep for an event this device can\'t see plans nothing', () {
    expect(plan(washKit), isEmpty);
  });
}
