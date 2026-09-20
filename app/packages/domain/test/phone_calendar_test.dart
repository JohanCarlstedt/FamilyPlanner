import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  ImportedEvent read({
    required CalendarDetail detail,
    String? title = 'Client review — Nordea',
  }) => fromPhoneCalendar(
    id: 'work-42',
    title: title,
    localStart: DateTime.utc(2026, 10, 26, 14),
    duration: const Duration(hours: 1),
    detail: detail,
    busyTitle: 'Busy',
    location: 'Advokatbyrån, Stureplan',
    description: 'Bring the Q3 numbers',
  );

  test('a private calendar gives the family the time and nothing else', () {
    final event = read(detail: CalendarDetail.busy);

    expect(event.title, 'Busy');
    // Where and why give away as much as a title does.
    expect(event.location, isNull);
    expect(event.description, isNull);
    expect(event.localStart, DateTime.utc(2026, 10, 26, 14));
    expect(event.duration, const Duration(hours: 1));
  });

  test('a shared calendar comes across as it is', () {
    final event = read(detail: CalendarDetail.full);

    expect(event.title, 'Client review — Nordea');
    expect(event.location, 'Advokatbyrån, Stureplan');
    expect(event.description, 'Bring the Q3 numbers');
  });

  test('an untitled entry is not a blank row in the family calendar', () {
    expect(read(detail: CalendarDetail.full, title: '  ').title, 'Busy');
    expect(read(detail: CalendarDetail.full, title: null).title, 'Busy');
  });

  test('the id is the entry, so a sync does not duplicate it', () {
    expect(read(detail: CalendarDetail.busy).uid, 'work-42');
    expect(read(detail: CalendarDetail.full).uid, 'work-42');
  });
}
