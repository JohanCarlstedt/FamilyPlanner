import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final forecast =
      jsonDecode(File('test/fixtures/met-forecast.json').readAsStringSync())
          as Map<String, dynamic>;

  test('a week of days, in the family\'s zone', () {
    final days = parseForecast(forecast, timeZone: 'Europe/Stockholm');

    expect(days.first.day, DateTime.utc(2026, 9, 20));
    expect(days.length, greaterThanOrEqualTo(8));
    // 06:00Z on the 20th is 08:00 in Stockholm, so the day is partial; the
    // days after it are whole.
    final whole = days[1];
    expect(whole.day, DateTime.utc(2026, 9, 21));
    expect(whole.low, lessThanOrEqualTo(whole.high));
    expect(whole.high - whole.low, lessThan(25), reason: 'a day, not a year');
    expect(whole.symbol, isNotEmpty);
    expect(whole.millimetres, greaterThanOrEqualTo(0));
  });

  test('a day hour by hour, for the sheet behind a tap', () {
    final days = parseForecast(forecast, timeZone: 'Europe/Stockholm');
    final tomorrow = days[1];
    // Hourly while MET has hours (about two and a half days ahead).
    expect(tomorrow.hours, hasLength(24));
    expect(tomorrow.hours.first.at, DateTime.utc(2026, 9, 21, 0));
    expect(tomorrow.hours.last.at, DateTime.utc(2026, 9, 21, 23));
    for (final h in tomorrow.hours) {
      expect(h.step, const Duration(hours: 1));
      expect(h.temperature, inInclusiveRange(tomorrow.low, tomorrow.high));
      expect(h.symbol, isNotEmpty);
    }
    // The hours hold all of the day's rain, and nothing extra.
    expect(
      tomorrow.hours.fold<double>(0, (sum, h) => sum + h.millimetres),
      closeTo(tomorrow.millimetres, 0.001),
    );
  });

  test('further ahead, six-hour steps: what MET has', () {
    final days = parseForecast(forecast, timeZone: 'Europe/Stockholm');
    final later = days.last;
    expect(later.hours, isNotEmpty);
    expect(later.hours.first.step, const Duration(hours: 6));
    expect(later.hours.length, lessThanOrEqualTo(4));
  });

  test('rain is counted once, not once per overlapping window', () {
    final days = parseForecast(forecast, timeZone: 'Europe/Stockholm');
    // Each entry contributes at most its own hour (or its own six), so a
    // day can't total more than its hours of rain.
    for (final day in days) {
      expect(day.millimetres, lessThan(200));
    }
  });

  test('the day\'s symbol comes from the middle of it', () {
    final days = parseForecast(forecast, timeZone: 'Europe/Stockholm');
    // Never a night symbol for a day summary.
    for (final day in days) {
      expect(day.symbol, isNot(contains('_night')));
    }
  });

  test('what is already over is left out', () {
    final days = parseForecast(
      forecast,
      timeZone: 'Europe/Stockholm',
      from: DateTime.utc(2026, 9, 23, 10),
    );
    expect(days.first.day, DateTime.utc(2026, 9, 23));
  });

  test('a position is blurred before it is sent to a weather service', () {
    // Two phones in the same part of town ask the same question.
    expect(
      blurForWeather(const GeoPoint(57.6893214, 11.9752119)),
      blurForWeather(const GeoPoint(57.6871, 11.9789)),
    );
    expect(
      blurForWeather(const GeoPoint(57.6893214, 11.9752119)),
      const GeoPoint(57.69, 11.98),
    );
    expect(
      distanceMeters(
        blurForWeather(const GeoPoint(57.6893214, 11.9752119)),
        const GeoPoint(57.6893214, 11.9752119),
      ),
      lessThan(1500),
    );
  });

  test('nonsense is no forecast, not a crash', () {
    expect(parseForecast(const {}, timeZone: 'Europe/Stockholm'), isEmpty);
    expect(
      parseForecast(const {
        'properties': {'timeseries': 'no'},
      }, timeZone: 'Europe/Stockholm'),
      isEmpty,
    );
  });
}
