import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/family_repository.dart';
import '../data/store_providers.dart';

/// The family's linked calendar feeds. Only parents' devices can read them.
final calendarLinksProvider =
    StreamProvider<List<(String, CalendarLinkPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchCalendarLinks();
    });

final calendarFeedsProvider = Provider<CalendarFeeds>(
  (ref) => CalendarFeeds(http.Client()),
);

/// Fetches linked feeds straight from their source, on this device: the
/// family's server never learns which team a child plays in.
class CalendarFeeds {
  CalendarFeeds(this._client);

  /// How often a feed is fetched while the app runs. Team schedules change
  /// by the day, not the minute.
  static const every = Duration(hours: 3);

  final http.Client _client;

  /// Fetches the feeds that are due (all of them if [force]). Returns how
  /// many events changed. A feed that fails is skipped until next time.
  Future<int> refresh(
    FamilyStore store, {
    bool force = false,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now().toUtc();
    var changed = 0;
    for (final (id, link) in await store.watchCalendarLinks().first) {
      final key = 'feed.fetched.$id';
      final last = DateTime.tryParse(await store.devicePreference(key) ?? '');
      if (!force && last != null && at.difference(last) < every) continue;
      try {
        changed += await fetch(store, id, link);
        await store.setDevicePreference(key, at.toIso8601String());
      } catch (e) {
        debugPrint('Calendar feed ${link.name} failed: $e');
        if (force) rethrow;
      }
    }
    return changed;
  }

  /// Fetches one feed now and imports what it holds.
  Future<int> fetch(
    FamilyStore store,
    String id,
    CalendarLinkPayload link,
  ) async => store.importFeed(
    linkId: id,
    memberId: link.memberId,
    timeZone: familyTimeZone,
    events: await download(link.url),
  );

  /// The events at [url]. Throws unless it answers with a calendar, so a
  /// wrong link is caught when it's entered; an empty one (off season) is
  /// fine.
  Future<List<ImportedEvent>> download(String url) async {
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (!text.contains('BEGIN:VCALENDAR')) {
      throw const FormatException('not an iCalendar feed');
    }
    return ICalendar.parse(text, timeZone: familyTimeZone);
  }
}
