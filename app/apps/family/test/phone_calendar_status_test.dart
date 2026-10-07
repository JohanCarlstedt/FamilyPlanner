import 'dart:convert';

import 'package:family/src/data/store_providers.dart';
import 'package:family/src/integrations/phone_calendars.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the phone's calendars screen says about each chosen calendar: an
/// import that found nothing or failed used to look exactly like one that
/// never ran.
void main() {
  test('a reading is kept, and read back, per calendar', () async {
    final prefs = MemoryPreferences();
    final at = DateTime.utc(2026, 10, 7, 12, 30);
    await prefs.write(
      'calendars.phone.status',
      jsonEncode({
        '7': PhoneCalendarStatus(at: at, found: 23, changed: 2).toJson(),
        '9': PhoneCalendarStatus(at: at, error: 'denied').toJson(),
      }),
    );
    final status = await PhoneCalendars(android: true).status(prefs);
    expect(status['7']!.found, 23);
    expect(status['7']!.changed, 2);
    expect(status['7']!.error, isNull);
    expect(status['9']!.error, 'denied');
    expect(status['9']!.at, at);
  });

  test('nothing read yet, or something unreadable, is no status', () async {
    final prefs = MemoryPreferences();
    expect(await PhoneCalendars(android: true).status(prefs), isEmpty);
    await prefs.write('calendars.phone.status', 'not json');
    expect(await PhoneCalendars(android: true).status(prefs), isEmpty);
  });
}
