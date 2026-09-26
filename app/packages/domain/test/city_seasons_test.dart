import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// The town through the year: seasons, the family's holidays, the child's
/// birthday, and the weather outside the window.
void main() {
  DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

  group('seasons', () {
    test('by the month, as in Sweden', () {
      expect(seasonOf(d(2026, 1, 10)), Season.winter);
      expect(seasonOf(d(2026, 2, 28)), Season.winter);
      expect(seasonOf(d(2026, 3, 1)), Season.spring);
      expect(seasonOf(d(2026, 6, 1)), Season.summer);
      expect(seasonOf(d(2026, 9, 1)), Season.autumn);
      expect(seasonOf(d(2026, 11, 30)), Season.autumn);
      expect(seasonOf(d(2026, 12, 1)), Season.winter);
    });
  });

  group('snow on the ground', () {
    test('in winter, unless the forecast says it is well above freezing', () {
      expect(snowOnGround(d(2027, 1, 10)), isTrue);
      expect(snowOnGround(d(2027, 1, 10), low: -3), isTrue);
      expect(snowOnGround(d(2027, 1, 10), low: 6), isFalse);
      expect(snowOnGround(d(2026, 7, 10), low: -1), isFalse,
          reason: 'a cold July night is not winter');
    });

    test('a snowy day outside of winter still has it', () {
      expect(snowOnGround(d(2026, 11, 20), falling: Falling.snow), isTrue);
    });
  });

  group('what falls from the sky', () {
    test('read from the forecast symbol', () {
      expect(fallingOf('heavyrain'), Falling.rain);
      expect(fallingOf('lightrainshowers_day'), Falling.rain);
      expect(fallingOf('rainandthunder'), Falling.rain);
      expect(fallingOf('snow'), Falling.snow);
      expect(fallingOf('lightsnowshowers_night'), Falling.snow);
      expect(fallingOf('sleet'), Falling.snow);
      expect(fallingOf('partlycloudy_day'), isNull);
      expect(fallingOf('clearsky_night'), isNull);
      expect(fallingOf(null), isNull);
    });
  });

  group('holidays', () {
    test('Christmas through December, Lucia on the 13th', () {
      expect(holidayOn(d(2026, 11, 30)), isNull);
      expect(holidayOn(d(2026, 12, 1)), CityHoliday.christmas);
      expect(holidayOn(d(2026, 12, 13)), CityHoliday.lucia);
      expect(holidayOn(d(2026, 12, 24)), CityHoliday.christmas);
      expect(holidayOn(d(2026, 12, 26)), CityHoliday.christmas);
      expect(holidayOn(d(2026, 12, 27)), isNull);
    });

    test('New Year: the evening and the day', () {
      expect(holidayOn(d(2026, 12, 31)), CityHoliday.newYear);
      expect(holidayOn(d(2027, 1, 1)), CityHoliday.newYear);
      expect(holidayOn(d(2027, 1, 2)), isNull);
    });

    test('Midsummer: the Friday between the 19th and the 25th of June, '
        'and the day after', () {
      // 2026: Friday 19 June. 2027: Friday 25 June.
      expect(holidayOn(d(2026, 6, 19)), CityHoliday.midsummer);
      expect(holidayOn(d(2026, 6, 20)), CityHoliday.midsummer);
      expect(holidayOn(d(2026, 6, 26)), isNull);
      expect(holidayOn(d(2027, 6, 25)), CityHoliday.midsummer);
      expect(holidayOn(d(2027, 6, 18)), isNull);
    });

    test('the national day, flags out', () {
      expect(holidayOn(d(2026, 6, 6)), CityHoliday.nationalDay);
    });

    test('Easter, from Maundy Thursday to Easter Monday', () {
      // Easter Sunday: 5 April 2026, 28 March 2027.
      expect(easterSunday(2026), d(2026, 4, 5));
      expect(easterSunday(2027), d(2027, 3, 28));
      expect(easterSunday(2025), d(2025, 4, 20));
      expect(holidayOn(d(2026, 4, 2)), CityHoliday.easter);
      expect(holidayOn(d(2026, 4, 6)), CityHoliday.easter);
      expect(holidayOn(d(2026, 4, 7)), isNull);
      expect(holidayOn(d(2026, 4, 1)), isNull);
    });

    test('Halloween', () {
      expect(holidayOn(d(2026, 10, 31)), CityHoliday.halloween);
    });

    test('the child\'s birthday comes before any other day', () {
      final born = d(2016, 12, 13);
      expect(holidayOn(d(2026, 12, 13), birthday: born), CityHoliday.birthday);
      expect(holidayOn(d(2026, 12, 14), birthday: born), CityHoliday.christmas);
    });

    test('a birthday on the 29th of February is kept on the 28th', () {
      final born = d(2016, 2, 29);
      expect(holidayOn(d(2027, 2, 28), birthday: born), CityHoliday.birthday);
      expect(holidayOn(d(2028, 2, 29), birthday: born), CityHoliday.birthday);
      expect(holidayOn(d(2028, 2, 28), birthday: born), isNull);
    });
  });
}
