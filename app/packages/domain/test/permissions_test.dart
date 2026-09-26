import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  Member child(MaturityTier tier) =>
      Member(id: 'c', displayName: 'C', role: MemberRole.child, tier: tier);
  const sara = Member(id: 'sara', displayName: 'Sara', role: MemberRole.helper);

  final event = CalendarEvent(
    series: EventSeries(
      eventId: 'e',
      localStart: DateTime.utc(2026, 9, 22, 17),
      duration: const Duration(hours: 1),
      timeZone: 'Europe/Stockholm',
    ),
    title: 'Training',
    kind: EventKind.activity,
  );

  test('a parent may do everything here', () {
    const p = Permissions(anna);
    expect(p.manageFamily, isTrue);
    expect(p.createEvents && p.createForOthers, isTrue);
    expect(p.createsRequests, isFalse);
    expect(p.editEvent(event, createdBy: 'someone'), isTrue);
    expect(p.setReminders(event, createdBy: 'someone'), isTrue);
    expect(p.approveRequests, isTrue);
    expect(p.daysVisible, isNull);
  });

  test('a child may delete what concerns them, not change it', () {
    final p = Permissions(child(MaturityTier.kid));
    CalendarEvent withWho(List<String> who) => CalendarEvent(
          series: event.series,
          title: event.title,
          kind: event.kind,
          participantIds: who,
        );
    expect(p.editEvent(withWho(['c']), createdBy: 'anna'), isFalse);
    expect(p.deleteEvent(withWho(['c']), createdBy: 'anna'), isTrue);
    expect(p.deleteEvent(withWho([]), createdBy: null), isTrue,
        reason: 'everyone\'s, so hers too');
    expect(p.deleteEvent(withWho(['anna']), createdBy: 'anna'), isFalse,
        reason: 'someone else\'s appointment');
    expect(Permissions(sara).deleteEvent(withWho(['c']), createdBy: 'anna'),
        isFalse, reason: 'a helper is not one of the family\'s children');
  });

  test('a teen: own events, for themselves', () {
    final p = Permissions(child(MaturityTier.teen));
    expect(p.createEvents, isTrue);
    expect(p.createForOthers, isFalse);
    expect(p.createsRequests, isFalse);
    expect(p.editEvent(event, createdBy: 'c'), isTrue);
    expect(p.editEvent(event, createdBy: 'anna'), isFalse);
    expect(p.setReminders(event, createdBy: 'c'), isTrue);
    expect(p.setReminders(event, createdBy: 'anna'), isFalse);
    expect(p.manageFamily, isFalse);
  });

  group('contributing to an event you are in', () {
    final hers = CalendarEvent(
      title: 'Football training',
      kind: EventKind.activity,
      series: EventSeries(
        eventId: 'football',
        localStart: DateTime.utc(2026, 9, 22, 17),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      ),
      participantIds: const ['c'],
    );

    test('a child in it may add to the kit, without being able to move it', () {
      // She knows the shin pads are in the hall better than anyone, and
      // could say nothing unless she had made the event herself — which,
      // for anything a parent entered, she had not.
      final p = Permissions(child(MaturityTier.kid));
      expect(p.contributeToEvent(hers), isTrue);
      expect(p.editEvent(hers, createdBy: 'anna'), isFalse);
    });

    test('a child not in it may not', () {
      final p = Permissions(
        const Member(
            id: 'other',
            displayName: 'O',
            role: MemberRole.child,
            tier: MaturityTier.teen),
      );
      expect(p.contributeToEvent(hers), isFalse);
    });

    test('a parent may, as before', () {
      expect(const Permissions(anna).contributeToEvent(hers), isTrue);
    });

    test('a helper may not', () {
      expect(const Permissions(sara).contributeToEvent(hers), isFalse);
    });
  });

  test('a kid asks; a parent approves', () {
    final p = Permissions(child(MaturityTier.kid));
    expect(p.createEvents, isTrue);
    expect(p.createsRequests, isTrue);
    // Their own is theirs to correct: a kid who was trusted to enter a
    // training session is trusted to move it half an hour, without
    // finding a parent to go and do it.
    expect(p.editEvent(event, createdBy: 'c'), isTrue);
    // What a parent put there stays a parent's.
    expect(p.editEvent(event, createdBy: 'anna'), isFalse);
    expect(p.editEvent(event, createdBy: null), isFalse);
    expect(p.setReminders(null, createdBy: null), isFalse);
    expect(p.approveRequests, isFalse);
  });

  test('a little one sees today and tomorrow, and changes nothing', () {
    final p = Permissions(child(MaturityTier.little));
    expect(p.daysVisible, 2);
    expect(p.createEvents, isFalse);
    expect(p.editEvent(event, createdBy: 'c'), isFalse);
  });

  test('a helper reads and can be responsible, nothing more here', () {
    const p = Permissions(sara);
    expect(p.createEvents, isFalse);
    expect(p.editEvent(event, createdBy: 'sara'), isFalse);
    expect(p.manageFamily, isFalse);
  });

  test('an unknown member may do nothing', () {
    const p = Permissions(null);
    expect(p.createEvents || p.manageFamily || p.approveRequests, isFalse);
  });

  group('the menu and dinner picks (spec §4)', () {
    test('parents and teens plan; everyone but a helper shops', () {
      expect(const Permissions(anna).planMenu, isTrue);
      expect(Permissions(child(MaturityTier.teen)).planMenu, isTrue);
      expect(Permissions(child(MaturityTier.kid)).planMenu, isFalse);
      expect(Permissions(child(MaturityTier.kid)).shop, isTrue);
      expect(const Permissions(sara).shop, isFalse);
      expect(const Permissions(null).shop, isFalse);
    });

    test('a child picks one dinner a week; a little one through a parent', () {
      final kid = Permissions(child(MaturityTier.kid));
      expect(kid.pickDinner(chosenThisWeek: const []), isTrue);
      expect(kid.pickDinner(chosenThisWeek: const ['other']), isTrue);
      expect(kid.pickDinner(chosenThisWeek: const ['c']), isFalse);
      expect(
        Permissions(child(MaturityTier.little))
            .pickDinner(chosenThisWeek: const []),
        isFalse,
      );
      expect(
          const Permissions(anna).pickDinner(chosenThisWeek: const []), isFalse,
          reason: 'a parent plans; the pick is the children\'s');
    });

    test('whose picks are still to come this week', () {
      final little = Member(
        id: 'ella',
        displayName: 'Ella',
        role: MemberRole.child,
        tier: MaturityTier.little,
      );
      final maja = child(MaturityTier.kid);
      expect(
        dinnerPicksLeft([anna, maja, little, sara], chosenThisWeek: ['c'])
            .map((m) => m.id),
        ['ella'],
      );
    });
  });
}
