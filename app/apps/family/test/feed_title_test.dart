import 'package:domain/domain.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// A subscribed calendar's events take the calendar's own name.
///
/// A club's feed titles every session "Träning". With three children on
/// three feeds the week reads "Träning · Träning · Träning" and says
/// nothing about whose or what — while the one label that does say, the
/// name the family gave the calendar when they linked it, was shown
/// nowhere at all.
void main() {
  CalendarEvent event({String title = 'Träning'}) => CalendarEvent(
    title: title,
    kind: EventKind.activity,
    series: EventSeries(
      eventId: 'e',
      localStart: DateTime.utc(2026, 9, 24, 17),
      duration: const Duration(hours: 1),
      timeZone: 'Europe/Stockholm',
    ),
    participantIds: const ['maja'],
    location: 'Hallen',
  );

  test('a feed event is shown under the calendar it came from', () {
    expect(titledByFeed(event(), 'Maja fotboll').title, 'Maja fotboll');
  });

  test('and keeps everything else about itself', () {
    final shown = titledByFeed(event(), 'Maja fotboll');
    expect(shown.location, 'Hallen');
    expect(shown.participantIds, ['maja']);
    expect(shown.series.localStart, DateTime.utc(2026, 9, 24, 17));
  });

  test('an event from no feed is untouched', () {
    expect(titledByFeed(event(title: 'Tandläkare'), null).title, 'Tandläkare');
  });

  test('a calendar with no name changes nothing', () {
    // Better the feed's own word than a blank line on the week.
    expect(titledByFeed(event(), '').title, 'Träning');
  });

  test('a calendar named the same as its events costs nothing', () {
    final original = event(title: 'Fotboll');
    expect(identical(titledByFeed(original, 'Fotboll'), original), isTrue);
  });
}
