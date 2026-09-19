import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);

  CalendarEvent birthday(DateTime date, {List<int> lead = const [14, 3, 0]}) =>
      Celebrations.event(
        eventId: 'b',
        title: 'Farmor',
        date: date,
        timeZone: zone,
        leadDays: lead,
      );

  test('a 29 February birthday is on the 28th in a common year', () {
    final starts = const RecurrenceExpander()
        .expand(
          birthday(DateTime.utc(2016, 2, 29)).series,
          DateTime.utc(2027, 1, 1),
          DateTime.utc(2029, 1, 1),
        )
        .map((o) => o.start);
    expect(starts, [
      // Midnight Stockholm, in UTC.
      DateTime.utc(2027, 2, 27, 23),
      DateTime.utc(2028, 2, 28, 23),
    ]);
  });

  test('how old someone turns', () {
    expect(
        Celebrations.ageOn(
            DateTime.utc(2015, 3, 12), DateTime.utc(2026, 3, 12)),
        11);
    expect(
        Celebrations.ageOn(DateTime.utc(1900, 1, 1), DateTime.utc(2026, 1, 1)),
        isNull,
        reason: 'a year of birth nobody knows is stored as 1900');
  });

  test(
      'gift reminders reach the adults at 09:00, 14 and 3 days ahead and '
      'on the day', () {
    final due = const ReminderPlanner().plan(
      events: [birthday(DateTime.utc(1950, 10, 20))],
      memberId: 'anna',
      from: DateTime.utc(2026, 10, 1),
      until: DateTime.utc(2026, 10, 25),
      members: const [anna, maja],
    );
    expect([
      for (final r in due) r.fireAt
    ], [
      DateTime.utc(2026, 10, 6, 7),
      DateTime.utc(2026, 10, 17, 7),
      DateTime.utc(2026, 10, 20, 7),
    ]);
    expect(
      const ReminderPlanner().plan(
        events: [birthday(DateTime.utc(1950, 10, 20))],
        memberId: 'maja',
        from: DateTime.utc(2026, 10, 1),
        until: DateTime.utc(2026, 10, 25),
        members: const [anna, maja],
      ),
      isEmpty,
      reason: 'a child isn\'t asked to buy gifts',
    );
  });
}
