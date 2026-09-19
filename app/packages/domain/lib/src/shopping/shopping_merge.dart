import 'catalogue.dart';
import 'ingredient_line.dart';
import 'units.dart';

/// One thing to buy, from one source: a recipe line, or something typed.
class ShoppingLine {
  const ShoppingLine({
    required this.name,
    this.key,
    this.quantity,
    this.unit,
    this.category = Aisle.other,
  });

  /// Matched to the catalogue where it can be; free text otherwise.
  factory ShoppingLine.fromIngredient(
    IngredientLine line,
    IngredientCatalogue catalogue,
  ) {
    final match = catalogue.match(line.name);
    return ShoppingLine(
      name: match?.name ?? line.name,
      key: match?.key,
      quantity: line.quantity,
      unit: line.unit,
      category: match?.category ?? Aisle.other,
    );
  }

  /// The catalogue ingredient, or null for free text, which never merges.
  final String? key;
  final String name;
  final double? quantity;
  final Unit? unit;
  final Aisle category;

  /// For more or fewer portions than the recipe's.
  ShoppingLine scaled(double factor) => ShoppingLine(
        name: name,
        key: key,
        quantity: quantity == null ? null : quantity! * factor,
        unit: unit,
        category: category,
      );

  String describe() => describeAmount(quantity, unit, name);
}

/// Several lines of the same ingredient in amounts that add up.
class MergedLine {
  const MergedLine({
    required this.name,
    required this.parts,
    this.key,
    this.quantity,
    this.unit,
    this.category = Aisle.other,
  });

  final String? key;
  final String name;
  final double? quantity;
  final Unit? unit;
  final Aisle category;

  /// Where it came from, so a source can be taken out again (spec §4
  /// `shopping_list_item_source`).
  final List<ShoppingLine> parts;

  String describe() => describeAmount(quantity, unit, name);
}

String describeAmount(double? quantity, Unit? unit, String name) {
  if (quantity == null) return name;
  final amount = formatAmount(_up(quantity));
  return unit == null ? '$amount $name' : '$amount ${unit.label} $name';
}

/// Shopping rounds up: a little more cream is fine, too little isn't.
double _up(double q) => (q * 10 - 1e-9).ceil() / 10;

/// Spec §4 "Generation": sums lines of the same ingredient whose amounts add
/// up; refuses where they don't (pieces and grams of onion stay two lines,
/// side by side), and never merges free text.
List<MergedLine> mergeShoppingLines(List<ShoppingLine> lines) {
  final groups = <Object, List<ShoppingLine>>{};
  final order = <Object>[];
  var loose = 0;
  for (final l in lines) {
    final Object id = l.key == null
        ? 'free:${loose++}'
        : (l.key!, l.quantity == null ? null : l.unit?.mergeKey);
    if (!groups.containsKey(id)) order.add(id);
    (groups[id] ??= []).add(l);
  }
  // Keep lines of the same ingredient next to each other.
  final firstOfKey = <String, int>{};
  for (final (i, id) in order.indexed) {
    if (id case (final String key, _)) firstOfKey.putIfAbsent(key, () => i);
  }
  int rank(Object id) => switch (id) {
        (final String key, _) => firstOfKey[key]!,
        _ => order.indexOf(id),
      };
  final sorted = [...order]..sort((a, b) {
      final byKey = rank(a).compareTo(rank(b));
      return byKey != 0 ? byKey : order.indexOf(a).compareTo(order.indexOf(b));
    });
  return [for (final id in sorted) _merge(groups[id]!)];
}

MergedLine _merge(List<ShoppingLine> parts) {
  final first = parts.first;
  if (parts.length == 1 || first.quantity == null || first.unit == null) {
    return MergedLine(
      key: first.key,
      name: first.name,
      quantity: first.quantity,
      unit: first.unit,
      category: first.category,
      parts: parts,
    );
  }
  final (quantity, unit) = sumAmounts([
    for (final p in parts) (p.quantity!, p.unit!),
  ])!;
  return MergedLine(
    key: first.key,
    name: first.name,
    quantity: quantity,
    unit: unit,
    category: first.category,
    parts: parts,
  );
}

/// The sum of [amounts], in the largest unit they were given in that still
/// makes at least one (kg and l from 1000 g or ml). Null unless they all
/// measure the same kind of thing.
(double, Unit)? sumAmounts(List<(double, Unit)> amounts) {
  if (amounts.isEmpty) return null;
  final kind = amounts.first.$2.mergeKey;
  if (amounts.any((a) => a.$2.mergeKey != kind)) return null;
  if (amounts.length == 1) return amounts.single;
  final measure = amounts.first.$2.measure;
  final total = amounts.fold<double>(0, (sum, a) => sum + a.$1 * a.$2.factor);
  final Unit unit;
  if (measure == Measure.mass && total >= 1000) {
    unit = Unit.kg;
  } else if (measure == Measure.volume && total >= 1000) {
    unit = Unit.l;
  } else {
    final used = {for (final a in amounts) a.$2}.toList()
      ..sort((a, b) => b.factor.compareTo(a.factor));
    unit = used.firstWhere(
      (u) => total / u.factor >= 1,
      orElse: () => used.last,
    );
  }
  return (total / unit.factor, unit);
}
