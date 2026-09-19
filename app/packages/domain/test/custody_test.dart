import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';

  // Maja comes to us on Sunday 20 September at 17:00; alternating weeks.
  final weeks = CustodyArrangement(
    childId: 'maja',
    coParentId: 'erik',
    pattern: CustodyPattern.alternatingWeeks,
    reference: DateTime.utc(2026, 9, 20, 17),
  );

  test('alternating weeks: here from the changeover, there a week later', () {
    expect(weeks.isHere(DateTime.utc(2026, 9, 20, 16, 59)), isFalse);
    expect(weeks.isHere(DateTime.utc(2026, 9, 20, 17)), isTrue);
    expect(weeks.isHere(DateTime.utc(2026, 9, 25, 12)), isTrue);
    expect(weeks.isHere(DateTime.utc(2026, 9, 27, 17)), isFalse);
    expect(weeks.isHere(DateTime.utc(2026, 10, 4, 17)), isTrue);
    expect(weeks.isHere(DateTime.utc(2026, 9, 1, 12)), isFalse,
        reason: 'before the reference the pattern runs backwards too');
  });

  test('alternating weekends: away Friday to Sunday every other week', () {
    final weekends = CustodyArrangement(
      childId: 'maja',
      pattern: CustodyPattern.alternatingWeekends,
      // To the other home Friday 25 September at 17:00.
      reference: DateTime.utc(2026, 9, 25, 17),
    );
    expect(weekends.isHere(DateTime.utc(2026, 9, 24, 12)), isTrue);
    expect(weekends.isHere(DateTime.utc(2026, 9, 26, 12)), isFalse);
    expect(weekends.isHere(DateTime.utc(2026, 9, 27, 17)), isTrue);
    expect(weekends.isHere(DateTime.utc(2026, 10, 3, 12)), isTrue);
    expect(weekends.isHere(DateTime.utc(2026, 10, 10, 12)), isFalse);
  });

  test('a swap overrides the pattern for its days', () {
    final swapped = CustodyArrangement(
      childId: 'maja',
      pattern: CustodyPattern.alternatingWeeks,
      reference: DateTime.utc(2026, 9, 20, 17),
      swaps: [
        CustodySwap(
          from: DateTime.utc(2026, 9, 28),
          until: DateTime.utc(2026, 9, 30),
          here: true,
        ),
      ],
    );
    expect(swapped.isHere(DateTime.utc(2026, 9, 29, 12)), isTrue);
    expect(swapped.isHere(DateTime.utc(2026, 10, 1, 12)), isFalse);
  });

  test('changeovers are events, both ways, every other week', () {
    final events = weeks.changeoverEvents(
      timeZone: zone,
      toUs: 'Maja till oss',
      toThem: 'Maja till Erik',
      idFor: (direction) => 'changeover-$direction',
    );
    expect(events.map((e) => e.title), ['Maja till oss', 'Maja till Erik']);
    final starts = [
      for (final e in events)
        const RecurrenceExpander()
            .expand(
                e.series, DateTime.utc(2026, 9, 19), DateTime.utc(2026, 10, 10))
            .map((o) => o.start)
            .toList(),
    ];
    expect(starts, [
      // 17:00 Stockholm is 15:00 UTC.
      [DateTime.utc(2026, 9, 20, 15), DateTime.utc(2026, 10, 4, 15)],
      [DateTime.utc(2026, 9, 27, 15)],
    ]);
    expect(events.every((e) => e.participantIds.contains('maja')), isTrue);
  });

  test('a co-parent edits their children\'s events, and nothing else', () {
    const erik = Member(
      id: 'erik',
      displayName: 'Erik',
      role: MemberRole.helper,
      coParentOf: {'maja'},
    );
    final p = Permissions(erik);
    CalendarEvent about(List<String> going) => CalendarEvent(
          series: EventSeries(
            eventId: 'e',
            localStart: DateTime.utc(2026, 9, 22, 17),
            duration: const Duration(hours: 1),
            timeZone: zone,
          ),
          title: 't',
          kind: EventKind.activity,
          participantIds: going,
        );
    expect(p.createEvents, isTrue);
    expect(p.editEvent(about(['maja']), createdBy: 'anna'), isTrue);
    expect(p.editEvent(about(['maja', 'ella']), createdBy: 'anna'), isFalse);
    expect(p.editEvent(about([]), createdBy: 'anna'), isFalse);
    expect(p.manageFamily, isFalse);
  });

  test('this home isn\'t asked who drives while the child is with the other',
      () {
    const anna =
        Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
    const maja =
        Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);
    CalendarEvent training(DateTime local) => CalendarEvent(
          series: EventSeries(
            eventId: 'training',
            localStart: local,
            duration: const Duration(hours: 1),
            timeZone: zone,
          ),
          title: 'Träning',
          kind: EventKind.activity,
          participantIds: const ['maja'],
        );
    List<DueReminder> plan(DateTime local) => const ReminderPlanner().plan(
          events: [training(local)],
          memberId: 'anna',
          from: DateTime.utc(2026, 9, 18),
          until: DateTime.utc(2026, 10, 10),
          members: const [anna, maja],
          custody: [weeks],
        );
    // Tuesday 22nd: with us. Tuesday 29th: with Erik.
    expect(plan(DateTime.utc(2026, 9, 22, 17)), isNotEmpty);
    expect(plan(DateTime.utc(2026, 9, 29, 17)), isEmpty);
  });
}
