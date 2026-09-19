import 'units.dart';

/// One line of a recipe's ingredients, read: "1 1/2 dl neutral rapsolja".
class IngredientLine {
  const IngredientLine({
    required this.text,
    required this.name,
    this.quantity,
    this.unit,
    this.note,
  });

  /// As the recipe wrote it.
  final String text;
  final double? quantity;
  final Unit? unit;
  final String name;

  /// "finhackad", "gärna ekologisk": kept, but not what you buy.
  final String? note;

  static const _vulgar = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 1 / 3,
    '⅔': 2 / 3
  };
  static const _number =
      r'(?:\d+\s+\d+/\d+|\d+\s*[½¼¾⅓⅔]|\d+/\d+|[½¼¾⅓⅔]|\d+(?:[.,]\d+)?)';
  static final _amount = RegExp(
    '^($_number)(?:\\s*[-–]\\s*($_number))?\\s*',
  );
  static final _about = RegExp(
    r'^(?:ca\.?|cirka|ungefär|c:a)\s+',
    caseSensitive: false,
  );

  static IngredientLine parse(String text) {
    var rest = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    rest = rest.replaceFirst(_about, '');
    double? quantity;
    Unit? unit;
    if (_amount.firstMatch(rest) case final m?) {
      // A range buys the upper end.
      quantity = _value(m.group(2) ?? m.group(1)!);
      rest = rest.substring(m.end);
      final word = rest.split(' ').first;
      if (Unit.parse(word) case final u?) {
        unit = u;
        rest = rest.substring(word.length).trim();
      } else {
        unit = Unit.st;
      }
    }
    String? note;
    if (RegExp(r'\s*\(([^)]*)\)').firstMatch(rest) case final m?) {
      note = m.group(1)!.trim();
      rest = rest.replaceRange(m.start, m.end, '').trim();
    }
    if (rest.indexOf(',') case final comma when comma > 0) {
      final after = rest.substring(comma + 1).trim();
      if (after.isNotEmpty) note = note == null ? after : '$after, $note';
      rest = rest.substring(0, comma).trim();
    }
    return IngredientLine(
      text: text,
      name: rest,
      quantity: quantity,
      unit: unit,
      note: note == null || note.isEmpty ? null : note,
    );
  }

  static double _value(String s) {
    s = s.trim();
    if (RegExp(r'^(\d+)\s*([½¼¾⅓⅔])$').firstMatch(s) case final m?) {
      return int.parse(m.group(1)!) + _vulgar[m.group(2)]!;
    }
    if (_vulgar[s] case final v?) return v;
    if (RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s) case final m?) {
      return int.parse(m.group(1)!) +
          int.parse(m.group(2)!) / int.parse(m.group(3)!);
    }
    if (RegExp(r'^(\d+)/(\d+)$').firstMatch(s) case final m?) {
      return int.parse(m.group(1)!) / int.parse(m.group(2)!);
    }
    return double.parse(s.replaceAll(',', '.'));
  }
}
