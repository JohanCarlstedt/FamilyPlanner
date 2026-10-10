import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// A family's shared calendar, told apart by its name on the phone.
void main() {
  test('Google and iCloud family calendars, in Swedish and English', () {
    for (final name in [
      'Family',
      'Familj',
      'Familjen',
      'Familjen Svensson',
      'Our family',
      'Svenssons familjekalender',
    ]) {
      expect(looksLikeFamilyCalendar(name), isTrue, reason: name);
    }
  });

  test('a person\'s or a work calendar is not one', () {
    for (final name in [
      'johan@gmail.com',
      'Arbete',
      'Helgdagar i Sverige',
      'Birthdays',
      'Fotboll P13',
    ]) {
      expect(looksLikeFamilyCalendar(name), isFalse, reason: name);
    }
  });
}
