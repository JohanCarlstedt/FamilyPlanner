import 'package:timezone/timezone.dart' as tz;

import 'location.dart';

/// One day's weather, as a week view needs it: how cold, how warm, what it
/// looks like, and how much falls out of the sky.
class DayWeather {
  const DayWeather({
    required this.day,
    required this.low,
    required this.high,
    required this.symbol,
    required this.millimetres,
  });

  /// The local day, as `DateTime.utc` date fields, like the rest of the app.
  final DateTime day;
  final double low;
  final double high;

  /// The forecast's own symbol name (`rain`, `partlycloudy_day`, …), left
  /// as it comes so the UI can pick an icon and a newer name still works.
  final String symbol;
  final double millimetres;
}

/// Coordinates as a weather service gets them: about a kilometre, never the
/// street. It is one more party that would otherwise learn where a family
/// is standing, and a blurred position answers the question just as well.
GeoPoint blurForWeather(GeoPoint at) => GeoPoint(
      (at.lat * 100).round() / 100,
      (at.lng * 100).round() / 100,
    );

/// Reads a MET Norway `locationforecast/2.0/compact` body into days in
/// [timeZone], dropping days that are already over at [from].
///
/// Anything unexpected in the body yields no days rather than an error: a
/// forecast is a nicety, and the week must still open.
List<DayWeather> parseForecast(
  Map<String, dynamic> body, {
  required String timeZone,
  DateTime? from,
}) {
  final series = switch (body['properties']) {
    {'timeseries': final List<dynamic> series} => series,
    _ => const [],
  };
  if (series.isEmpty) return const [];

  final location = tz.getLocation(timeZone);
  final since = from?.toUtc();
  final temperatures = <DateTime, List<double>>{};
  final rain = <DateTime, double>{};
  final symbols = <DateTime, ({Duration fromNoon, String symbol})>{};

  for (final entry in series) {
    if (entry is! Map<String, dynamic>) continue;
    final at = DateTime.tryParse('${entry['time']}')?.toUtc();
    final data = entry['data'];
    if (at == null || data is! Map<String, dynamic>) continue;

    final local = tz.TZDateTime.from(at, location);
    final day = DateTime.utc(local.year, local.month, local.day);
    if (since != null) {
      final endOfDay = tz.TZDateTime(
        location,
        local.year,
        local.month,
        local.day,
      ).add(const Duration(days: 1));
      if (!endOfDay.toUtc().isAfter(since)) continue;
    }

    if (_number(data, const ['instant', 'details', 'air_temperature'])
        case final temperature?) {
      (temperatures[day] ??= []).add(temperature);
    }

    // The hourly window where there is one, the six-hourly where there
    // isn't: they don't overlap, so nothing is counted twice.
    final window =
        data.containsKey('next_1_hours') ? 'next_1_hours' : 'next_6_hours';
    if (_number(data, [window, 'details', 'precipitation_amount'])
        case final fell?) {
      rain[day] = (rain[day] ?? 0) + fell;
    }

    final symbol = _text(data, [window, 'summary', 'symbol_code']) ??
        _text(data, const ['next_12_hours', 'summary', 'symbol_code']);
    if (symbol != null && !symbol.endsWith('_night')) {
      // Midday says what the day was like; dawn and dusk mislead.
      final noon =
          tz.TZDateTime(location, local.year, local.month, local.day, 12);
      final distance = local.difference(noon).abs();
      final held = symbols[day];
      if (held == null || distance < held.fromNoon) {
        symbols[day] = (fromNoon: distance, symbol: symbol);
      }
    }
  }

  final days = [
    for (final day in temperatures.keys.toList()..sort())
      if (temperatures[day]!.isNotEmpty)
        DayWeather(
          day: day,
          low: temperatures[day]!.reduce((a, b) => a < b ? a : b),
          high: temperatures[day]!.reduce((a, b) => a > b ? a : b),
          symbol: symbols[day]?.symbol ?? '',
          millimetres: rain[day] ?? 0,
        ),
  ];
  return days;
}

double? _number(Map<String, dynamic> from, List<String> path) =>
    switch (_at(from, path)) {
      final num value => value.toDouble(),
      _ => null,
    };

String? _text(Map<String, dynamic> from, List<String> path) =>
    switch (_at(from, path)) {
      final String value when value.isNotEmpty => value,
      _ => null,
    };

Object? _at(Map<String, dynamic> from, List<String> path) {
  Object? here = from;
  for (final step in path) {
    if (here is! Map) return null;
    here = here[step];
  }
  return here;
}
