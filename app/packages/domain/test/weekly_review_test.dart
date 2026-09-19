import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const erik = Member(id: 'erik', displayName: 'Erik', role: MemberRole.parent);
  const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);
  const family = [anna, erik, maja];

  CalendarEvent event(
    String id,
    DateTime localStart, {
    String? driver,
    List<String> going = const ['maja'],
    EventKind kind = EventKind.activity,
    RecurrenceRule? rule,
  }) =>
      CalendarEvent(
        series: EventSeries(
          eventId: id,
          localStart: localStart,
          duration: const Duration(hours: 1),
          timeZone: zone,
          rule: rule,
        ),
        title: id,
        kind: kind,
        participantIds: going,
        responsibleMemberId: driver,
      );

  WeeklyReview review(List<CalendarEvent> events, DateTime today) =>
      const WeeklyReviewBuilder().build(
        events: events,
        members: family,
        today: today,
        timeZone: zone,
        // Sunday evening, 19:00 local.
        now: DateTime.utc(today.year, today.month, today.day, 17),
      );

  test('from Friday on it reviews the week ahead, before that this week', () {
    expect(review([], DateTime.utc(2026, 9, 20)).weekStart,
        DateTime.utc(2026, 9, 21));
    expect(review([], DateTime.utc(2026, 9, 20)).weekNumber, 39);
    expect(review([], DateTime.utc(2026, 9, 18)).weekStart,
        DateTime.utc(2026, 9, 21));
    expect(review([], DateTime.utc(2026, 9, 16)).weekStart,
        DateTime.utc(2026, 9, 14));
    expect(review([], DateTime.utc(2026, 9, 16)).days, hasLength(7));
  });

  test('what needs deciding: no one driving, and one adult in two places', () {
    final r = review([
      event('Football', DateTime.utc(2026, 9, 22, 17), driver: 'anna'),
      event('Dentist', DateTime.utc(2026, 9, 22, 17, 30), driver: 'anna'),
      event('Swimming', DateTime.utc(2026, 9, 24, 18)),
      // Last week: not this review's business.
      event('Old', DateTime.utc(2026, 9, 17, 18)),
    ], DateTime.utc(2026, 9, 20));
    expect(r.unassigned.map((e) => e.event.title), ['Swimming']);
    expect(r.conflicts.map((c) => (c.first.event.title, c.second.event.title)),
        [('Football', 'Dentist')]);
    expect(r.needsAttention, 2);
  });

  test('who drives how often, and how many events there are', () {
    final r = review([
      event(
        'Football',
        DateTime.utc(2026, 9, 21, 17),
        driver: 'anna',
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.mo, Weekday.we},
        ),
      ),
      event('Dentist', DateTime.utc(2026, 9, 25, 9), driver: 'erik'),
      event('School', DateTime.utc(2026, 9, 21, 8),
          kind: EventKind.routine,
          rule: const RecurrenceRule(frequency: Frequency.daily)),
    ], DateTime.utc(2026, 9, 20));
    expect(r.drives, {'anna': 2, 'erik': 1});
    expect(r.eventCount, 3, reason: 'routines are the background, not events');
    expect(r.needsAttention, 0);
  });
}
