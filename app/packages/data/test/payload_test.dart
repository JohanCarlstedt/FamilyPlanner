import 'package:cbor/cbor.dart';
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payload rules (crypto doc §5)', () {
    test('unknown fields written by a newer client survive a rewrite', () {
      // A future client wrote pv 3 with fields this one has never heard of.
      final fromTheFuture = cbor.encode(
        CborMap({
          CborString('pv'): CborSmallInt(3),
          CborString('title'): CborString('Football'),
          CborString('carpoolSeats'): CborSmallInt(4),
          CborString('reactions'): CborList([CborString('👍')]),
        }),
      );

      final payload = Payload.decode(fromTheFuture);
      final edited = EventPayload.write(
        existing: payload,
        title: 'Football training',
        kind: EventKind.activity,
        localStart: DateTime(2026, 9, 22, 17, 30),
        duration: const Duration(minutes: 75),
        timeZone: 'Europe/Stockholm',
      );

      final reread = cbor.decode(edited.payload.encode()) as CborMap;
      expect(reread[CborString('carpoolSeats')], CborSmallInt(4));
      expect(reread[CborString('reactions')], CborList([CborString('👍')]));
      expect(reread[CborString('title')], CborString('Football training'));
    });

    test('an older client never lowers pv', () {
      final newer = Payload.decode(
        cbor.encode(CborMap({CborString('pv'): CborSmallInt(3)})),
      );
      newer.upgradeTo(1);
      expect(newer.pv, 3);
    });

    test('an older payload is lifted to this client\'s version on write', () {
      final older = Payload.create(0);
      final event = EventPayload.write(
        existing: older,
        title: 'x',
        kind: EventKind.appointment,
        localStart: DateTime(2026, 1, 1, 9),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      );
      expect(event.payload.pv, EventPayload.version);
    });

    test('clearing a field writes null, it never removes the key', () {
      final event = EventPayload.write(
        title: 'x',
        kind: EventKind.appointment,
        localStart: DateTime(2026, 1, 1, 9),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        location: 'Skolan',
      );
      final cleared = EventPayload.write(
        existing: event.payload,
        title: 'x',
        kind: EventKind.appointment,
        localStart: DateTime(2026, 1, 1, 9),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      );
      final map = cbor.decode(cleared.payload.encode()) as CborMap;
      expect(map.containsKey(CborString('location')), isTrue);
      expect(map[CborString('location')], const CborNull());
      expect(cleared.location, isNull);
    });

    test('unknown fields inside a nested map survive too', () {
      final withRule = cbor.encode(
        CborMap({
          CborString('pv'): CborSmallInt(2),
          CborString('rule'): CborMap({
            CborString('freq'): CborString('weekly'),
            CborString('byWeekday'): CborList([CborString('tu')]),
            CborString('exceptOnHolidays'): CborBool(true),
          }),
        }),
      );
      final edited = EventPayload.write(
        existing: Payload.decode(withRule),
        title: 'x',
        kind: EventKind.activity,
        localStart: DateTime(2026, 9, 1, 17),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        rule: const RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.th},
        ),
      );
      final rule =
          (cbor.decode(edited.payload.encode()) as CborMap)[CborString('rule')]!
              as CborMap;
      expect(rule[CborString('exceptOnHolidays')], const CborBool(true));
      expect(rule[CborString('byWeekday')], CborList([CborString('th')]));
    });

    test('rejects bytes that are not a payload', () {
      expect(() => Payload.decode([0xff, 0x00]), throwsFormatException);
      expect(
        () => Payload.decode(cbor.encode(CborString('x'))),
        throwsFormatException,
      );
      expect(
        () => Payload.decode(
          cbor.encode(CborMap({CborString('a'): CborSmallInt(1)})),
        ),
        throwsFormatException,
      );
    });
  });

  group('events', () {
    test('round-trip into the domain, recurrence included', () {
      final written = EventPayload.write(
        title: 'Football training',
        kind: EventKind.activity,
        localStart: DateTime.utc(2026, 9, 3, 17, 30),
        duration: const Duration(minutes: 75),
        timeZone: 'Europe/Stockholm',
        rule: RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: const {Weekday.th},
          until: DateTime.utc(2026, 12, 17),
        ),
        participantIds: const ['maja'],
        responsibleMemberId: 'anna',
        location: 'Sportshallen',
        visibility: EventVisibility.parentsOnly,
      );

      final read = EventPayload.read(Payload.decode(written.payload.encode()));
      final event = read.toDomain('e1')!;

      expect(event.title, 'Football training');
      expect(event.kind, EventKind.activity);
      expect(event.series.localStart, DateTime.utc(2026, 9, 3, 17, 30));
      expect(event.series.duration, const Duration(minutes: 75));
      expect(event.series.rule!.byWeekday, {Weekday.th});
      expect(event.series.rule!.until, DateTime.utc(2026, 12, 17));
      expect(event.participantIds, ['maja']);
      expect(event.responsibleMemberId, 'anna');
      expect(read.visibility, EventVisibility.parentsOnly);
    });

    test('start times are stored as wall-clock, never as instants', () {
      final written = EventPayload.write(
        title: 'x',
        kind: EventKind.appointment,
        localStart: DateTime.utc(
          2026,
          3,
          29,
          2,
          30,
        ), // inside Stockholm's DST gap
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      );
      expect(written.payload.text('start'), '2026-03-29T02:30');
      expect(
        EventPayload.read(written.payload).localStart,
        DateTime.utc(2026, 3, 29, 2, 30),
        reason: 'read back without passing through the device zone',
      );
    });

    test('a damaged event without a start is not scheduled', () {
      final p = Payload.create(1)..setText('title', 'x');
      expect(EventPayload.read(p).toDomain('e1'), isNull);
    });
  });

  test('member profiles round-trip', () {
    final written = MemberProfile.write(
      displayName: 'Maja',
      role: MemberRole.child,
      color: '#009E73',
    );
    final read = MemberProfile.read(Payload.decode(written.payload.encode()));
    expect(read.displayName, 'Maja');
    expect(read.color, '#009E73');
  });

  group('event reminders', () {
    EventPayload withReminders(
      List<EventReminder> reminders, {
      Payload? existing,
    }) => EventPayload.write(
      existing: existing,
      title: 'Football',
      kind: EventKind.activity,
      localStart: DateTime.utc(2026, 9, 17, 17, 30),
      duration: const Duration(hours: 1),
      timeZone: 'Europe/Stockholm',
      reminders: reminders,
    );

    test('round-trip into the domain', () {
      final written = withReminders(const [
        EventReminder(minutesBefore: 24 * 60),
        EventReminder(minutesBefore: 10, target: ReminderTarget.responsible),
      ]);
      final event = EventPayload.read(Payload.decode(written.payload.encode()))
          .toDomain('e1')!;

      expect(
        [for (final r in event.reminders) (r.minutesBefore, r.target)],
        [
          (24 * 60, ReminderTarget.participants),
          (10, ReminderTarget.responsible),
        ],
      );
    });

    test('a newer client\'s field on a reminder survives a rewrite', () {
      final stored = Payload.decode(
        withReminders(const [EventReminder(minutesBefore: 30)]).payload
            .encode(),
      );
      stored.nestedList('reminders')!.single.setText('sound', 'whistle');

      final rewritten = withReminders(const [
        EventReminder(minutesBefore: 45),
      ], existing: stored);
      final reminder = rewritten.payload.nestedList('reminders')!.single;
      expect(reminder.text('sound'), 'whistle');
      expect(reminder.integer('minutes'), 45);
    });

    test('an event from before reminders has none', () {
      final old = EventPayload.write(
        title: 'Football',
        kind: EventKind.activity,
        localStart: DateTime.utc(2026, 9, 17, 17, 30),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      );
      old.payload.setNestedList('reminders', null);
      expect(EventPayload.read(old.payload).reminders, isEmpty);
    });
  });

  group('event exceptions', () {
    final original = DateTime.utc(2026, 9, 17, 15, 30);

    test('round-trip into the domain', () {
      final written = EventExceptionPayload.write(
        eventId: 'training',
        originalStart: original,
        type: ExceptionType.moved,
        overrideStart: DateTime.utc(2026, 9, 18, 16),
        overrideDuration: const Duration(minutes: 90),
        overrideTitle: 'Away match',
        overrideResponsibleMemberId: 'erik',
      );

      final read = EventExceptionPayload.read(
        Payload.decode(written.payload.encode()),
      );
      final entry = read.toDomain()!;
      expect(read.eventId, 'training');
      expect(entry.originalStart, original);
      expect(entry.type, ExceptionType.moved);
      expect(entry.overrideStart, DateTime.utc(2026, 9, 18, 16));
      expect(entry.overrideDuration, const Duration(minutes: 90));
      expect(entry.overrideTitle, 'Away match');
      expect(entry.overrideResponsibleMemberId, 'erik');
    });

    test('times are stored as UTC instants, marked as such', () {
      final written = EventExceptionPayload.write(
        eventId: 'training',
        originalStart: original,
        type: ExceptionType.cancelled,
      );

      expect(written.payload.text('original'), '2026-09-17T15:30Z');
      expect(written.payload.text('start'), isNull);
    });

    test('one occurrence has one id on every device', () {
      final a = EventExceptionPayload.idFor('training', original);
      final b = EventExceptionPayload.idFor('training', original.toLocal());
      expect(a, b);
      expect(
        EventExceptionPayload.idFor(
          'training',
          original.add(const Duration(days: 7)),
        ),
        isNot(a),
      );
      // Pinned against Python's uuid.uuid5 with the same namespace and name:
      // other clients must derive the same id.
      expect(a, '5a26489d-51ba-5cf1-bc7e-58fe5104dde6');
    });

    test('an exception that cannot name its occurrence is ignored', () {
      final damaged = Payload.create(EventExceptionPayload.version)
        ..setText('event', 'training');
      expect(EventExceptionPayload.read(damaged).toDomain(), isNull);
    });
  });
}
