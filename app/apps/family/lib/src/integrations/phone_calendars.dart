import 'dart:convert';

import 'package:device_calendar/device_calendar.dart' as plugin;
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
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
  PhoneCalendars({plugin.DeviceCalendarPlugin? calendars})
    : _plugin = calendars ?? plugin.DeviceCalendarPlugin();

  final plugin.DeviceCalendarPlugin _plugin;

  static const _preference = 'calendars.phone';

  /// How far back and forward entries are taken. Far enough to be useful,
  /// short enough that a decade of someone's work calendar never lands in
  /// the family's.
  static const past = Duration(days: 14);
  static const ahead = Duration(days: 120);

  /// Asks for permission, once, and says whether it was given. Without it
  /// nothing here works and the screen says so rather than failing quietly.
  Future<bool> ask() async {
    final granted = await _plugin.hasPermissions();
    if (granted.isSuccess && granted.data == true) return true;
    final asked = await _plugin.requestPermissions();
    return asked.isSuccess && asked.data == true;
  }

  /// The calendars on this phone, whether or not the family sees them.
  Future<List<PhoneCalendar>> available() async {
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

  Future<void> choose(
    DevicePreferences prefs,
    Map<String, CalendarDetail> calendars,
  ) => prefs.write(
    _preference,
    jsonEncode({for (final e in calendars.entries) e.key: e.value.name}),
  );

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
    if (!await ask()) return 0;

    final at = now ?? DateTime.now().toUtc();
    final location = tz.getLocation(timeZone);
    var changed = 0;

    for (final entry in calendars.entries) {
      final found = await _plugin.retrieveEvents(
        entry.key,
        plugin.RetrieveEventsParams(
          startDate: at.subtract(past),
          endDate: at.add(ahead),
        ),
      );
      if (!found.isSuccess) continue;

      final events = <ImportedEvent>[];
      for (final e in found.data ?? const <plugin.Event>[]) {
        final id = e.eventId;
        final start = e.start;
        if (id == null || start == null) continue;
        final end = e.end ?? start.add(const Duration(hours: 1));
        // The plugin hands back instants; the family's calendar travels as
        // wall-clock fields in the family's zone (CLAUDE.md invariant 4).
        final local = tz.TZDateTime.from(start, location);
        events.add(
          fromPhoneCalendar(
            id: id,
            title: e.title,
            localStart: DateTime.utc(
              local.year,
              local.month,
              local.day,
              local.hour,
              local.minute,
            ),
            duration: end.difference(start),
            allDay: e.allDay ?? false,
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
        memberId: memberId,
        timeZone: timeZone,
        events: events,
        now: at,
      );
    }
    return changed;
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
