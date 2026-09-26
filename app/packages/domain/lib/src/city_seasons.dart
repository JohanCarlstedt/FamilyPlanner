/// The town through the year: the season, the family's holidays and the
/// child's birthday, and whatever is falling outside the window. Nothing
/// here changes what the town is, only how it looks on the day.
library;

enum Season { winter, spring, summer, autumn }

/// The season by the month, as a Swedish year has it.
Season seasonOf(DateTime day) => switch (day.month) {
      12 || 1 || 2 => Season.winter,
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      _ => Season.autumn,
    };

/// What is falling in town.
enum Falling { rain, snow }

/// What a MET Norway forecast symbol has falling: rain for rain, showers
/// and thunder, snow for snow and sleet, nothing for the rest.
Falling? fallingOf(String? symbol) {
  if (symbol == null) return null;
  if (symbol.contains('snow') || symbol.contains('sleet')) return Falling.snow;
  if (symbol.contains('rain')) return Falling.rain;
  return null;
}

/// Whether the town lies under snow: through winter unless the forecast
/// has the night well above freezing, and on any day it is snowing.
bool snowOnGround(DateTime day, {double? low, Falling? falling}) {
  if (falling == Falling.snow) return true;
  if (seasonOf(day) != Season.winter) return false;
  return low == null || low <= 2;
}

/// The days the town dresses up for.
enum CityHoliday {
  birthday,
  lucia,
  christmas,
  newYear,
  easter,
  nationalDay,
  midsummer,
  halloween,
}

/// Easter Sunday in [year] (the Gregorian computus, Meeus/Jones/Butcher).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime.utc(year, month, day);
}

/// What [day] (`DateTime.utc` date fields) is in town, if anything. The
/// child's own birthday ([birthday], any year) comes first; one on the
/// 29th of February is kept on the 28th in a common year.
CityHoliday? holidayOn(DateTime day, {DateTime? birthday}) {
  final date = DateTime.utc(day.year, day.month, day.day);
  if (birthday != null) {
    final leap = DateTime.utc(date.year, 2, 29).month == 2;
    final (m, dd) = birthday.month == 2 && birthday.day == 29 && !leap
        ? (2, 28)
        : (birthday.month, birthday.day);
    if (date.month == m && date.day == dd) return CityHoliday.birthday;
  }
  final (month, d) = (date.month, date.day);
  if (month == 12 && d == 13) return CityHoliday.lucia;
  if ((month == 12 && d == 31) || (month == 1 && d == 1)) {
    return CityHoliday.newYear;
  }
  if (month == 12 && d <= 26) return CityHoliday.christmas;
  final easter = easterSunday(date.year);
  final fromEaster = date.difference(easter).inDays;
  if (fromEaster >= -3 && fromEaster <= 1) return CityHoliday.easter;
  if (month == 6 && d == 6) return CityHoliday.nationalDay;
  // Midsummer Eve is the Friday from the 19th to the 25th of June.
  if (month == 6) {
    final eve = [
      for (var x = 19; x <= 25; x++)
        if (DateTime.utc(date.year, 6, x).weekday == DateTime.friday) x,
    ].first;
    if (d == eve || d == eve + 1) return CityHoliday.midsummer;
  }
  if (month == 10 && d == 31) return CityHoliday.halloween;
  return null;
}
