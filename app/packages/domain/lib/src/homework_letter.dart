import 'package:timezone/timezone.dart' as tz;

import 'homework.dart';

/// A piece of homework read out of a teacher's letter, for someone to
/// confirm. Never saved on its own: the parser guesses, and a guess that
/// quietly becomes a deadline is worse than one that asks.
class HomeworkCandidate {
  const HomeworkCandidate({
    required this.title,
    required this.dueAt,
    this.subject,
    this.type = HomeworkType.assignment,
  });

  final String title;

  /// Wall-clock date, as `DateTime.utc` fields — a deadline is a day, not
  /// an instant, and the family's zone decides when that day ends.
  final DateTime? dueAt;

  /// The subject as the letter names it, capitalised as a heading would be.
  final String? subject;

  final HomeworkType type;
}

/// Reads the homework out of a week letter — a veckobrev, a note in Teams,
/// a shared Word document, a photo someone pasted the text from.
///
/// Deliberately a *reader*, not an importer. Teachers write these
/// differently every term and rewrite them mid-year; anything here is a
/// heuristic, and heuristics belong in front of a person who can say no.
/// Nothing is invented: a line that does not look like homework is left
/// out rather than guessed at.
List<HomeworkCandidate> readHomeworkLetter(
  String text, {
  required DateTime now,
  required String timeZone,
}) {
  final found = <HomeworkCandidate>[];
  final location = tz.getLocation(timeZone);
  final today = tz.TZDateTime.from(now, location);

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    // A heading on its own ("Läxor:") announces what follows; it is not
    // itself a piece of homework.
    if (_isHeading(line)) continue;
    final kind = _kindOf(line);
    if (kind == null) continue;

    found.add(
      HomeworkCandidate(
        title: _title(line),
        subject: _subject(line),
        type: kind,
        dueAt: _due(line, today),
      ),
    );
  }
  return found;
}

/// Words that mean a line is homework rather than news.
const _homeworkWords = [
  'läxa',
  'läxor',
  'glosor',
  'glosförhör',
  'homework',
  'inlämning',
  'lämna in',
  'redovisning',
  'hand in',
];

const _testWords = ['prov', 'test', 'förhör', 'diagnos', 'nationella'];

const _readingWords = ['läs ', 'läsa ', 'läsning', 'read '];

/// Subjects as a Swedish timetable names them, lower case for matching.
const _subjects = {
  'matematik': 'Matematik',
  'matte': 'Matematik',
  'maths': 'Matematik',
  'svenska': 'Svenska',
  'engelska': 'Engelska',
  'english': 'Engelska',
  'no': 'NO',
  'so': 'SO',
  'biologi': 'Biologi',
  'fysik': 'Fysik',
  'kemi': 'Kemi',
  'historia': 'Historia',
  'geografi': 'Geografi',
  'religion': 'Religion',
  'samhällskunskap': 'Samhällskunskap',
  'idrott': 'Idrott',
  'musik': 'Musik',
  'slöjd': 'Slöjd',
  'bild': 'Bild',
  'teknik': 'Teknik',
  'spanska': 'Spanska',
  'tyska': 'Tyska',
  'franska': 'Franska',
};

bool _isHeading(String line) {
  final bare = line.toLowerCase().replaceAll(RegExp(r'[:\s]'), '');
  return bare == 'läxor' || bare == 'läxa' || bare == 'homework';
}

HomeworkType? _kindOf(String line) {
  final lower = line.toLowerCase();
  if (_testWords.any(lower.contains)) return HomeworkType.test;
  // A subject followed by a colon is the shape of a homework line in every
  // one of these letters: "Matematik: sidorna 42-44".
  final hasSubject = _subjects.keys.any(
    (s) => lower.startsWith('$s:') || lower.startsWith('$s :'),
  );
  if (_homeworkWords.any(lower.contains) || hasSubject) {
    if (_readingWords.any(lower.contains)) return HomeworkType.reading;
    if (lower.contains('inlämning') || lower.contains('lämna in')) {
      return HomeworkType.handIn;
    }
    return HomeworkType.assignment;
  }
  return null;
}

String _title(String line) {
  var title = line.trim();
  // The subject is carried separately; leading "Matematik:" would only
  // repeat it.
  final colon = title.indexOf(':');
  if (colon > 0 && colon < 24) {
    final head = title.substring(0, colon).toLowerCase().trim();
    if (_subjects.containsKey(head)) title = title.substring(colon + 1).trim();
  }
  // "…, till torsdag 24/9" — the date is carried separately too.
  title = title
      .replaceAll(
        RegExp(
          r',?\s*(till|senast|to|by)\s+\S+(\s+\d{1,2}/\d{1,2})?\s*\.?$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  return title.replaceAll(RegExp(r'[\s,.;]+$'), '');
}

String? _subject(String line) {
  final lower = line.toLowerCase();
  for (final entry in _subjects.entries) {
    if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) {
      return entry.value;
    }
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

/// The deadline a line names: a date if it gives one, else the next of the
/// weekday it names, else nothing at all rather than a guess.
DateTime? _due(String line, tz.TZDateTime today) {
  final lower = line.toLowerCase();

  // 24/9 or 24/9-26, the way a Swedish letter writes it.
  final slash = RegExp(r'\b(\d{1,2})/(\d{1,2})\b').firstMatch(lower);
  if (slash != null) {
    final day = int.parse(slash.group(1)!);
    final month = int.parse(slash.group(2)!);
    var year = today.year;
    final date = DateTime.utc(year, month, day);
    // A letter read in December naming 8/1 means January, not ten months
    // ago: a deadline in the past is never what was meant.
    if (date.isBefore(DateTime.utc(today.year, today.month, today.day))) {
      year += 1;
    }
    return DateTime.utc(year, month, day);
  }

  for (final entry in _weekdays.entries) {
    if (!lower.contains(entry.key)) continue;
    var date = DateTime.utc(today.year, today.month, today.day);
    // The next one, counting today as too late to still be set homework.
    do {
      date = date.add(const Duration(days: 1));
    } while (date.weekday != entry.value);
    return date;
  }
  return null;
}

/// Whether text carries the marks of having been read with the wrong
/// encoding — UTF-8 bytes taken one at a time, so "\u00e5" arrived as two
/// characters instead of one.
///
/// Homework imported before that was fixed can never be matched to its
/// corrected self: the id is derived from the title, so repaired text
/// arrives as a *new* piece of homework and the unreadable one stays
/// beside it for ever. This is how the old one is recognised for removal.
///
/// Deliberately narrow: the tell is the stray capital A-tilde followed by
/// another high character, which is the signature of the mistake and
/// effectively never appears in real school text. One on its own is not
/// enough to delete a child's homework over.
bool looksMisread(String text) =>
    RegExp('\u00c3[\u0080-\u00ff]').hasMatch(text) ||
    text.contains('\u00e2\u20ac') ||
    text.contains('\ufffd');
