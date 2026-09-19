import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';
import 'recurrence.dart';

/// One event read from an iCalendar feed (RFC 5545), in this app's terms:
/// wall-clock time in the family's zone (CLAUDE.md invariant 4).
class ImportedEvent {
  const ImportedEvent({
    required this.uid,
    required this.sequence,
    required this.title,
    required this.localStart,
    required this.duration,
    this.allDay = false,
    this.location,
    this.description,
    this.categories = const [],
    this.cancelled = false,
    this.rule,
  });

  /// The feed's own id: the same event across fetches.
  final String uid;

  /// Bumped by the feed each time the event changes.
  final int sequence;
  final String title;

  /// Wall-clock start in the family's zone, as `DateTime.utc` fields.
  final DateTime localStart;
  final Duration duration;
  final bool allDay;
  final String? location;
  final String? description;
  final List<String> categories;
  final bool cancelled;

  /// A repeat this app can expand faithfully, or null.
  final RecurrenceRule? rule;

  /// How long before the start to be there, from a meeting time in the
  /// notes: laget.se writes "Samlingstid" and the date and time. Null
  /// unless it falls on the same day, up to four hours before.
  int? get meetMinutesBefore {
    final match = _meeting.firstMatch(description ?? '');
    if (match == null) return null;
    final date = match.group(1);
    if (date != null) {
      final day =
          DateTime.utc(localStart.year, localStart.month, localStart.day);
      if (DateTime.tryParse('${date}T00:00:00Z') != day) return null;
    }
    final at = DateTime.utc(
      localStart.year,
      localStart.month,
      localStart.day,
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    final minutes = localStart.difference(at).inMinutes;
    return minutes > 0 && minutes <= 240 ? minutes : null;
  }

  static final _meeting = RegExp(
    r'Samling(?:stid)?\s*:?\s*(?:(\d{4}-\d{2}-\d{2})\s+)?(\d{1,2})[:.](\d{2})',
    caseSensitive: false,
  );
}

/// Reads iCalendar feeds: enough of RFC 5545 for club, school and shared
/// calendars. Forgiving: a malformed event is skipped, never the feed.
class ICalendar {
  ICalendar._();

  /// Windows zone names some feeds use (laget.se's ical.net among them),
  /// mapped to an IANA zone with the same rules.
  static const _windowsZones = {
    'W. Europe Standard Time': 'Europe/Berlin',
    'Central Europe Standard Time': 'Europe/Budapest',
    'Central European Standard Time': 'Europe/Warsaw',
    'Romance Standard Time': 'Europe/Paris',
    'GMT Standard Time': 'Europe/London',
    'FLE Standard Time': 'Europe/Helsinki',
    'E. Europe Standard Time': 'Europe/Chisinau',
    'UTC': 'UTC',
  };

  /// "Träning - Landvetter IF 2003 F-2015" in the calendar "F-2015" is
  /// "Träning": the team is already who the calendar is for. Titles naming
  /// anyone else ("Match Örgryte - Landvetter IF 2003 A") stay whole.
  static String _shortTitle(String title, String? calendarName) {
    if (calendarName == null) return title;
    final dash = title.lastIndexOf(' - ');
    if (dash <= 0 || !title.endsWith(calendarName)) return title;
    return title.substring(0, dash).trim();
  }

  /// [events] as an iCalendar feed named [name], for another calendar app
  /// to read: times in each event's own zone, repeats as RRULE, cancelled
  /// occurrences as EXDATE. Changed single occurrences go out as the series
  /// has them.
  static String write(List<CalendarEvent> events, {required String name}) {
    final out = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Family Planner//EN',
      'CALSCALE:GREGORIAN',
      'X-WR-CALNAME:${_escape(name)}',
    ];
    String local(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}'
        'T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';
    for (final e in events) {
      final s = e.series;
      out
        ..add('BEGIN:VEVENT')
        ..add('UID:${s.eventId}@familyplanner')
        ..add('DTSTART;TZID=${s.timeZone}:${local(s.localStart)}')
        ..add('DURATION:PT${s.duration.inMinutes}M')
        ..add('SUMMARY:${_escape(e.title)}');
      if (e.location case final l? when l.isNotEmpty) {
        out.add('LOCATION:${_escape(l)}');
      }
      if (e.isCancelled) out.add('STATUS:CANCELLED');
      if (s.rule case final r?) {
        out.add('RRULE:${[
          'FREQ=${r.frequency.name.toUpperCase()}',
          if (r.interval != 1) 'INTERVAL=${r.interval}',
          if (r.byWeekday.isNotEmpty)
            'BYDAY=${[
              for (final d in Weekday.values)
                if (r.byWeekday.contains(d)) d.name.toUpperCase(),
            ].join(',')}',
          if (r.byMonthDay case final d?) 'BYMONTHDAY=$d',
          if (r.byMonth case final m?) 'BYMONTH=$m',
          if (r.until case final u?)
            'UNTIL=${local(tz.TZDateTime(tz.getLocation(s.timeZone), u.year, u.month, u.day, u.hour, u.minute).toUtc())}Z',
          if (r.count case final c?) 'COUNT=$c',
        ].join(';')}');
      }
      for (final x in s.exceptions) {
        if (x.type == ExceptionType.cancelled) {
          out.add('EXDATE:${local(x.originalStart.toUtc())}Z');
        }
      }
      out.add('END:VEVENT');
    }
    out.add('END:VCALENDAR');
    return '${out.map(_fold).join('\r\n')}\r\n';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  /// RFC 5545 §3.1: at most 75 octets a line, continued with a space.
  static String _fold(String line) {
    final parts = <String>[];
    var current = StringBuffer();
    var octets = 0;
    for (final rune in line.runes) {
      final size = rune < 0x80
          ? 1
          : rune < 0x800
              ? 2
              : rune < 0x10000
                  ? 3
                  : 4;
      final limit = parts.isEmpty ? 75 : 74;
      if (octets + size > limit) {
        parts.add(current.toString());
        current = StringBuffer();
        octets = 0;
      }
      current.writeCharCode(rune);
      octets += size;
    }
    parts.add(current.toString());
    return parts.join('\r\n ');
  }

  /// Every event in [text], with times on [timeZone]'s wall clock.
  static List<ImportedEvent> parse(String text, {required String timeZone}) {
    final lines = _unfold(text);
    if (!lines.any((l) => l.name == 'BEGIN' && l.value == 'VCALENDAR')) {
      return const [];
    }
    final target = tz.getLocation(timeZone);
    final calendarZone = lines
        .where((l) => l.name == 'X-WR-TIMEZONE')
        .map((l) => _location(l.value))
        .whereType<tz.Location>()
        .firstOrNull;
    final calendarName = lines
        .where((l) => l.name == 'X-WR-CALNAME')
        .map((l) => _unescape(l.value).trim())
        .where((n) => n.isNotEmpty)
        .firstOrNull;

    final events = <ImportedEvent>[];
    var depth = 0;
    Map<String, _Line>? current;
    List<String>? categories;
    for (final line in lines) {
      if (line.name == 'BEGIN') {
        if (line.value == 'VEVENT' && depth == 0) {
          current = {};
          categories = [];
        } else if (current != null) {
          depth++;
        }
        continue;
      }
      if (line.name == 'END') {
        if (depth > 0) {
          depth--;
        } else if (line.value == 'VEVENT' && current != null) {
          final event = _event(
            current,
            categories!,
            target,
            calendarZone,
            calendarName,
          );
          if (event != null) events.add(event);
          current = null;
        }
        continue;
      }
      // Properties of nested components (alarms) aren't the event's.
      if (current == null || depth > 0) continue;
      if (line.name == 'CATEGORIES') {
        categories!.addAll(
          _splitList(line.value).map(_unescape).where((c) => c.isNotEmpty),
        );
      } else {
        current.putIfAbsent(line.name, () => line);
      }
    }
    return events;
  }

  static ImportedEvent? _event(
    Map<String, _Line> p,
    List<String> categories,
    tz.Location target,
    tz.Location? calendarZone,
    String? calendarName,
  ) {
    final uid = p['UID']?.value;
    final dtStart = p['DTSTART'];
    // A changed single instance of a series: this app's own exceptions
    // can't be fed from outside yet, so the series stands as it was.
    if (uid == null || dtStart == null || p.containsKey('RECURRENCE-ID')) {
      return null;
    }
    final start = _time(dtStart, target, calendarZone);
    if (start == null) return null;

    Duration duration;
    if (p['DTEND'] case final end?) {
      final endTime = _time(end, target, calendarZone);
      duration = endTime == null
          ? const Duration(hours: 1)
          : endTime.wall.difference(start.wall);
    } else if (p['DURATION'] case final d?) {
      duration = _duration(d.value) ?? const Duration(hours: 1);
    } else {
      duration =
          start.allDay ? const Duration(days: 1) : const Duration(hours: 1);
    }
    if (duration.isNegative) duration = Duration.zero;

    return ImportedEvent(
      uid: uid,
      sequence: int.tryParse(p['SEQUENCE']?.value ?? '') ?? 0,
      title: _shortTitle(_unescape(p['SUMMARY']?.value ?? ''), calendarName),
      localStart: start.wall,
      duration: duration,
      allDay: start.allDay,
      location: switch (p['LOCATION']?.value) {
        final l? when l.trim().isNotEmpty => _unescape(l),
        _ => null,
      },
      description: switch (p['DESCRIPTION']?.value) {
        final d? when d.trim().isNotEmpty => _unescape(d),
        _ => null,
      },
      categories: categories,
      cancelled: p['STATUS']?.value.toUpperCase() == 'CANCELLED',
      rule: switch (p['RRULE']) {
        final r? => _rule(r.value, target, calendarZone),
        null => null,
      },
    );
  }

  /// A time as the family's wall clock.
  static ({DateTime wall, bool allDay})? _time(
    _Line line,
    tz.Location target,
    tz.Location? calendarZone,
  ) {
    final v = line.value.trim();
    final date = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(v);
    if (date != null) {
      return (
        wall: DateTime.utc(
          int.parse(date[1]!),
          int.parse(date[2]!),
          int.parse(date[3]!),
        ),
        allDay: true,
      );
    }
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$')
        .firstMatch(v);
    if (m == null) return null;
    int f(int i) => int.parse(m[i]!);
    final DateTime instant;
    if (m[7] == 'Z') {
      instant = DateTime.utc(f(1), f(2), f(3), f(4), f(5), f(6));
    } else {
      // Named zone, else the calendar's own, else floating: the family's.
      final zone = _location(line.params['TZID']) ?? calendarZone ?? target;
      final t = tz.TZDateTime(zone, f(1), f(2), f(3), f(4), f(5), f(6));
      instant = DateTime.fromMicrosecondsSinceEpoch(
        t.microsecondsSinceEpoch,
        isUtc: true,
      );
    }
    final wall = tz.TZDateTime.from(instant, target);
    return (
      wall: DateTime.utc(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
        wall.second,
      ),
      allDay: false,
    );
  }

  static tz.Location? _location(String? name) {
    if (name == null) return null;
    final iana =
        _windowsZones[name.replaceAll('"', '')] ?? name.replaceAll('"', '');
    try {
      return tz.getLocation(iana);
    } on Object {
      return null;
    }
  }

  /// FREQ, INTERVAL, BYDAY (plain days), BYMONTHDAY, BYMONTH, UNTIL, COUNT.
  /// Anything more (BYSETPOS, "2nd Tuesday") can't be expanded faithfully
  /// here, so the event comes in once rather than wrong.
  static RecurrenceRule? _rule(
    String value,
    tz.Location target,
    tz.Location? calendarZone,
  ) {
    final parts = {
      for (final kv in value.split(';'))
        if (kv.contains('='))
          kv.substring(0, kv.indexOf('=')).toUpperCase(): kv.substring(
            kv.indexOf('=') + 1,
          ),
    };
    const supported = {
      'FREQ',
      'INTERVAL',
      'BYDAY',
      'BYMONTHDAY',
      'BYMONTH',
      'UNTIL',
      'COUNT',
      'WKST',
    };
    if (parts.keys.any((k) => !supported.contains(k))) return null;
    final frequency = switch (parts['FREQ']) {
      'DAILY' => Frequency.daily,
      'WEEKLY' => Frequency.weekly,
      'MONTHLY' => Frequency.monthly,
      'YEARLY' => Frequency.yearly,
      _ => null,
    };
    if (frequency == null) return null;
    final days = <Weekday>{};
    for (final d
        in (parts['BYDAY'] ?? '').split(',').where((d) => d.isNotEmpty)) {
      final day = Weekday.values
          .where((w) => w.name.toUpperCase() == d.toUpperCase())
          .firstOrNull;
      if (day == null) return null;
      days.add(day);
    }
    if (days.isNotEmpty && frequency != Frequency.weekly) return null;
    DateTime? until;
    if (parts['UNTIL'] case final u?) {
      until = _time(_Line('UNTIL', const {}, u), target, calendarZone)?.wall;
      if (until == null) return null;
    }
    return RecurrenceRule(
      frequency: frequency,
      interval: int.tryParse(parts['INTERVAL'] ?? '') ?? 1,
      byWeekday: days,
      byMonthDay: int.tryParse(parts['BYMONTHDAY'] ?? ''),
      byMonth: int.tryParse(parts['BYMONTH'] ?? ''),
      until: until,
      count: int.tryParse(parts['COUNT'] ?? ''),
    );
  }

  static Duration? _duration(String v) {
    final m = RegExp(
      r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    ).firstMatch(v.trim());
    if (m == null) return null;
    int f(int i) => int.tryParse(m[i] ?? '') ?? 0;
    return Duration(
      days: f(2) * 7 + f(3),
      hours: f(4),
      minutes: f(5),
      seconds: f(6),
    );
  }

  /// RFC 5545 §3.1: a line beginning with a space or tab continues the one
  /// before, less that character.
  static List<_Line> _unfold(String text) {
    final raw = text.split(RegExp(r'\r\n|\n|\r'));
    final joined = <String>[];
    for (final line in raw) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          joined.isNotEmpty) {
        joined[joined.length - 1] += line.substring(1);
      } else if (line.isNotEmpty) {
        joined.add(line);
      }
    }
    return [for (final l in joined) _Line.parse(l)].whereType<_Line>().toList();
  }

  /// Splits on commas that aren't escaped.
  static List<String> _splitList(String value) =>
      value.split(RegExp(r'(?<!\\),'));

  static String _unescape(String v) => v.replaceAllMapped(
        RegExp(r'\\([\;,nN])'),
        (m) => switch (m[1]) {
          'n' || 'N' => '\n',
          final c => c!,
        },
      );
}

class _Line {
  const _Line(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;

  /// `NAME;PARAM=value;PARAM="quoted:value":VALUE`
  static _Line? parse(String line) {
    var inQuotes = false;
    var colon = -1;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') inQuotes = !inQuotes;
      if (c == ':' && !inQuotes) {
        colon = i;
        break;
      }
    }
    if (colon < 0) return null;
    final head = line.substring(0, colon).split(';');
    return _Line(
      head.first.toUpperCase(),
      {
        for (final p in head.skip(1))
          if (p.contains('='))
            p.substring(0, p.indexOf('=')).toUpperCase(): p.substring(
              p.indexOf('=') + 1,
            ),
      },
      line.substring(colon + 1),
    );
  }
}
