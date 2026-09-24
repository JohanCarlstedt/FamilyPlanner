/// The day's electricity price in the calendar (a family setting, off
/// until a parent picks a price area).
///
/// Nord Pool's spot price for a Swedish price area, as elprisetjustnu.se
/// publishes it: free, no key, no account, and fetched by a phone like the
/// weather, so all anyone learns is which of four areas the family is in.
/// Spot only: VAT, the grid fee and the supplier's surcharge are not in it.
library;

import 'package:timezone/timezone.dart' as tz;

/// Sweden's four price areas, north to south.
enum PriceArea { se1, se2, se3, se4 }

/// One stretch at one price: a quarter hour now, an hour before 1 October
/// 2025. Instants, UTC.
class PriceSlot {
  const PriceSlot({
    required this.start,
    required this.end,
    required this.sekPerKwh,
  });

  final DateTime start;
  final DateTime end;
  final double sekPerKwh;

  Duration get length => end.difference(start);
}

/// The service's JSON, as slots. Anything unreadable is left out rather
/// than guessed at.
List<PriceSlot> parseSpotPrices(List<dynamic> json) => [
      for (final e in json)
        if (e
            case {
              'SEK_per_kWh': final num price,
              'time_start': final String from,
              'time_end': final String until,
            })
          if ((DateTime.tryParse(from), DateTime.tryParse(until))
              case (final start?, final end?) when end.isAfter(start))
            PriceSlot(
              start: start.toUtc(),
              end: end.toUtc(),
              sekPerKwh: price.toDouble(),
            ),
    ];

/// A day's price, in öre per kWh: what the calendar shows, and what is
/// behind a tap on it.
class DayPrice {
  const DayPrice({
    required this.day,
    required this.averageOre,
    required this.cheapestFrom,
    required this.cheapestOre,
    required this.dearestFrom,
    required this.dearestOre,
    required this.hours,
  });

  /// The date, as `DateTime.utc` fields (invariant 4).
  final DateTime day;

  /// Averaged over the day's time, not over its slots: a price that holds
  /// for an hour counts four times a quarter hour's.
  final double averageOre;

  /// The cheapest whole hour and the dearest, from when (wall clock), and
  /// what they average: when to run the dishwasher, and when not to.
  final DateTime cheapestFrom;
  final double cheapestOre;
  final DateTime dearestFrom;
  final double dearestOre;

  /// Each clock hour of the day (wall clock) and its average, for the
  /// chart behind a tap: 24 of them, 23 on the day the clocks go forward.
  /// The hour that happens twice in October is one bar, both halves in it.
  final List<(DateTime, double)> hours;
}

/// The day [slots] cover, summed up in [timeZone]. Null for no prices.
DayPrice? dayPrice(List<PriceSlot> slots, {required String timeZone}) {
  if (slots.isEmpty) return null;
  final sorted = [...slots]..sort((a, b) => a.start.compareTo(b.start));
  final location = tz.getLocation(timeZone);
  DateTime wall(DateTime at) {
    final l = tz.TZDateTime.from(at, location);
    return DateTime.utc(l.year, l.month, l.day, l.hour, l.minute);
  }

  var total = 0.0;
  var minutes = 0;
  for (final s in sorted) {
    total += s.sekPerKwh * s.length.inMinutes;
    minutes += s.length.inMinutes;
  }

  // Every whole hour that starts on a slot, averaged the same way.
  final hours = <(DateTime, double)>[];
  for (var i = 0; i < sorted.length; i++) {
    var sum = 0.0;
    var covered = 0;
    for (var j = i; j < sorted.length && covered < 60; j++) {
      final take = sorted[j].length.inMinutes.clamp(0, 60 - covered);
      sum += sorted[j].sekPerKwh * take;
      covered += take;
    }
    if (covered == 60) hours.add((sorted[i].start, sum / 60));
  }
  if (hours.isEmpty) hours.add((sorted.first.start, total / minutes));
  final cheapest = hours.reduce((a, b) => b.$2 < a.$2 ? b : a);
  final dearest = hours.reduce((a, b) => b.$2 > a.$2 ? b : a);

  // Clock hours, by where each slot starts in the family's zone.
  final byHour = <DateTime, (double, int)>{};
  for (final s in sorted) {
    final w = wall(s.start);
    final hour = DateTime.utc(w.year, w.month, w.day, w.hour);
    final (sum, mins) = byHour[hour] ?? (0.0, 0);
    byHour[hour] = (
      sum + s.sekPerKwh * s.length.inMinutes,
      mins + s.length.inMinutes,
    );
  }

  final first = wall(sorted.first.start);
  return DayPrice(
    day: DateTime.utc(first.year, first.month, first.day),
    averageOre: total / minutes * 100,
    cheapestFrom: wall(cheapest.$1),
    cheapestOre: cheapest.$2 * 100,
    dearestFrom: wall(dearest.$1),
    dearestOre: dearest.$2 * 100,
    hours: [
      for (final MapEntry(key: hour, value: (sum, mins)) in byHour.entries)
        (hour, sum / mins * 100),
    ],
  );
}
