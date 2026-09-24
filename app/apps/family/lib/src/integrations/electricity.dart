import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/family_repository.dart';
import '../data/store_providers.dart';

final electricityProvider = Provider<Electricity>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return Electricity(client);
});

/// A day's electricity price in the family's price area, or null: the
/// family has not switched it on, the day is past tomorrow (published
/// around 13:00 the day before), or the service could not be reached.
///
/// Keyed on the wall-clock date, `DateTime.utc` fields (invariant 4).
final dayPriceProvider = FutureProvider.family<DayPrice?, DateTime>((
  ref,
  date,
) async {
  final area = ref.watch(settingsProvider).value?.priceArea;
  if (area == null) return null;
  final repository = await ref.watch(familyRepositoryProvider.future);
  return ref
      .watch(electricityProvider)
      .forDay(
        area,
        date,
        timeZone: repository.timeZone,
        preferences: await ref.watch(devicePreferencesProvider.future),
      );
});

/// Spot prices from elprisetjustnu.se: free, open, no key, fetched by the
/// phone like the weather, so the server learns nothing and the service
/// only which of Sweden's four price areas the family is in.
///
/// A day that has been fetched is kept for good: a published price never
/// changes. One that is not out yet is asked about again after half an
/// hour, not on every repaint of the week.
class Electricity {
  Electricity(this._client);

  final http.Client _client;
  static const _agent =
      'FamilyPlanner/1.0 (github.com/johancarlstedt/family-planner)';
  static const _retry = Duration(minutes: 30);

  Future<DayPrice?> forDay(
    PriceArea area,
    DateTime date, {
    required String timeZone,
    required DevicePreferences preferences,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now().toUtc();
    // Nothing is published past tomorrow; asking would only be refused.
    final tomorrow = DateTime.utc(moment.year, moment.month, moment.day + 1);
    if (date.isAfter(tomorrow)) return null;

    String two(int n) => n.toString().padLeft(2, '0');
    final name = '${date.year}/${two(date.month)}-${two(date.day)}';
    final key = 'electricity.${area.name}.$name';
    final missKey = 'electricity.miss.${area.name}.$name';

    List<dynamic>? body;
    try {
      final held = await preferences.read(key);
      if (held != null) body = jsonDecode(held) as List<dynamic>;
    } on Object {
      body = null;
    }
    if (body == null) {
      final missed = DateTime.tryParse(await preferences.read(missKey) ?? '');
      if (missed != null && moment.difference(missed) < _retry) return null;
      try {
        final response = await _client
            .get(
              Uri.https(
                'www.elprisetjustnu.se',
                '/api/v1/prices/$name'
                    '_${area.name.toUpperCase()}.json',
              ),
              headers: const {'User-Agent': _agent},
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          await preferences.write(missKey, moment.toIso8601String());
          return null;
        }
        body = jsonDecode(response.body) as List<dynamic>;
        await preferences.write(key, response.body);
      } on Object catch (e) {
        debugPrint('No electricity price: $e');
        await preferences.write(missKey, moment.toIso8601String());
        return null;
      }
    }
    return dayPrice(parseSpotPrices(body), timeZone: timeZone);
  }
}
