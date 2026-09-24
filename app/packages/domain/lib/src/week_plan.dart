import 'package:timezone/timezone.dart' as tz;

import 'homework.dart';
import 'week_number.dart';

/// One cell's worth of homework from a school's week overview.
class WeekPlanEntry {
  const WeekPlanEntry({
    required this.group,
    required this.title,
    required this.dueAt,
    this.subject,
    this.type = HomeworkType.assignment,
  });

  /// The row it came from: a class, "5A". Which one is the family's is
  /// theirs to say — a school publishes every class in one document.
  final String group;

  final String title;

  /// Wall-clock date, from the column it sat under.
  final DateTime? dueAt;

  final String? subject;
  final HomeworkType type;
}

/// The classes a week overview covers, in the order the document has them.
List<String> classesIn(List<List<String>> table) {
  final header = _headerRow(table);
  if (header == null) return const [];
  return [
    for (final row in table.skip(header + 1))
      if (row.isNotEmpty && row.first.trim().isNotEmpty) row.first.trim(),
  ];
}

/// Reads a school's week overview — the veckoöversikt that arrives as a
/// Word document — into homework for someone to confirm.
///
/// These are tables, not letters: a header row naming the weekdays, often
/// with only Monday dated, and a row per class. A cell holds a day's
/// homework for that class, frequently several subjects at once
/// ("Sv: Läsuppdrag och veckans ord Eng: glosor").
///
/// Everything here is a guess about someone else's formatting, so it
/// proposes and a person decides. What it will not do is invent a date: a
/// column it cannot place leaves the homework dateless rather than
/// wrongly dated.
List<WeekPlanEntry> readWeekPlan(
  List<List<String>> table, {
  required String timeZone,
  DateTime? now,
}) {
  final header = _headerRow(table);
  if (header == null) return const [];
  final days = _columnDates(table[header], timeZone: timeZone, now: now);

  final entries = <WeekPlanEntry>[];
  for (final row in table.skip(header + 1)) {
    if (row.isEmpty) continue;
    final group = row.first.trim();
    if (group.isEmpty) continue;
    for (var column = 1; column < row.length; column++) {
      final cell = row[column].trim();
      if (cell.isEmpty || _isDayOff(cell)) continue;
      for (final piece in _splitBySubject(cell)) {
        // A week overview carries school news in the same cells —
        // "Utvecklingssamtalsdag 0810-1300", a vaccination time, an outing.
        // Without a subject in front of it and without a word that means
        // homework, it is something to read, not something to do.
        if (piece.subject == null && !_soundsLikeHomework(piece.text)) {
          continue;
        }
        entries.add(
          WeekPlanEntry(
            group: group,
            title: piece.text,
            subject: piece.subject,
            type: _typeOf(piece.text),
            dueAt: days[column],
          ),
        );
      }
    }
  }
  return entries;
}

/// The row naming the weekdays. Anything above it is a title or a link.
int? _headerRow(List<List<String>> table) {
  for (final (i, row) in table.indexed) {
    final named = row.where((c) => _weekdayIn(c) != null).length;
    // Three is enough to be the header and not a sentence mentioning a day.
    if (named >= 3) return i;
  }
  return null;
}

const _weekdays = {
  'måndag': DateTime.monday,
  'monday': DateTime.monday,
  'tisdag': DateTime.tuesday,
  'tuesday': DateTime.tuesday,
  'onsdag': DateTime.wednesday,
  'wednesday': DateTime.wednesday,
  'torsdag': DateTime.thursday,
  'thursday': DateTime.thursday,
  'fredag': DateTime.friday,
  'friday': DateTime.friday,
  'lördag': DateTime.saturday,
  'saturday': DateTime.saturday,
  'söndag': DateTime.sunday,
  'sunday': DateTime.sunday,
};

int? _weekdayIn(String cell) {
  final lower = cell.toLowerCase();
  for (final entry in _weekdays.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

/// A date per column, worked out from whatever the header gives: a date in
/// the cell, a week number in the corner, or the weekday counted from a
/// column that did have a date.
Map<int, DateTime> _columnDates(
  List<String> header, {
  required String timeZone,
  DateTime? now,
}) {
  final weekdays = <int, int>{};
  final dated = <int, DateTime>{};

  for (final (column, cell) in header.indexed) {
    final weekday = _weekdayIn(cell);
    if (weekday == null) continue;
    weekdays[column] = weekday;
    final slash = RegExp(r'\b(\d{1,2})\s*/\s*(\d{1,2})\b').firstMatch(cell);
    if (slash == null) continue;
    final day = int.parse(slash.group(1)!);
    final month = int.parse(slash.group(2)!);
    dated[column] =
        DateTime.utc(_yearFor(month, day, timeZone, now), month, day);
  }

  // A Monday elsewhere in the row fixes the rest of the week.
  DateTime? monday;
  for (final entry in dated.entries) {
    final weekday = weekdays[entry.key]!;
    monday = entry.value.subtract(Duration(days: weekday - DateTime.monday));
    break;
  }
  // Failing that, the week number in the corner ("Vecka 39").
  monday ??= _mondayOfWeekNumber(header, timeZone, now);
  if (monday == null) return dated;

  return {
    for (final entry in weekdays.entries)
      entry.key: dated[entry.key] ??
          monday.add(Duration(days: entry.value - DateTime.monday)),
  };
}

/// School years cross a new year: a plan read in December naming 8/1 means
/// January. Anything more than a month behind is next year's.
int _yearFor(int month, int day, String timeZone, DateTime? now) {
  final at = tz.TZDateTime.from(
    now ?? DateTime.now().toUtc(),
    tz.getLocation(timeZone),
  );
  final thisYear = DateTime.utc(at.year, month, day);
  final today = DateTime.utc(at.year, at.month, at.day);
  return thisYear.isBefore(today.subtract(const Duration(days: 31)))
      ? at.year + 1
      : at.year;
}

DateTime? _mondayOfWeekNumber(
  List<String> header,
  String timeZone,
  DateTime? now,
) {
  for (final cell in header) {
    final match = RegExp(
      r'\bv(?:ecka|\.)?\s*(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(cell);
    if (match == null) continue;
    final week = int.parse(match.group(1)!);
    final at = tz.TZDateTime.from(
      now ?? DateTime.now().toUtc(),
      tz.getLocation(timeZone),
    );
    // The year whose week this is: a plan for week 2 read in December is
    // next year's.
    final year =
        isoWeekNumber(DateTime(at.year, at.month, at.day)) > 40 && week < 10
            ? at.year + 1
            : at.year;
    return _mondayOfIsoWeek(year, week);
  }
  return null;
}

/// The Monday of ISO week [week] in [year], as wall-clock date fields.
DateTime _mondayOfIsoWeek(int year, int week) {
  final fourth = DateTime.utc(year, 1, 4);
  final firstMonday = fourth.subtract(
    Duration(days: fourth.weekday - DateTime.monday),
  );
  return firstMonday.add(Duration(days: (week - 1) * 7));
}

/// Days with no school in them: a cell saying so is not homework.
const _daysOff = ['studiedag', 'lov', 'ledig', 'helgdag', 'röd dag'];

bool _isDayOff(String cell) {
  final lower = cell.toLowerCase().trim();
  return _daysOff.any((w) => lower == w || lower.startsWith('$w '));
}

/// Subjects as a Swedish timetable abbreviates them in a table like this,
/// longest first so "Sv" does not swallow "SvA".
const _subjects = <String, String>{
  'ma': 'Matematik',
  'matematik': 'Matematik',
  'matte': 'Matematik',
  'sv': 'Svenska',
  'sva': 'Svenska som andraspråk',
  'svenska': 'Svenska',
  'eng': 'Engelska',
  'engelska': 'Engelska',
  'no': 'NO',
  'so': 'SO',
  'bi': 'Biologi',
  'fy': 'Fysik',
  'ke': 'Kemi',
  'hi': 'Historia',
  'ge': 'Geografi',
  're': 'Religion',
  'sh': 'Samhällskunskap',
  'idh': 'Idrott',
  'idrott': 'Idrott',
  'mu': 'Musik',
  'bl': 'Bild',
  'sl': 'Slöjd',
  'tk': 'Teknik',
  'hkk': 'Hem- och konsumentkunskap',
};

class _Piece {
  const _Piece(this.text, this.subject);
  final String text;
  final String? subject;
}

/// A cell split where a new subject starts: "Sv: Läsuppdrag Eng: glosor" is
/// two pieces of homework, not one with a strange title.
List<_Piece> _splitBySubject(String cell) {
  final pattern = RegExp(
    r'\b(' + _subjects.keys.map(RegExp.escape).join('|') + r')\s*:',
    caseSensitive: false,
  );
  final marks = pattern.allMatches(cell).toList();
  if (marks.isEmpty) return [_Piece(cell, null)];

  final pieces = <_Piece>[];
  // Anything before the first subject belongs with it: "Vildmarksleden NO:
  // fundera…" is about the NO homework.
  for (final (i, mark) in marks.indexed) {
    final from = mark.end;
    final to = i + 1 < marks.length ? marks[i + 1].start : cell.length;
    final lead = i == 0 ? cell.substring(0, mark.start).trim() : '';
    final body = cell.substring(from, to).trim();
    final text = [
      if (lead.isNotEmpty) lead,
      if (body.isNotEmpty) body,
    ].join(' · ');
    if (text.isEmpty) continue;
    pieces.add(_Piece(text, _subjects[mark.group(1)!.toLowerCase()]));
  }
  return pieces.isEmpty ? [_Piece(cell, null)] : pieces;
}

/// Words that make a line homework rather than a notice.
const _homeworkWords = [
  'läxa',
  'läxor',
  'glosor',
  'glosförhör',
  'prov',
  'diagnos',
  'förhör',
  'repetera',
  'läsuppdrag',
  'inlämning',
  'lämna in',
  'redovisning',
  'homework',
];

bool _soundsLikeHomework(String text) {
  final lower = text.toLowerCase();
  return _homeworkWords.any(lower.contains);
}

HomeworkType _typeOf(String text) {
  final lower = text.toLowerCase();
  if (['prov', 'diagnos', 'förhör', 'nationella'].any(lower.contains)) {
    return HomeworkType.test;
  }
  if (['läs', 'läsuppdrag', 'read'].any(lower.contains)) {
    return HomeworkType.reading;
  }
  if (['inlämning', 'lämna in'].any(lower.contains)) {
    return HomeworkType.handIn;
  }
  return HomeworkType.assignment;
}
