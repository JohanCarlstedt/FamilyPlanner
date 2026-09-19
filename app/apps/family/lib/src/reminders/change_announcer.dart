import 'dart:convert';
import 'dart:ui';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../common/l10n.dart';
import '../data/store_providers.dart';
import '../features/events/occurrence_editing.dart';
import 'change_detector.dart';

/// Runs when the server's change wake arrives: compares the family's events
/// with what this device last announced, tells its member what matters to
/// them, and remembers the new state.
class ChangeAnnouncer {
  ChangeAnnouncer(this._prefs);

  final DevicePreferences _prefs;

  static const _snapshotPref = 'changes.snapshot';
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> announce({
    required FamilyStore store,
    required String memberId,
    required DateTime now,
  }) async {
    final after = await snapshot(store, now);
    final raw = await _prefs.read(_snapshotPref);
    if (raw != null) {
      final before = {
        for (final MapEntry(:key, :value)
            in (jsonDecode(raw) as Map<String, dynamic>).entries)
          key: EventSnapshot.fromJson(value as Map<String, dynamic>),
      };
      final domain = await _domainEvents(store);
      final changes = const ChangeDetector().detect(
        before: before,
        after: after,
        memberId: memberId,
        now: now,
        nextStart: (id, occurrence) =>
            _nextStart(domain[id], occurrence, now) ?? before[id]?.next,
      );
      for (final change in changes) {
        await _show(
          change,
          after[change.eventId] ?? before[change.eventId]!,
          domain[change.eventId],
          now,
        );
      }
    }
    // The first run only takes stock: nothing was announced before it.
    await _prefs.write(
      _snapshotPref,
      jsonEncode({
        for (final MapEntry(:key, :value) in after.entries) key: value.toJson(),
      }),
    );
  }

  /// Takes stock once, so the first change wake after installing has
  /// something to compare with.
  Future<void> ensureSnapshot(FamilyStore store, DateTime now) async {
    if (await _prefs.read(_snapshotPref) != null) return;
    final current = await snapshot(store, now);
    await _prefs.write(
      _snapshotPref,
      jsonEncode({
        for (final MapEntry(:key, :value) in current.entries)
          key: value.toJson(),
      }),
    );
  }

  /// Every event, deleted and cancelled ones included: a change to "gone" is
  /// the one that matters most.
  static Future<Map<String, EventSnapshot>> snapshot(
    FamilyStore store,
    DateTime now,
  ) async {
    final exceptions = <String, List<EventExceptionPayload>>{};
    for (final (_, x) in await store.watchExceptions().first) {
      (exceptions[x.eventId] ??= []).add(x);
    }
    final domain = await _domainEvents(store);
    return {
      for (final (id, e) in await store.watchEvents().first)
        id: EventSnapshot.of(
          id,
          e,
          exceptions[id] ?? const [],
          next: _nextStart(domain[id], null, now),
        ),
    };
  }

  static Future<Map<String, CalendarEvent>> _domainEvents(
    FamilyStore store,
  ) async {
    final exceptions = <String, List<ExceptionEntry>>{};
    for (final (_, x) in await store.watchExceptions().first) {
      if (x.toDomain() case final entry?) {
        (exceptions[x.eventId] ??= []).add(entry);
      }
    }
    return {
      for (final (id, e) in await store.watchEvents().first)
        if (e.toDomain(id) case final event?)
          id: event.withExceptions(exceptions[id] ?? const []),
    };
  }

  /// When the change bites: the occurrence's own start, or the series' next.
  static DateTime? _nextStart(
    CalendarEvent? event,
    DateTime? occurrence,
    DateTime now,
  ) {
    if (event == null) return occurrence;
    if (occurrence != null) {
      final ex = event.series.exceptions
          .where((x) => x.originalStart == occurrence)
          .firstOrNull;
      return ex?.overrideStart ?? occurrence;
    }
    return const RecurrenceExpander()
        .expand(
          event.series.withExceptions(const []),
          now,
          now.add(const Duration(days: 400)),
        )
        .firstOrNull
        ?.start;
  }

  Future<void> _show(
    EventChange change,
    EventSnapshot snapshot,
    CalendarEvent? event,
    DateTime now,
  ) async {
    final locale = resolveAppLocale(
      PlatformDispatcher.instance.locale,
      appLocales,
    );
    Intl.defaultLocale = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);
    final zone = event?.series.timeZone ?? 'Europe/Stockholm';
    final start =
        _nextStart(event, change.occurrence, now) ?? snapshot.next ?? now;
    final when = DateFormat('EEE d MMM HH:mm').format(wallClock(start, zone));
    final day = DateFormat('EEEE d MMMM')
        .format(wallClock(change.occurrence ?? start, zone));
    final repeats = !snapshot.when.endsWith('|');

    var text = switch (change.kind) {
      ChangeKind.added => l10n.changeAdded(when),
      ChangeKind.cancelled when change.occurrence != null =>
        l10n.changeCancelledOne(day),
      ChangeKind.cancelled => l10n.changeCancelled,
      ChangeKind.moved when change.occurrence != null => l10n.changeMovedOne(
        day,
      ),
      ChangeKind.moved when change.timeChanged && change.placeChanged =>
        l10n.changeTimeAndPlace(when),
      ChangeKind.moved when change.placeChanged => l10n.changePlace(when),
      ChangeKind.moved => l10n.changeTime(when),
      ChangeKind.youAreIn => l10n.changeYouAreIn(when),
      ChangeKind.youAreOut => l10n.changeYouAreOut,
      ChangeKind.youDrive => l10n.changeYouDrive(when),
      ChangeKind.someoneElseDrives => l10n.changeSomeoneElseDrives(when),
    };
    // Spec §8: a change to a repeating event says which occurrences it
    // touched.
    if (repeats &&
        change.occurrence == null &&
        change.kind == ChangeKind.moved) {
      text = l10n.changeEveryTime(text);
    }

    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _notifications.show(
      '${change.eventId}|${change.occurrence}'.hashCode & 0x7fffffff,
      change.title,
      text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'changes',
          l10n.changesChannel,
          channelDescription: l10n.changesChannelDescription,
          importance: change.kind == ChangeKind.cancelled
              ? Importance.high
              : Importance.defaultImportance,
        ),
      ),
    );
  }
}
