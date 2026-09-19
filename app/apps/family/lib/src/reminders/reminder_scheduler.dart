import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:domain/domain.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/store_providers.dart';

/// Where wakes go: the server's scheduler, which pushes through FCM.
abstract interface class WakeChannel {
  Future<void> schedule(Map<String, DateTime> wakes, List<String> cancel);
}

/// Everything the planner needs about one member's family.
class ReminderContext {
  const ReminderContext({
    required this.events,
    required this.memberId,
    required this.timeZone,
    this.members = const [],
    this.settings = FamilySettings.defaults,
    this.places = const {},
    this.withDevices = const {},
  });

  final List<CalendarEvent> events;
  final String memberId;
  final String timeZone;
  final List<Member> members;
  final FamilySettings settings;
  final Map<String, Place> places;

  /// Members with an active device; children outside it have their
  /// reminders routed to whoever is responsible.
  final Set<String> withDevices;
}

/// What a wake turned out to stand for, once the device has synced.
sealed class WakeContent {}

/// One or more reminders due together (spec §8: several reminders within
/// ten minutes collapse into one notification).
class DueReminders extends WakeContent {
  DueReminders(this.reminders);
  final List<DueReminder> reminders;
}

/// A test the member asked for, to see reminders reach them.
class TestReminder extends WakeContent {}

/// The morning digest: the member's day.
class Digest extends WakeContent {
  Digest(this.entries);
  final List<AgendaEntry> entries;
}

/// Keeps the server's wakes for this device in step with the reminders its
/// member is owed, and decides what a wake that arrives should show.
///
/// The server sees a time and an opaque reference, nothing else. References
/// are keyed with a secret that never leaves this device: event ids are
/// routing metadata the server already holds, so a plain hash of one would
/// tell it which event is due when.
class ReminderScheduler {
  ReminderScheduler({
    required DevicePreferences preferences,
    required this._channel,
    this._planner = const ReminderPlanner(),
  }) : _prefs = preferences;

  final DevicePreferences _prefs;
  final WakeChannel _channel;
  final ReminderPlanner _planner;

  /// How far ahead wakes are registered. A replan wake before the end keeps
  /// the window rolling when the app isn't opened.
  static const horizon = Duration(days: 7);
  static const replanAfter = Duration(days: 3);

  /// Reminders in the same ten minutes share one wake and one notification.
  static const batch = Duration(minutes: 10);

  /// A wake later than this shows nothing: a reminder half an hour late is
  /// noise, not help.
  static const tooLate = Duration(minutes: 30);

  static const _keyPref = 'reminders.key';
  static const _registeredPref = 'reminders.registered';
  static const _shownPref = 'reminders.shown';

  /// Registers what's newly due and cancels what no longer is.
  Future<void> reconcile(
    ReminderContext context, {
    required DateTime now,
  }) async {
    final key = await _key();
    final registered = await _registered();
    // Past wakes have fired or never will; nothing to cancel there.
    registered.removeWhere((_, at) => at.isBefore(now));

    final replan = _ref(key, 'replan');
    final desired = <String, DateTime>{
      for (final MapEntry(key: bucket, value: due) in _buckets(
        _plan(context, now, now.add(horizon)),
      ).entries)
        _ref(key, 'bucket|${bucket.toIso8601String()}'): due.first.fireAt,
      for (final (day, at) in _digests(context, now, now.add(horizon)))
        _ref(key, 'digest|$day'): at,
      // Kept where it is until it has fired, so reconciling often costs
      // nothing.
      replan: registered[replan] ?? now.add(replanAfter),
    };

    final toSchedule = {
      for (final MapEntry(key: ref, value: at) in desired.entries)
        if (registered[ref] != at) ref: at,
    };
    final toCancel = [
      for (final ref in registered.keys)
        if (!desired.containsKey(ref)) ref,
    ];
    if (toSchedule.isEmpty && toCancel.isEmpty) return;

    await _channel.schedule(toSchedule, toCancel);
    await _prefs.write(
      _registeredPref,
      jsonEncode({
        for (final MapEntry(key: ref, value: at) in desired.entries)
          ref: at.toUtc().toIso8601String(),
      }),
    );
  }

  static const _testPref = 'reminders.test';

  /// Registers a wake a minute from now that shows a test notification: the
  /// whole path a real reminder takes, on demand.
  Future<void> scheduleTest({required DateTime now}) async {
    final key = await _key();
    final ref = _ref(key, 'test|${now.toIso8601String()}');
    await _prefs.write(_testPref, ref);
    await _channel.schedule({
      ref: now.add(const Duration(minutes: 1)),
    }, const []);
  }

  /// What a wake with [ref] stands for, if anything is still owed: after the
  /// device has synced, so a cancellation made on another phone since the
  /// wake was registered shows nothing. Each reminder is shown once.
  Future<WakeContent?> resolve(
    String ref,
    ReminderContext context, {
    required DateTime now,
  }) async {
    final key = await _key();
    final shown = await _shown();
    if (ref == await _prefs.read(_testPref)) {
      await _prefs.write(_testPref, '');
      return TestReminder();
    }

    for (final (day, _) in _digests(
      context,
      now.subtract(tooLate),
      now.add(const Duration(minutes: 2)),
    )) {
      if (_ref(key, 'digest|$day') != ref) continue;
      final id = 'digest|$day';
      if (shown.contains(id)) return null;
      await _markShown(shown, [id]);
      final entries = _today(context, now);
      return entries.isEmpty ? null : Digest(entries);
    }

    // A push can arrive a little before its time, or late.
    final buckets = _buckets(
      _plan(
        context,
        now.subtract(tooLate),
        now.add(batch + const Duration(minutes: 2)),
      ),
    );
    for (final MapEntry(key: bucket, value: due) in buckets.entries) {
      if (_ref(key, 'bucket|${bucket.toIso8601String()}') != ref) continue;
      final fresh = [
        for (final r in due)
          if (!shown.contains(r.key)) r,
      ];
      if (fresh.isEmpty) return null;
      await _markShown(shown, [for (final r in fresh) r.key]);
      return DueReminders(fresh);
    }
    return null;
  }

  List<DueReminder> _plan(ReminderContext c, DateTime from, DateTime until) =>
      _planner.plan(
        events: c.events,
        memberId: c.memberId,
        from: from,
        until: until,
        members: c.members,
        settings: c.settings,
        places: c.places,
        withDevices: c.withDevices,
      );

  /// Reminders grouped by the ten minutes they fall in. Fixed buckets, not
  /// clusters: a bucket is the same whenever it's computed, so a wake's
  /// reference means the same thing when it fires as when it was made.
  static Map<DateTime, List<DueReminder>> _buckets(List<DueReminder> due) {
    final buckets = <DateTime, List<DueReminder>>{};
    for (final r in due) {
      final ms = r.fireAt.millisecondsSinceEpoch;
      final start = DateTime.fromMillisecondsSinceEpoch(
        ms - ms % batch.inMilliseconds,
        isUtc: true,
      );
      (buckets[start] ??= []).add(r);
    }
    return buckets;
  }

  /// Each day's digest time in [from, until), as (yyyy-mm-dd, instant).
  static Iterable<(String, DateTime)> _digests(
    ReminderContext c,
    DateTime from,
    DateTime until,
  ) sync* {
    final at = c.settings.digestAt;
    if (at == null) return;
    final location = tz.getLocation(c.timeZone);
    final first = tz.TZDateTime.from(from, location);
    for (var i = -1; i <= horizon.inDays + 1; i++) {
      final t = tz.TZDateTime(
        location,
        first.year,
        first.month,
        first.day + i,
        0,
        at,
      );
      final instant = DateTime.fromMicrosecondsSinceEpoch(
        t.microsecondsSinceEpoch,
        isUtc: true,
      );
      if (instant.isBefore(from) || !instant.isBefore(until)) continue;
      yield (
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}',
        instant,
      );
    }
  }

  /// The member's own day: their events and the whole family's.
  static List<AgendaEntry> _today(ReminderContext c, DateTime now) {
    final local = tz.TZDateTime.from(now, tz.getLocation(c.timeZone));
    final agenda = const DayAgendaBuilder().build(
      events: c.events,
      members: c.members,
      day: DateTime(local.year, local.month, local.day),
      timeZone: c.timeZone,
      now: now,
    );
    final mine = CalendarFilter.mine(c.memberId);
    return [
      for (final e in agenda.entries)
        if (!e.event.isCancelled && mine.matches(e.event)) e,
    ];
  }

  Future<void> _markShown(List<String> shown, List<String> ids) => _prefs.write(
    _shownPref,
    jsonEncode([
      ...shown.skip(max(0, shown.length + ids.length - 300)),
      ...ids,
    ]),
  );

  String _ref(List<int> key, String name) =>
      Hmac(sha256, key).convert(utf8.encode(name)).toString().substring(0, 32);

  Future<List<int>> _key() async {
    final stored = await _prefs.read(_keyPref);
    if (stored != null) return base64Decode(stored);
    final random = Random.secure();
    final key = [for (var i = 0; i < 32; i++) random.nextInt(256)];
    await _prefs.write(_keyPref, base64Encode(key));
    return key;
  }

  Future<Map<String, DateTime>> _registered() async {
    final raw = await _prefs.read(_registeredPref);
    if (raw == null) return {};
    return {
      for (final MapEntry(key: ref, value: at)
          in (jsonDecode(raw) as Map<String, dynamic>).entries)
        ref: DateTime.parse(at as String),
    };
  }

  Future<List<String>> _shown() async {
    final raw = await _prefs.read(_shownPref);
    return raw == null ? [] : (jsonDecode(raw) as List).cast<String>();
  }
}
