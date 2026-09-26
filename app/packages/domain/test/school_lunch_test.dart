import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const feed = '''
<rss version="2.0"><channel>
<item><title>Måndag - Vecka 39</title><description>Ingen meny för idag</description>
<pubDate>Mon, 21 Sep 2026 00:00:00 GMT</pubDate></item>
<item><title>Fredag - Vecka 39</title><description><![CDATA[Kalvfärslimpa med grönpepparsås och kokt potatis, <br/>Veg: Vegofärslimpa med grönpepparsås &amp; potatis]]></description>
<pubDate>Fri, 25 Sep 2026 00:00:00 GMT</pubDate></item>
</channel></rss>''';

  test('a week\'s lunches by day, a day with none left out', () {
    final week = parseSchoolLunch(feed);
    expect(week.keys, [DateTime.utc(2026, 9, 25)]);
    expect(week[DateTime.utc(2026, 9, 25)], [
      'Kalvfärslimpa med grönpepparsås och kokt potatis',
      'Veg: Vegofärslimpa med grönpepparsås & potatis',
    ]);
  });

  test('anything that is not a feed gives nothing', () {
    expect(parseSchoolLunch('Error generating RSS feed'), isEmpty);
  });

  test('the school from however its address was pasted', () {
    for (final input in [
      'https://skolmaten.se/engelbrektsskolan-stockholm',
      'skolmaten.se/engelbrektsskolan-stockholm/',
      ' Engelbrektsskolan-Stockholm ',
      'https://www.skolmaten.se/engelbrektsskolan-stockholm?x=1',
    ]) {
      expect(skolmatenSchool(input), 'engelbrektsskolan-stockholm', reason: input);
    }
    expect(skolmatenSchool('https://example.com/a b'), isNull);
    expect(skolmatenSchool(''), isNull);
    expect(
      schoolLunchFeed('engelbrektsskolan-stockholm').toString(),
      'https://skolmaten.se/api/4/rss/week/engelbrektsskolan-stockholm?locale=sv',
    );
  });
}
