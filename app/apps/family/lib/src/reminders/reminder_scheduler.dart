import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:domain/domain.dart';

import '../data/store_providers.dart';

/// Where wakes go: the server's scheduler, which pushes through FCM.
abstract interface class WakeChannel {
  Future<void> schedule(Map<String, DateTime> wakes, List<String> cancel);
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

  /// A wake later than this shows nothing: a reminder half an hour late is
  /// noise, not help.
  static const tooLate = Duration(minutes: 30);

  static const _keyPref = 'reminders.key';
  static const _registeredPref = 'reminders.registered';
  static const _shownPref = 'reminders.shown';

  /// Registers what's newly due and cancels what no longer is.
  Future<void> reconcile({
    required List<CalendarEvent> events,
    required String memberId,
    required DateTime now,
  }) async {
    final key = await _key();
    final registered = await _registered();
    // Past wakes have fired or never will; nothing to cancel there.
    registered.removeWhere((_, at) => at.isBefore(now));

    final replan = _ref(key, 'replan');
    final desired = <String, DateTime>{
      for (final r in _planner.plan(
        events: events,
        memberId: memberId,
        from: now,
        until: now.add(horizon),
      ))
        _ref(key, r.key): r.fireAt,
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

  /// The reminder a wake with [ref] stands for, if it's still owed: after the
  /// device has synced, so a cancellation made on another phone since the
  /// wake was registered shows nothing. Each reminder is returned once.
  Future<DueReminder?> resolve({
    required String ref,
    required List<CalendarEvent> events,
    required String memberId,
    required DateTime now,
  }) async {
    final key = await _key();
    final shown = await _shown();
    if (shown.contains(ref)) return null;
    final due = _planner
        .plan(
          events: events,
          memberId: memberId,
          from: now.subtract(tooLate),
          // A push can arrive a little before its time.
          until: now.add(const Duration(minutes: 2)),
        )
        .where((r) => _ref(key, r.key) == ref)
        .firstOrNull;
    if (due == null) return null;

    await _prefs.write(
      _shownPref,
      jsonEncode([...shown.skip(max(0, shown.length - 199)), ref]),
    );
    return due;
  }

  String _ref(List<int> key, String reminderKey) => Hmac(
    sha256,
    key,
  ).convert(utf8.encode(reminderKey)).toString().substring(0, 32);

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
