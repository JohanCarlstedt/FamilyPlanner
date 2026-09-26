/// School lunch from Skolmaten: each school's week as a public RSS feed,
/// fetched on the phone (nothing about the family goes anywhere).
library;

/// The feed for [school]'s current week, in Swedish.
Uri schoolLunchFeed(String school) =>
    Uri.https('skolmaten.se', '/api/4/rss/week/$school', {'locale': 'sv'});

/// The school's name in a Skolmaten address, however it was pasted:
/// `https://skolmaten.se/engelbrektsskolan-stockholm`, without the
/// scheme, or just the name. Null when it is not one.
String? skolmatenSchool(String input) {
  var text = input.trim().toLowerCase();
  text = text.replaceFirst(RegExp(r'^https?://'), '');
  text = text.replaceFirst(RegExp(r'^(www\.)?skolmaten\.se/'), '');
  text = text.split(RegExp(r'[/?#]')).first;
  return RegExp(r'^[a-z0-9][a-z0-9-]{1,99}$').hasMatch(text) ? text : null;
}

/// The dishes on each day in a Skolmaten week feed, by date (as
/// `DateTime.utc` date fields). A day with no menu is left out; a feed
/// that is not one gives nothing.
Map<DateTime, List<String>> parseSchoolLunch(String xml) {
  final out = <DateTime, List<String>>{};
  for (final item in RegExp(r'<item>([\s\S]*?)</item>').allMatches(xml)) {
    final body = item.group(1)!;
    final date = RegExp(r'<pubDate>([^<]+)</pubDate>').firstMatch(body);
    final text = RegExp(r'<description>([\s\S]*?)</description>')
        .firstMatch(body);
    if (date == null || text == null) continue;
    final day = _rfc822Day(date.group(1)!);
    if (day == null) continue;
    final raw = text
        .group(1)!
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '');
    final dishes = [
      for (final line in raw.split(RegExp(r'<br\s*/?>', caseSensitive: false)))
        if (_clean(line) case final dish
            when dish.isNotEmpty && !dish.toLowerCase().startsWith('ingen meny'))
          dish,
    ];
    if (dishes.isNotEmpty) out[day] = dishes;
  }
  return out;
}

String _clean(String line) => line
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .replaceFirst(RegExp(r',$'), '');

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// "Mon, 21 Sep 2026 00:00:00 GMT" as its date.
DateTime? _rfc822Day(String text) {
  final m = RegExp(r'(\d{1,2}) ([A-Za-z]{3}) (\d{4})').firstMatch(text);
  if (m == null) return null;
  final month = _months[m.group(2)!.toLowerCase()];
  if (month == null) return null;
  return DateTime.utc(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
}
