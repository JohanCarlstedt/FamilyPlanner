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
  }) => ReminderContext(
    events: events,
    memberId: 'maja',
    timeZone: zone,
    members: const [maja],
    settings: settings,
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
}
