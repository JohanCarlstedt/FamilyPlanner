import 'recurrence.dart';

/// What a line of text says about an event.
class QuickEvent {
  const QuickEvent({
    required this.title,
    required this.localStart,
    this.allDay = false,
    this.duration,
    this.rule,
    this.place,
  });

  final String title;

  /// Wall clock, as `DateTime.utc` fields.
  final DateTime localStart;
  final bool allDay;
  final Duration? duration;
  final RecurrenceRule? rule;

  /// A known place's name as the family wrote it, or the words after
  /// "på"/"at".
  final String? place;
}

/// Spec §10 "Quick capture": "fotboll tisdagar 17:30 på sportshallen till
/// maj" as an event, in Swedish or English. Forgiving: whatever isn't a
/// day, time, place or end date is the title, and a line of plain words is
/// an all-day event today.
class QuickCapture {
  QuickCapture._();

  /// Stands in for a part taken out, so the words around it know.
  static const _gap = '§';

  static const _weekdays = {
    'måndag': Weekday.mo,
    'mån': Weekday.mo,
    'monday': Weekday.mo,
    'mon': Weekday.mo,
    'tisdag': Weekday.tu,
    'tis': Weekday.tu,
    'tuesday': Weekday.tu,
    'tue': Weekday.tu,
    'onsdag': Weekday.we,
    'ons': Weekday.we,
    'wednesday': Weekday.we,
    'wed': Weekday.we,
    'torsdag': Weekday.th,
    'tors': Weekday.th,
    'thursday': Weekday.th,
    'thu': Weekday.th,
    'fredag': Weekday.fr,
    'fre': Weekday.fr,
    'friday': Weekday.fr,
    'fri': Weekday.fr,
    'lördag': Weekday.sa,
    'lör': Weekday.sa,
    'saturday': Weekday.sa,
    'sat': Weekday.sa,
    'söndag': Weekday.su,
    'sön': Weekday.su,
    'sunday': Weekday.su,
    'sun': Weekday.su,
  };

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'maj': 5,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'okt': 10,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static const _fillers = {
    'på',
    'at',
    'on',
    'i',
    'kl',
    'kl.',
    'klockan',
    'varje',
    'every',
    'alla',
    'och',
    'and',
    'den',
    'the',
    'från',
    'from',
    'mellan',
    '-',
  };

  static QuickEvent parse(
    String input, {
    required DateTime today,
    List<String> places = const [],
  }) {
    var text = ' ${input.trim().replaceAll(_gap, ' ')} ';
    final day = DateTime.utc(today.year, today.month, today.day);
    void cut(Match m) => text = text.replaceRange(m.start, m.end, ' $_gap ');

    // A place the family knows, wherever it is.
    String? place;
    for (final name in [...places]..sort((a, b) => b.length - a.length)) {
      final m = RegExp(
        '\\s(?:(?:på|at|i)\\s+)?${RegExp.escape(name)}(?=[\\s,.])',
        caseSensitive: false,
      ).firstMatch(text);
      if (m != null) {
        place = name;
        cut(m);
        break;
      }
    }

    // Until: "till maj", "until may", "t.o.m. 15/12".
    DateTime? until;
    final monthWords = _months.keys.join('|');
    if (RegExp(
      '\\s(?:till|until|t\\.o\\.m\\.?|tom)\\s+'
      '(?:(\\d{1,2})/(\\d{1,2})|($monthWords)[a-zé]*)(?=\\s)',
      caseSensitive: false,
    ).firstMatch(text)
        case final m?) {
      if (m.group(3) case final month?) {
        final n = _months[month.toLowerCase()]!;
        final year = n < day.month ? day.year + 1 : day.year;
        until = DateTime.utc(year, n + 1, 0, 23, 59);
      } else {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        var year = day.year;
        if (DateTime.utc(year, mo, d).isBefore(day)) year++;
        until = DateTime.utc(year, mo, d, 23, 59);
      }
      cut(m);
    }

    // A date: "12/10", "3 okt", "den 12 oktober". A date already past this
    // year is next year's.
    DateTime? date;
    DateTime nextOf(int d, int mo) {
      final candidate = DateTime.utc(day.year, mo, d);
      return candidate.isBefore(day)
          ? DateTime.utc(day.year + 1, mo, d)
          : candidate;
    }

    if (RegExp(r'\s(\d{1,2})/(\d{1,2})(?=\s)').firstMatch(text) case final m?) {
      date = nextOf(int.parse(m.group(1)!), int.parse(m.group(2)!));
      cut(m);
    } else if (RegExp(
      '\\s(\\d{1,2})\\s+($monthWords)[a-zé]*(?=\\s)',
      caseSensitive: false,
    ).firstMatch(text)
        case final m?) {
      date = nextOf(
        int.parse(m.group(1)!),
        _months[m.group(2)!.toLowerCase()]!,
      );
      cut(m);
    }

    // Today and tomorrow.
    for (final (pattern, offset) in [
      (r'\s(?:i\s*övermorgon|day after tomorrow)(?=\s)', 2),
      (r'\s(?:i\s*morgon|tomorrow)(?=\s)', 1),
      (r'\s(?:i\s*dag|today|i\s*kväll|tonight)(?=\s)', 0),
    ]) {
      if (RegExp(pattern, caseSensitive: false).firstMatch(text)
          case final m?) {
        date ??= day.add(Duration(days: offset));
        cut(m);
      }
    }

    // Weekdays: plural or "varje"/"every" repeats; a single one is the next.
    final days = <Weekday>{};
    var repeats = false;
    final weekdayWords =
        (_weekdays.keys.toList()..sort((a, b) => b.length - a.length)).join(
      '|',
    );
    final weekday = RegExp(
      '\\s((?:varje|every|alla)\\s+)?($weekdayWords)(ar|s)?(?=[\\s,])',
      caseSensitive: false,
    );
    for (var m = weekday.firstMatch(text);
        m != null;
        m = weekday.firstMatch(text)) {
      days.add(_weekdays[m.group(2)!.toLowerCase()]!);
      if (m.group(1) != null || m.group(3) != null) repeats = true;
      cut(m);
    }

    // Times: "17:30-19:15", "14-16", "kl 9", "9.15", "5pm".
    int? hour;
    int? minute;
    int? endHour;
    int? endMinute;
    final range = RegExp(
      r'\s(?:kl\.?\s*)?(\d{1,2})(?:[:.](\d{2}))?\s*[-–]\s*(\d{1,2})(?:[:.](\d{2}))?(?=\s)',
    ).firstMatch(text);
    if (range != null &&
        int.parse(range.group(1)!) < 24 &&
        int.parse(range.group(3)!) < 24) {
      hour = int.parse(range.group(1)!);
      minute = int.tryParse(range.group(2) ?? '') ?? 0;
      endHour = int.parse(range.group(3)!);
      endMinute = int.tryParse(range.group(4) ?? '') ?? 0;
      cut(range);
    } else {
      final single = RegExp(
        r'\s(kl\.?\s*|klockan\s+|at\s+)?(\d{1,2})(?:([:.])(\d{2}))?\s*(am|pm)?(?=\s)',
        caseSensitive: false,
      );
      for (final m in single.allMatches(text)) {
        var h = int.parse(m.group(2)!);
        // A bare number is a time only beside a day: "torsdag 18".
        final marked =
            m.group(1) != null || m.group(3) != null || m.group(5) != null;
        if (h > 23 || (!marked && days.isEmpty && date == null)) continue;
        if (m.group(5)?.toLowerCase() == 'pm' && h < 12) h += 12;
        hour = h;
        minute = int.tryParse(m.group(4) ?? '') ?? 0;
        cut(m);
        break;
      }
    }

    // "på X" / "at X" up to the next part taken out, or the end.
    if (place == null) {
      final m = RegExp(
        '\\s(?:på|at)\\s+([^$_gap]+?)\\s*(?=$_gap|\$)',
      ).firstMatch(text.trimRight());
      if (m != null && m.group(1)!.trim().isNotEmpty) {
        place = m.group(1)!.trim();
        cut(m);
      }
    }

    // What's left is the title, less the little words that only joined the
    // parts taken out.
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final kept = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w == _gap) continue;
      final nearGap = (i > 0 && words[i - 1] == _gap) ||
          (i + 1 < words.length && words[i + 1] == _gap) ||
          i == words.length - 1;
      if (_fillers.contains(w.toLowerCase()) && nearGap) continue;
      kept.add(w);
    }
    var title = kept.join(' ').replaceAll(RegExp(r'[,\s]+$'), '');
    if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);

    // The first day it happens.
    var start = date ?? day;
    if (date == null && days.isNotEmpty) {
      while (!days.contains(Weekday.values[start.weekday - 1])) {
        start = start.add(const Duration(days: 1));
      }
    }
    Duration? duration;
    if (endHour != null) {
      var d = Duration(
        minutes: endHour * 60 + endMinute! - (hour! * 60 + minute!),
      );
      if (d.isNegative) d += const Duration(days: 1);
      duration = d;
    }
    return QuickEvent(
      title: title,
      localStart: DateTime.utc(
        start.year,
        start.month,
        start.day,
        hour ?? 0,
        minute ?? 0,
      ),
      allDay: hour == null,
      duration: duration,
      rule: days.isNotEmpty && (repeats || until != null)
          ? RecurrenceRule(
              frequency: Frequency.weekly,
              byWeekday: days,
              until: until,
            )
          : null,
      place: place,
    );
  }
}
