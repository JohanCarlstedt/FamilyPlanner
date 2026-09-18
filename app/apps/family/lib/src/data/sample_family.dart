import 'package:domain/domain.dart';

import 'family_repository.dart';

/// An invented household for widget tests and screenshots. Seeded so today always
/// shows a responsibility gap, a double-booked parent, a cancellation and
/// routine blocks, the cases the Today screen has to handle.
class SampleFamily implements FamilyRepository {
  static const String zone = 'Europe/Stockholm';

  SampleFamily({required this.today});

  /// Local calendar date the one-off events land on.
  final DateTime today;

  @override
  String get timeZone => zone;

  // Okabe–Ito colours: distinguishable under deuteranopia (spec §5).
  static const _members = [
    Member(
      id: 'anna',
      displayName: 'Anna',
      role: MemberRole.parent,
      color: '#0072B2',
    ),
    Member(
      id: 'erik',
      displayName: 'Erik',
      role: MemberRole.parent,
      color: '#E69F00',
    ),
    Member(
      id: 'maja',
      displayName: 'Maja',
      role: MemberRole.child,
      color: '#009E73',
    ),
    Member(
      id: 'leo',
      displayName: 'Leo',
      role: MemberRole.child,
      color: '#CC79A7',
    ),
  ];

  static const _everyone = ['anna', 'erik', 'maja', 'leo'];

  @override
  Stream<List<Member>> watchMembers() => Stream.value(_members);

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(_events());

  List<CalendarEvent> _events() {
    final weekday = Weekday.values[today.weekday - 1];
    // Recurring series start four weeks back, as real ones would.
    final seasonStart = today.subtract(const Duration(days: 28));

    return [
      _event(
        'breakfast',
        'Breakfast',
        seasonStart,
        7,
        0,
        30,
        kind: EventKind.routine,
        participants: _everyone,
        daily: true,
      ),
      _event(
        'school-run',
        'School run',
        seasonStart,
        7,
        45,
        30,
        kind: EventKind.activity,
        participants: ['maja', 'leo'],
        responsible: 'erik',
        location: 'Skolan',
        daily: true,
      ),
      _event(
        'dentist',
        'Dentist',
        today,
        10,
        0,
        45,
        participants: ['leo'],
        responsible: 'anna',
        location: 'Folktandvården',
      ),
      _event(
        'piano',
        'Piano lesson',
        seasonStart,
        16,
        0,
        45,
        kind: EventKind.activity,
        participants: ['maja'],
        responsible: 'erik',
        location: 'Kulturskolan',
        status: EventStatus.cancelled,
        weeklyOn: weekday,
      ),
      _event(
        'football',
        'Football training',
        seasonStart,
        17,
        0,
        75,
        kind: EventKind.activity,
        participants: ['maja'],
        location: 'Sportshallen',
        weeklyOn: weekday,
      ),
      _event(
        'swimming',
        'Swimming',
        seasonStart,
        17,
        30,
        45,
        kind: EventKind.activity,
        participants: ['leo'],
        responsible: 'anna',
        location: 'Simhallen',
        weeklyOn: weekday,
      ),
      _event(
        'parents-evening',
        "Parents' evening",
        today,
        18,
        0,
        60,
        participants: ['anna'],
        responsible: 'anna',
        location: 'Skolan',
      ),
      _event(
        'dinner',
        'Dinner',
        seasonStart,
        18,
        30,
        45,
        kind: EventKind.routine,
        participants: _everyone,
        daily: true,
      ),
      _event(
        'bedtime',
        'Bedtime',
        seasonStart,
        19,
        30,
        30,
        kind: EventKind.routine,
        participants: ['leo'],
        responsible: 'erik',
        daily: true,
      ),
    ];
  }

  CalendarEvent _event(
    String id,
    String title,
    DateTime date,
    int hour,
    int minute,
    int minutes, {
    EventKind kind = EventKind.appointment,
    List<String> participants = const [],
    String? responsible,
    String? location,
    EventStatus status = EventStatus.confirmed,
    bool daily = false,
    Weekday? weeklyOn,
  }) {
    final RecurrenceRule? rule;
    if (daily) {
      rule = const RecurrenceRule(frequency: Frequency.daily);
    } else if (weeklyOn != null) {
      rule = RecurrenceRule(frequency: Frequency.weekly, byWeekday: {weeklyOn});
    } else {
      rule = null;
    }

    return CalendarEvent(
      series: EventSeries(
        eventId: id,
        localStart: DateTime(date.year, date.month, date.day, hour, minute),
        duration: Duration(minutes: minutes),
        timeZone: zone,
        rule: rule,
      ),
      title: title,
      kind: kind,
      status: status,
      participantIds: participants,
      responsibleMemberId: responsible,
      location: location,
    );
  }
}
