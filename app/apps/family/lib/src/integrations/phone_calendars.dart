import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_calendar/device_calendar.dart' as plugin;
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/store_providers.dart';

final phoneCalendarsProvider = Provider<PhoneCalendars>(
  (ref) => PhoneCalendars(),
);

/// Calendars the phone already syncs — Google, Outlook, iCloud, a work
/// account — read straight off the device.
///
/// This is the whole integration: no OAuth client to register, no refresh
/// tokens to keep, nothing told to Google or Microsoft about this family.
/// The phone did the syncing; the app reads what is already there
/// (docs/calendars.md).
///
/// Which calendars, and in how much detail, is a choice per device, because
/// the calendars themselves are: Anna's phone cannot see the accounts on
/// yours. The choice lives in device preferences, never synced.
class PhoneCalendars {
  PhoneCalendars({plugin.DeviceCalendarPlugin? calendars, bool? android})
    : _plugin = calendars ?? plugin.DeviceCalendarPlugin(),
      _android = android ?? Platform.isAndroid;

  final plugin.DeviceCalendarPlugin _plugin;

  /// On Android the app reads through its own channel: the plugin refuses
  /// every call there without WRITE_CALENDAR, and this app only reads.
  final bool _android;
  static const _reader = MethodChannel('family/phone_calendars');

  static const _preference = 'calendars.phone';

  /// Which of the chosen calendars are the whole family's rather than
  /// this phone's owner's: a list of calendar ids, beside the choices
  /// above so a phone that chose before this existed reads as before.
  static const _familyPreference = 'calendars.phone.family';

  /// How far back and forward entries are taken. Far enough to be useful,
  /// short enough that a decade of someone's work calendar never lands in
  /// the family's.
  static const past = Duration(days: 14);
  static const ahead = Duration(days: 120);

  /// Asks for permission, once, and says whether it was given. Without it
  /// nothing here works and the screen says so rather than failing quietly.
  Future<bool> ask() async {
    if (_android) {
      try {
        return await _reader.invokeMethod<bool>('ask') ?? false;
      } on MissingPluginException {
        // Woken in the background, with no screen to ask on.
        return false;
      }
    }
    final granted = await _plugin.hasPermissions();
    if (granted.isSuccess && granted.data == true) return true;
    final asked = await _plugin.requestPermissions();
    return asked.isSuccess && asked.data == true;
  }

  /// The calendars on this phone, whether or not the family sees them.
  Future<List<PhoneCalendar>> available() async {
    if (_android) {
      final rows =
          await _reader.invokeListMethod<Map<Object?, Object?>>('calendars') ??
          const [];
      return [
        for (final r in rows)
          PhoneCalendar(
            id: r['id']! as String,
            name: (r['name'] as String?) ?? r['id']! as String,
            account: r['account'] as String?,
            readOnly: (r['readOnly'] as bool?) ?? false,
          ),
      ];
    }
    final result = await _plugin.retrieveCalendars();
    return [
      for (final c in result.data ?? const <plugin.Calendar>[])
        if (c.id case final id?)
          PhoneCalendar(
            id: id,
            name: c.name ?? id,
            account: c.accountName,
            readOnly: c.isReadOnly ?? false,
          ),
    ];
  }

  /// What the family sees of this phone's calendars, by calendar id.
  Future<Map<String, CalendarDetail>> chosen(DevicePreferences prefs) async {
    final raw = await prefs.read(_preference);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key:
              CalendarDetail.values.asNameMap()[e.value as String] ??
              CalendarDetail.busy,
      };
    } on Object {
      return const {};
    }
  }

  /// The chosen calendars that are the whole family's.
  Future<Set<String>> forFamily(DevicePreferences prefs) async {
    final raw = await prefs.read(_familyPreference);
    if (raw == null) return const {};
    try {
      return {for (final id in jsonDecode(raw) as List<dynamic>) id as String};
    } on Object {
      return const {};
    }
  }

  /// Records which calendars are the whole family's. The next import
  /// moves their events over: named nobody, or back to this phone's
  /// owner.
  Future<void> chooseFamily(DevicePreferences prefs, Set<String> ids) =>
      prefs.write(_familyPreference, jsonEncode(ids.toList()));

  /// Records which of this phone's calendars the family sees, and takes
  /// back the events of any that has just been un-ticked.
  ///
  /// [store] is not optional on purpose. Un-ticking a calendar used to do
  /// nothing but stop fetching it, so everything it had ever imported
  /// stayed in the family's calendar with no way to remove it — the
  /// events outlived the decision that brought them in, which is the one
  /// thing an import must never do.
  Future<void> choose(
    DevicePreferences prefs,
    Map<String, CalendarDetail> calendars, {
    required FamilyStore store,
  }) async {
    final before = await chosen(prefs);
    await prefs.write(
      _preference,
      jsonEncode({for (final e in calendars.entries) e.key: e.value.name}),
    );
    for (final id in before.keys) {
      if (calendars.containsKey(id)) continue;
      await store.withdrawFeed('phone/$id');
    }
  }

  /// Imports the chosen calendars into the family's, as [memberId].
  ///
  /// Returns how many events changed. Entries go through the same import as
  /// a subscribed feed, so an event the family deleted stays deleted and one
  /// that disappears from the phone is cancelled rather than vanishing.
  Future<int> refresh(
    FamilyStore store,
    DevicePreferences prefs, {
    required String memberId,
    required String timeZone,
    required String busyTitle,
    DateTime? now,
  }) async {
    final calendars = await chosen(prefs);
    if (calendars.isEmpty) return 0;
    final family = await forFamily(prefs);
    if (!await ask()) return 0;

    final at = now ?? DateTime.now().toUtc();
    final location = tz.getLocation(timeZone);
    var changed = 0;

    for (final entry in calendars.entries) {
      final found = await _events(entry.key, at.subtract(past), at.add(ahead));
      if (found == null) continue;

      final events = <ImportedEvent>[];
      for (final e in found) {
        // Instants in; the family's calendar travels as wall-clock fields
        // in the family's zone (CLAUDE.md invariant 4). An all-day entry
        // is a date, which Android keeps as midnight UTC: read in the
        // family's zone it would start at two in the morning.
        final local = e.allDay
            ? e.start.toUtc()
            : tz.TZDateTime.from(e.start, location);
        events.add(
          fromPhoneCalendar(
            id: e.id,
            title: e.title,
            localStart: DateTime.utc(
              local.year,
              local.month,
              local.day,
              e.allDay ? 0 : local.hour,
              e.allDay ? 0 : local.minute,
            ),
            duration: e.end.difference(e.start),
            allDay: e.allDay,
            location: e.location,
            description: e.description,
            detail: entry.value,
            busyTitle: busyTitle,
          ),
        );
      }

      changed += await store.importFeed(
        // The same shape a feed link uses, so one phone's calendar is one
        // source and the ids stay stable across syncs.
        linkId: 'phone/${entry.key}',
        memberId: family.contains(entry.key) ? null : memberId,
        timeZone: timeZone,
        events: events,
        now: at,
      );
    }
    return changed;
  }
}

typedef _PhoneEvent = ({
  String id,
  DateTime start,
  DateTime end,
  String? title,
  bool allDay,
  String? location,
  String? description,
});

extension on PhoneCalendars {
  /// One calendar's entries in [from, until), or null if the phone would
  /// not say.
  Future<List<_PhoneEvent>?> _events(
    String calendar,
    DateTime from,
    DateTime until,
  ) async {
    if (_android) {
      final List<Map<Object?, Object?>>? rows;
      try {
        rows = await PhoneCalendars._reader
            .invokeListMethod<Map<Object?, Object?>>('events', {
              'calendar': calendar,
              'from': from.millisecondsSinceEpoch,
              'until': until.millisecondsSinceEpoch,
            });
      } on MissingPluginException {
        return null;
      }
      return [
        for (final r in rows ?? const <Map<Object?, Object?>>[])
          (
            id: r['id']! as String,
            start: DateTime.fromMillisecondsSinceEpoch(
              r['begin']! as int,
              isUtc: true,
            ),
            end: DateTime.fromMillisecondsSinceEpoch(
              r['end']! as int,
              isUtc: true,
            ),
            title: r['title'] as String?,
            allDay: (r['allDay'] as bool?) ?? false,
            location: r['location'] as String?,
            description: r['description'] as String?,
          ),
      ];
    }
    final found = await _plugin.retrieveEvents(
      calendar,
      plugin.RetrieveEventsParams(startDate: from, endDate: until),
    );
    if (!found.isSuccess) return null;
    return [
      for (final e in found.data ?? const <plugin.Event>[])
        if ((e.eventId, e.start) case (final id?, final start?))
          (
            id: id,
            start: start,
            end: e.end ?? start.add(const Duration(hours: 1)),
            title: e.title,
            allDay: e.allDay ?? false,
            location: e.location,
            description: e.description,
          ),
    ];
  }
}

/// A calendar as the phone describes it.
class PhoneCalendar {
  const PhoneCalendar({
    required this.id,
    required this.name,
    this.account,
    this.readOnly = false,
  });

  final String id;
  final String name;

  /// Which account it came from, which is how someone tells two calendars
  /// called "Calendar" apart.
  final String? account;
  final bool readOnly;
}
