import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// The day's electricity price (spot, per price area), as elprisetjustnu.se
/// publishes it: quarter hours, SEK per kWh, VAT and grid fees not included.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  /// A day of quarter hours at [price] öre, with [cheap] from 03:00 to
  /// 04:00 and [dear] from 18:00 to 19:00, Swedish summer time.
  List<Map<String, Object>> day({
    double price = 100,
    double cheap = 20,
    double dear = 300,
  }) =>
      [
        for (var q = 0; q < 96; q++)
          {
            'SEK_per_kWh': (q ~/ 4 == 3
                    ? cheap
                    : q ~/ 4 == 18
                        ? dear
                        : price) /
                100,
            'time_start': _at(q),
            'time_end': _at(q + 1),
          },
      ];

  test('reads the quarter hours as instants', () {
    final slots = parseSpotPrices(day());
    expect(slots, hasLength(96));
    expect(slots.first.start, DateTime.utc(2026, 9, 23, 22));
    expect(slots.first.end, DateTime.utc(2026, 9, 23, 22, 15));
    expect(slots.first.sekPerKwh, 1.0);
  });

  test('a day: its average, its cheapest hour and its dearest', () {
    final price = dayPrice(
      parseSpotPrices(day()),
      timeZone: 'Europe/Stockholm',
    )!;
    expect(price.day, DateTime.utc(2026, 9, 24));
    expect(price.averageOre, closeTo((22 * 100 + 20 + 300) / 24, 0.01));
    expect(price.cheapestFrom, DateTime.utc(2026, 9, 24, 3));
    expect(price.cheapestOre, closeTo(20, 0.01));
    expect(price.dearestFrom, DateTime.utc(2026, 9, 24, 18));
    expect(price.dearestOre, closeTo(300, 0.01));
  });

  test('the day hour by hour, for the chart', () {
    final price = dayPrice(
      parseSpotPrices(day()),
      timeZone: 'Europe/Stockholm',
    )!;
    expect(price.hours, hasLength(24));
    expect(price.hours.first.$1, DateTime.utc(2026, 9, 24, 0));
    expect(price.hours[3].$2, closeTo(20, 0.01));
    expect(price.hours[18].$2, closeTo(300, 0.01));
    expect(price.hours[12].$2, closeTo(100, 0.01));
  });

  test('a real day from the service, SE3 on 24 September 2026', () {
    final json = jsonDecode(
      File('test/fixtures/elpris-se3-2026-09-24.json').readAsStringSync(),
    ) as List<dynamic>;
    final price = dayPrice(
      parseSpotPrices(json),
      timeZone: 'Europe/Stockholm',
    )!;
    expect(price.day, DateTime.utc(2026, 9, 24));
    expect(price.hours, hasLength(24));
    expect(price.cheapestOre, lessThanOrEqualTo(price.averageOre));
    expect(price.dearestOre, greaterThanOrEqualTo(price.averageOre));
    final cheapestHour =
        price.hours.map((h) => h.$2).reduce((a, b) => a < b ? a : b);
    // The cheapest whole hour may start on a quarter, so it is never dearer
    // than the cheapest clock hour.
    expect(price.cheapestOre, lessThanOrEqualTo(cheapestHour + 0.001));
  });

  test('hourly prices, as the service gave before quarter hours', () {
    final hourly = [
      for (var h = 0; h < 24; h++)
        {
          'SEK_per_kWh': h == 5 ? 0.1 : 1.0,
          'time_start': _at(h * 4),
          'time_end': _at(h * 4 + 4),
        },
    ];
    final price = dayPrice(
      parseSpotPrices(hourly),
      timeZone: 'Europe/Stockholm',
    )!;
    expect(price.cheapestFrom, DateTime.utc(2026, 9, 24, 5));
    expect(price.cheapestOre, closeTo(10, 0.01));
  });

  test('nothing to say about a day with no prices, or broken ones', () {
    expect(dayPrice(const [], timeZone: 'Europe/Stockholm'), isNull);
    expect(
        parseSpotPrices([
          {'SEK_per_kWh': 'lots', 'time_start': 'soon'},
        ]),
        isEmpty);
  });

  test('the price area is a family setting, off until chosen', () {
    expect(FamilySettings.defaults.priceArea, isNull);
    final on = FamilySettings.defaults.copyWith(priceArea: () => PriceArea.se3);
    expect(on.priceArea, PriceArea.se3);
    expect(on.copyWith(jarSize: 4).priceArea, PriceArea.se3);
    expect(on.copyWith(priceArea: () => null).priceArea, isNull);
  });
}

String _at(int quarter) {
  final t = DateTime.utc(2026, 9, 23, 22).add(Duration(minutes: 15 * quarter));
  final local = t.add(const Duration(hours: 2));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}'
      'T${two(local.hour)}:${two(local.minute)}:00+02:00';
}
