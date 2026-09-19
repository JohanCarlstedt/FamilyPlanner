import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // Saturday 19 September 2026.
  final today = DateTime.utc(2026, 9, 19);
  QuickEvent p(String s, {List<String> places = const []}) =>
      QuickCapture.parse(s, today: today, places: places);

  test('the spec\'s own example', () {
    final e = p(
      'fotboll tisdagar 17:30 på sportshallen till maj',
      places: ['Sportshallen'],
    );
    expect(e.title, 'Fotboll');
    expect(e.localStart, DateTime.utc(2026, 9, 22, 17, 30));
    expect(e.rule?.frequency, Frequency.weekly);
    expect(e.rule?.byWeekday, {Weekday.tu});
    expect(e.rule?.until, DateTime.utc(2027, 5, 31, 23, 59));
    expect(e.place, 'Sportshallen');
  });

  test('English too', () {
    final e = p('Swimming every monday and thursday 18:00-19:15 at the pool');
    expect(e.title, 'Swimming');
    expect(e.rule?.byWeekday, {Weekday.mo, Weekday.th});
    expect(e.localStart, DateTime.utc(2026, 9, 21, 18));
    expect(e.duration, const Duration(minutes: 75));
    expect(e.place, 'the pool');
  });

  test('one-off days: tomorrow, a weekday, a date', () {
    expect(p('tandläkare imorgon kl 9').localStart, DateTime.utc(2026, 9, 20, 9));
    expect(p('tandläkare i morgon 9.15').localStart,
        DateTime.utc(2026, 9, 20, 9, 15));
    expect(p('kalas på fredag 14-16').localStart,
        DateTime.utc(2026, 9, 25, 14));
    expect(p('kalas på fredag 14-16').duration, const Duration(hours: 2));
    expect(p('kalas på fredag 14-16').rule, isNull);
    expect(p('Utvecklingssamtal 12/10 8:30').localStart,
        DateTime.utc(2026, 10, 12, 8, 30));
    expect(p('Cup 3 okt').localStart, DateTime.utc(2026, 10, 3));
    expect(p('Cup 3 okt').allDay, isTrue);
    expect(p('dentist today 16:00').localStart, DateTime.utc(2026, 9, 19, 16));
  });

  test('a date that has passed this year is next year', () {
    expect(p('Julmarknad 5/1').localStart, DateTime.utc(2027, 1, 5));
  });

  test('a known place is found without "på"', () {
    final e = p('Träning Vallen torsdag 18', places: ['Vallen', 'Hallen']);
    expect(e.place, 'Vallen');
    expect(e.title, 'Träning');
  });

  test('nothing but words is a title for today, no time', () {
    final e = p('ring mormor');
    expect(e.title, 'Ring mormor');
    expect(e.localStart, today);
    expect(e.allDay, isTrue);
  });
}
