import 'shopping/catalogue.dart';
import 'shopping/ingredient_line.dart';

/// Spec §4 `member_dietary_note`.
enum DietType { allergy, intolerance, dislike, diet }

/// What one member doesn't or can't eat. [value] is a catalogue key
/// ("nuts") or free words ("koriander").
class DietNote {
  const DietNote({
    required this.memberId,
    required this.type,
    required this.value,
    this.strict = false,
    this.note,
  });

  static DietNote values({
    required String memberId,
    required String type,
    required String value,
    bool strict = false,
    String? note,
  }) =>
      DietNote(
        memberId: memberId,
        type: DietType.values.asNameMap()[type] ?? DietType.dislike,
        value: value,
        strict: strict,
        note: note,
      );

  final String memberId;
  final DietType type;
  final String value;

  /// Strict notes (an allergy that matters) keep a meal out of polls and
  /// are flagged everywhere; the rest are shown, never enforced.
  final bool strict;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is DietNote &&
      other.memberId == memberId &&
      other.type == type &&
      other.value == value &&
      other.strict == strict &&
      other.note == note;

  @override
  int get hashCode => Object.hash(memberId, type, value, strict, note);
}

/// One recipe line that runs into a note.
class DietConflict {
  const DietConflict(this.note, this.line);

  final DietNote note;
  final String line;
}

/// Which of a recipe's [lines] run into which [notes]: by catalogue
/// ingredient when the note names one, by the words otherwise. Flagged,
/// never filtered: a parent needs to see why (spec §4).
List<DietConflict> dietConflicts(
  List<String> lines,
  List<DietNote> notes,
  IngredientCatalogue catalogue,
) =>
    [
      for (final line in lines)
        for (final note in notes)
          if (_hits(line, note, catalogue)) DietConflict(note, line),
    ];

/// Spec §4 "Dietary exclusions beat votes": a meal with a strict conflict
/// can't be a poll option.
bool excludedFromPolls(
  List<String> lines,
  List<DietNote> notes,
  IngredientCatalogue catalogue,
) =>
    dietConflicts(lines, notes, catalogue).any((c) => c.note.strict);

bool _hits(String line, DietNote note, IngredientCatalogue catalogue) {
  final name = IngredientLine.parse(line).name.toLowerCase();
  if (catalogue.byKey(note.value) != null) {
    return catalogue.match(name)?.key == note.value;
  }
  final words = note.value.toLowerCase().trim();
  if (words.isEmpty) return false;
  if (' $name '.contains(' $words')) return true;
  // "lök" also catches "gula lökar": both are the catalogue's onion.
  final key = catalogue.match(words)?.key;
  return key != null && catalogue.match(name)?.key == key;
}
