import 'package:domain/domain.dart';
import 'package:family/src/data/store_providers.dart';
import 'package:family/src/reminders/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class _Channel implements WakeChannel {
  final calls = <(Map<String, DateTime>, List<String>)>[];

  @override
  Future<void> schedule(
    Map<String, DateTime> wakes,
    List<String> cancel,
  ) async => calls.add((wakes, cancel));
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const zone = 'Europe/Stockholm';
  const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);

  // Thursdays 17:30 in Stockholm (15:30 UTC), an hour's reminder, Maja going.
  // A routine, so only the event's own reminder applies here.
  CalendarEvent training({
    List<ExceptionEntry> exceptions = const [],
    String id = 'training',
    int minutesBefore = 60,
    EventKind kind = EventKind.routine,
  }) => CalendarEvent(
    series: EventSeries(
      eventId: id,
      localStart: DateTime.utc(2026, 9, 3, 17, 30),
      duration: const Duration(hours: 1),
      timeZone: zone,
      rule: const RecurrenceRule(
        frequency: Frequency.weekly,
        byWeekday: {Weekday.th},
      ),
      exceptions: exceptions,
    ),
    title: id,
    kind: kind,
    participantIds: const ['maja'],
    reminders: [EventReminder(minutesBefore: minutesBefore)],
  );

  final cancelledThursday = ExceptionEntry(
    originalStart: DateTime.utc(2026, 9, 17, 15, 30),
    type: ExceptionType.cancelled,
  );

  final monday = DateTime.utc(2026, 9, 14, 8);
  final thursdayWake = DateTime.utc(2026, 9, 17, 14, 30);

  late MemoryPreferences prefs;
  late _Channel channel;
  late ReminderScheduler scheduler;

  setUp(() {
    prefs = MemoryPreferences();
    channel = _Channel();
    scheduler = ReminderScheduler(preferences: prefs, channel: channel);
  });

  ReminderContext context(
    List<CalendarEvent> events, {
    FamilySettings settings = const FamilySettings(digestAt: null),
    List<({DateTime closesAt, String id, String title})> polls = const [],
  }) => ReminderContext(
    events: events,
    memberId: 'maja',
    timeZone: zone,
    members: const [maja],
    settings: settings,
    unansweredPolls: polls,
  );

  Future<void> reconcile(List<CalendarEvent> events, DateTime now) =>
      scheduler.reconcile(context(events), now: now);

  String refAt(DateTime at) =>
      channel.calls.first.$1.entries.firstWhere((e) => e.value == at).key;

  test('registers the week ahead and a replan wake', () async {
    await reconcile([training()], monday);

    final (wakes, cancel) = channel.calls.single;
    expect(
      wakes.values,
      containsAll([thursdayWake, monday.add(ReminderScheduler.replanAfter)]),
    );
    expect(wakes, hasLength(2), reason: 'next Thursday is past the horizon');
    expect(cancel, isEmpty);
  });

  test('references reveal nothing about the event', () async {
    await reconcile([training()], monday);

    for (final ref in channel.calls.single.$1.keys) {
      expect(ref, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
  });

  test('reconciling again with nothing changed sends nothing', () async {
    await reconcile([training()], monday);
    await reconcile([training()], monday.add(const Duration(minutes: 30)));

    expect(channel.calls, hasLength(1));
  });

  test('a cancelled occurrence cancels its wake', () async {
    await reconcile([training()], monday);
    final thursdayRef = refAt(thursdayWake);

    await reconcile([
      training(exceptions: [cancelledThursday]),
    ], monday);

    expect(channel.calls.last.$2, [thursdayRef]);
  });

  test('a wake shows its reminder once, and only if still owed', () async {
    await reconcile([training()], monday);
    final ref = refAt(thursdayWake);

    Future<WakeContent?> resolve(List<CalendarEvent> events) =>
        scheduler.resolve(ref, context(events), now: thursdayWake);

    expect(
      await resolve([
        training(exceptions: [cancelledThursday]),
      ]),
      isNull,
      reason: 'cancelled on another phone after the wake was registered',
    );
    final shown = await resolve([training()]);
    expect((shown! as DueReminders).reminders.single.event.title, 'training');
    expect(await resolve([training()]), isNull, reason: 'never twice');
  });

  test('reminders in the same ten minutes share one wake', () async {
    final together = [
      training(id: 'football', minutesBefore: 62),
      training(id: 'piano', minutesBefore: 65),
    ];
    channel.calls.clear();
    await scheduler.reconcile(context(together), now: monday);
    final first = channel.calls.single.$1.entries
        .where(
          (e) =>
              e.value.isBefore(DateTime.utc(2026, 9, 18)) &&
              e.value != monday.add(ReminderScheduler.replanAfter),
        )
        .toList();
    expect(first, hasLength(1), reason: '16:25 and 16:28 are one bucket');

    final content = await scheduler.resolve(
      first.single.key,
      context(together),
      now: first.single.value,
    );
    expect([
      for (final r in (content! as DueReminders).reminders) r.event.title,
    ], unorderedEquals(['football', 'piano']));
  });

  test('the morning digest lists the member\'s day', () async {
    const settings = FamilySettings(digestAt: 7 * 60);
    // Routines stay out of the digest, like dinner every day would.
    final events = [training(kind: EventKind.activity)];
    await scheduler.reconcile(context(events, settings: settings), now: monday);
    // 07:00 Thursday in Stockholm is 05:00 UTC.
    final at = DateTime.utc(2026, 9, 17, 5);
    final ref = refAt(at);

    final content = await scheduler.resolve(
      ref,
      context(events, settings: settings),
      now: at,
    );
    expect((content! as Digest).entries.single.event.title, 'training');

    // Wednesday's digest has nothing to say, so it says nothing.
    final wednesday = DateTime.utc(2026, 9, 16, 5);
    expect(
      await scheduler.resolve(
        refAt(wednesday),
        context(events, settings: settings),
        now: wednesday,
      ),
      isNull,
    );
  });

  test('a wake far too late shows nothing', () async {
    await reconcile([training()], monday);

    final late = await scheduler.resolve(
      refAt(thursdayWake),
      context([training()]),
      now: thursdayWake.add(const Duration(hours: 1)),
    );
    expect(late, isNull);
  });
  group('a question about to stop being answerable', () {
    // Friday 18 September, 18:00 Stockholm (16:00 UTC).
    final closes = DateTime.utc(2026, 9, 18, 16);
    ({DateTime closesAt, String id, String title}) question({
      String id = 'cabin',
      DateTime? at,
    }) => (id: id, title: 'Vilken helg åker vi?', closesAt: at ?? closes);

    test('is asked about three hours before it closes', () async {
      await scheduler.reconcile(
        context(const [], polls: [question()]),
        now: monday,
      );
      final (wakes, _) = channel.calls.single;
      expect(wakes.values, contains(DateTime.utc(2026, 9, 18, 13)));
    });

    test('and not at all once that moment has gone', () async {
      // "This closes in three hours" arriving twenty minutes before it
      // closes is worse than silence.
      await scheduler.reconcile(
        context(const [], polls: [question()]),
        now: DateTime.utc(2026, 9, 18, 15, 40),
      );
      final (wakes, _) = channel.calls.single;
      expect(wakes.values, isNot(contains(DateTime.utc(2026, 9, 18, 13))));
    });

    test('never inside quiet hours', () async {
      // Closing at six in the morning would ask at three. A question is
      // not urgent enough to wake a house.
      await scheduler.reconcile(
        context(const [], polls: [question(at: DateTime.utc(2026, 9, 18, 4))]),
        now: monday,
      );
      final (wakes, _) = channel.calls.single;
      // 03:00 local, which is what three hours before six in the
      // morning comes to. The replan wake is still there, as always.
      expect(wakes.values, isNot(contains(DateTime.utc(2026, 9, 18, 1))));
    });

    test('the wake says what is still owed, and only once', () async {
      final ctx = context(const [], polls: [question()]);
      await scheduler.reconcile(ctx, now: monday);
      // Found by its time: the reference itself is an HMAC, and the
      // replan wake sits beside it.
      final ref = channel.calls.single.$1.entries
          .firstWhere((e) => e.value == DateTime.utc(2026, 9, 18, 13))
          .key;

      final first = await scheduler.resolve(
        ref,
        ctx,
        now: DateTime.utc(2026, 9, 18, 13),
      );
      expect(first, isA<PollClosing>());
      expect((first! as PollClosing).polls.single.title, 'Vilken helg åker vi?');

      // Shown once: a second push for the same wake is silent.
      expect(
        await scheduler.resolve(ref, ctx, now: DateTime.utc(2026, 9, 18, 13)),
        isNull,
      );
    });

    test('answered since the wake was registered, it shows nothing', () async {
      final ctx = context(const [], polls: [question()]);
      await scheduler.reconcile(ctx, now: monday);
      final ref = channel.calls.single.$1.entries
          .firstWhere((e) => e.value == DateTime.utc(2026, 9, 18, 13))
          .key;

      // The context is read fresh at wake time, so an answered question
      // is simply not in it any more.
      expect(
        await scheduler.resolve(
          ref,
          context(const []),
          now: DateTime.utc(2026, 9, 18, 13),
        ),
        isNull,
      );
    });
  });

}
