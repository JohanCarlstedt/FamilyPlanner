import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// A linked calendar can be one person's or the whole family's.
void main() {
  test('a whole-family link imports for nobody, and still names who linked it',
      () {
    final link = CalendarLinkPayload.write(
      memberId: 'johan',
      name: 'Familjen',
      url: 'https://calendar.google.com/calendar/ical/x/basic.ics',
      forFamily: true,
    );
    expect(link.forFamily, isTrue);
    expect(link.importsFor, isNull);
    // What an older app, which knows no whole family, imports it as.
    expect(link.memberId, 'johan');
  });

  test('a link saved before there was a choice is one person\'s', () {
    final old = CalendarLinkPayload.write(
      memberId: 'maja',
      name: 'Fotboll',
      url: 'https://cal.laget.se/team.ics',
    );
    old.payload.setBoolean('family', null);
    expect(old.forFamily, isFalse);
    expect(old.importsFor, 'maja');
  });
}
