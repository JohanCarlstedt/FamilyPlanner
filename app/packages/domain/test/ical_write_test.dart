import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  const zone = 'Europe/Stockholm';

  final training = CalendarEvent(
    series: EventSeries(
      eventId: 'e1',
      localStart: DateTime.utc(2026, 9, 21, 17, 30),
      duration: const Duration(minutes: 90),
      timeZone: zone,
      rule: RecurrenceRule(
        frequency: Frequency.weekly,
        byWeekday: const {Weekday.mo, Weekday.we},
        until: DateTime.utc(2026, 12, 16, 23, 59),
      ),
      exceptions: [
        ExceptionEntry(
          // 17:30 Stockholm on 23 September is 15:30 UTC.
          originalStart: DateTime.utc(2026, 9, 23, 15, 30),
          type: ExceptionType.cancelled,
        ),
      ],
    ),
    title: 'Fotboll; träning, grupp 2',
    kind: EventKind.activity,
    location: 'Sportshallen',
  );
  final dentist = CalendarEvent(
    series: EventSeries(
      eventId: 'e2',
      localStart: DateTime.utc(2026, 10, 1, 9),
      duration: const Duration(minutes: 45),
      timeZone: zone,
    ),
    title: 'Tandläkare',
    kind: EventKind.appointment,
    status: EventStatus.cancelled,
  );

  test('what it writes reads back the same', () {
    final text = ICalendar.write([training, dentist], name: 'Maja');
    final back = ICalendar.parse(text, timeZone: zone);
    expect(back, hasLength(2));
    final t = back.firstWhere((e) => e.uid.startsWith('e1'));
    expect(t.title, 'Fotboll; träning, grupp 2');
    expect(t.localStart, DateTime.utc(2026, 9, 21, 17, 30));
    expect(t.duration, const Duration(minutes: 90));
    expect(t.location, 'Sportshallen');
    expect(t.rule?.frequency, Frequency.weekly);
    expect(t.rule?.byWeekday, {Weekday.mo, Weekday.we});
    expect(t.cancelled, isFalse);
    final d = back.firstWhere((e) => e.uid.startsWith('e2'));
    expect(d.cancelled, isTrue);
    expect(d.rule, isNull);
  });

  test('a cancelled occurrence is an EXDATE; lines stay within 75 octets', () {
    final long = CalendarEvent(
      series: training.series,
      title: 'Å' * 60,
      kind: EventKind.activity,
    );
    final text = ICalendar.write([long], name: 'Maja');
    expect(text, contains('EXDATE:20260923T153000Z'));
    expect(text, contains('X-WR-CALNAME:Maja'));
    for (final line in text.split('\r\n')) {
      expect(_octets(line), lessThanOrEqualTo(75));
    }
    expect(ICalendar.parse(text, timeZone: zone).single.title, 'Å' * 60);
  });
}

int _octets(String s) => s.runes.fold(
      0,
      (n, r) =>
          n +
          (r < 0x80
              ? 1
              : r < 0x800
                  ? 2
                  : r < 0x10000
                      ? 3
                      : 4),
    );
