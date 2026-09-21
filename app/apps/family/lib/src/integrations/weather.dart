import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../location/location_providers.dart';
import '../membership/membership.dart';

/// Where the week's weather is for: where this phone last said it was, or
/// home. Nothing is asked of the phone for the sake of a forecast — if the
/// family shares no position and has marked no home, there is no weather.
final weatherPlaceProvider = Provider<GeoPoint?>((ref) {
  final me = ref.watch(membershipProvider).value?.memberId;
  final mine = ref.watch(positionsProvider).value?[me]?.position?.point;
  if (mine != null) return blurForWeather(mine);

  // Falling back to home covered a parent, whose phone is usually sharing
  // a position anyway, and left the children with no weather at all: they
  // share nothing, so everything rested on home having been pinned, which
  // is a setup step nobody is made to do.
  //
  // Any place the family has marked will do. They are places — home,
  // school, the sports hall — not people, so this tells a child nothing
  // about where anyone is, and a town's forecast is a town's forecast.
  final places = ref.watch(placesProvider).value ?? const <Place>[];
  final somewhere =
      places.where((p) => p.isHome && p.location != null).firstOrNull ??
      places.where((p) => p.location != null).firstOrNull;
  return somewhere == null ? null : blurForWeather(somewhere.location!);
});

/// The week's weather, by day. Empty when there's nowhere to ask about or
/// nothing to ask with.
final weekWeatherProvider = FutureProvider<Map<DateTime, DayWeather>>((
  ref,
) async {
  final at = ref.watch(weatherPlaceProvider);
  if (at == null) return const {};
  final repository = await ref.watch(familyRepositoryProvider.future);
  final forecast = ref.watch(weatherProvider);
  final days = await forecast.forDays(
    at,
    timeZone: repository.timeZone,
    preferences: await ref.watch(devicePreferencesProvider.future),
  );
  return {for (final day in days) day.day: day};
});

final weatherProvider = Provider<Weather>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return Weather(client);
});

/// The forecast for a place, from MET Norway's free service, fetched by
/// this phone (spec §3: the family's server learns nothing about where
/// anyone is). The position is blurred to about a kilometre first, and the
/// answer is kept for an hour so a week that's opened often asks once.
class Weather {
  Weather(this._client);

  /// MET asks for a real identity rather than a browser's, so they can get
  /// in touch about a misbehaving client instead of blocking it.
  static const _agent =
      'FamilyPlanner/1.0 (github.com/johancarlstedt/family-planner)';
  static const _every = Duration(hours: 1);
  static const _key = 'weather.forecast';

  final http.Client _client;

  Future<List<DayWeather>> forDays(
    GeoPoint at, {
    required String timeZone,
    required DevicePreferences preferences,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now().toUtc();
    final held = await _held(preferences);
    if (held != null &&
        held.at == '${at.lat},${at.lng}' &&
        moment.difference(held.fetched) < _every) {
      return parseForecast(held.body, timeZone: timeZone, from: moment);
    }
    try {
      final response = await _client
          .get(
            Uri.https(
              'api.met.no',
              '/weatherapi/locationforecast/2.0/compact',
              {'lat': at.lat.toString(), 'lon': at.lng.toString()},
            ),
            headers: const {'User-Agent': _agent},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw http.ClientException('weather ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      await preferences.write(
        _key,
        jsonEncode({
          'at': '${at.lat},${at.lng}',
          'fetched': moment.toIso8601String(),
          'body': body,
        }),
      );
      return parseForecast(body, timeZone: timeZone, from: moment);
    } on Object catch (e) {
      // Offline, or the service is having a day: yesterday's answer is
      // better than none, and no answer is better than an error.
      debugPrint('No fresh weather: $e');
      return held == null
          ? const []
          : parseForecast(held.body, timeZone: timeZone, from: moment);
    }
  }

  Future<({String at, DateTime fetched, Map<String, dynamic> body})?> _held(
    DevicePreferences preferences,
  ) async {
    try {
      final raw = await preferences.read(_key);
      if (raw == null) return null;
      final held = jsonDecode(raw) as Map<String, dynamic>;
      final fetched = DateTime.tryParse('${held['fetched']}');
      if (fetched == null) return null;
      return (
        at: '${held['at']}',
        fetched: fetched.toUtc(),
        body: held['body'] as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}
