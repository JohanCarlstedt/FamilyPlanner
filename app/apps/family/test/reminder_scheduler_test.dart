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

  // Thursdays 17:30 in Stockholm (15:30 UTC), an hour's reminder, Maja going.
  CalendarEvent training({List<ExceptionEntry> exceptions = const []}) =>
      CalendarEvent(
        series: EventSeries(
          eventId: 'training',
          localStart: DateTime.utc(2026, 9, 3, 17, 30),
          duration: const Duration(hours: 1),
          timeZone: 'Europe/Stockholm',
          rule: const RecurrenceRule(
            frequency: Frequency.weekly,
            byWeekday: {Weekday.th},
          ),
          exceptions: exceptions,
        ),
        title: 'Training',
        kind: EventKind.activity,
        participantIds: const ['maja'],
        reminders: const [EventReminder(minutesBefore: 60)],
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

  Future<void> reconcile(List<CalendarEvent> events, DateTime now) =>
      scheduler.reconcile(events: events, memberId: 'maja', now: now);

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
      expect(ref, isNot(contains('training')));
    }
  });

  test('reconciling again with nothing changed sends nothing', () async {
    await reconcile([training()], monday);
    await reconcile([training()], monday.add(const Duration(minutes: 30)));

    expect(channel.calls, hasLength(1));
  });

  test('a cancelled occurrence cancels its wake', () async {
    await reconcile([training()], monday);
    final thursdayRef = channel.calls.single.$1.entries
        .firstWhere((e) => e.value == thursdayWake)
        .key;

    await reconcile([
      training(
        exceptions: [
          ExceptionEntry(
            originalStart: DateTime.utc(2026, 9, 17, 15, 30),
            type: ExceptionType.cancelled,
          ),
        ],
      ),
    ], monday);

    expect(channel.calls.last.$2, [thursdayRef]);
  });

  test('a wake shows its reminder once, and only if still owed', () async {
    await reconcile([training()], monday);
    final ref = channel.calls.single.$1.entries
        .firstWhere((e) => e.value == thursdayWake)
        .key;

    Future<DueReminder?> resolve(List<CalendarEvent> events) => scheduler
        .resolve(ref: ref, events: events, memberId: 'maja', now: thursdayWake);

    final cancelled = training(
      exceptions: [
        ExceptionEntry(
          originalStart: DateTime.utc(2026, 9, 17, 15, 30),
          type: ExceptionType.cancelled,
        ),
      ],
    );
    expect(
      await resolve([cancelled]),
      isNull,
      reason: 'cancelled on another phone after the wake was registered',
    );

    final shown = await resolve([training()]);
    expect(shown?.event.title, 'Training');
    expect(await resolve([training()]), isNull, reason: 'never twice');
  });

  test('a wake far too late shows nothing', () async {
    await reconcile([training()], monday);
    final ref = channel.calls.single.$1.entries
        .firstWhere((e) => e.value == thursdayWake)
        .key;

    final late = await scheduler.resolve(
      ref: ref,
      events: [training()],
      memberId: 'maja',
      now: thursdayWake.add(const Duration(hours: 1)),
    );
    expect(late, isNull);
  });
}
