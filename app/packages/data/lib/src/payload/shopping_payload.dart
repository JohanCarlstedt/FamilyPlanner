import 'package:domain/domain.dart';

import 'payload.dart';

enum ShoppingListState { active, completed, template }

enum ItemState { needed, inCart, bought, unavailable }

/// A shopping list (spec §4 `shopping_list`, kind 7): its items are objects
/// of their own, so two people shopping from it never overwrite each other.
class ShoppingListPayload {
  ShoppingListPayload._(this.payload);

  static const version = 1;

  factory ShoppingListPayload.read(Payload payload) =>
      ShoppingListPayload._(payload);

  factory ShoppingListPayload.write({
    Payload? existing,
    required String name,
    ShoppingListState state = ShoppingListState.active,
    String? store,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('name', name)
      ..setText('state', state.name)
      ..setText('store', store);
    return ShoppingListPayload._(p);
  }

  final Payload payload;

  String get name => payload.text('name') ?? '';
  ShoppingListState get state =>
      ShoppingListState.values.asNameMap()[payload.text('state')] ??
      ShoppingListState.active;
  String? get store => payload.text('store');
}

/// Where an item's amount came from (spec §4 `shopping_list_item_source`):
/// taking the source away takes away only its share.
class ItemSource {
  const ItemSource({
    required this.type,
    this.id,
    this.quantity,
    this.unit,
    this.label,
  });

  /// `recipe`, `manual` or `staple`.
  final String type;
  final String? id;
  final double? quantity;
  final Unit? unit;

  /// "Kycklinggryta", for "why is this on the list".
  final String? label;

  Payload toPayload() => Payload.map()
    ..setText('type', type)
    ..setText('id', id)
    ..setText('quantity', quantity?.toString())
    ..setText('unit', unit?.name)
    ..setText('label', label);

  static ItemSource read(Payload p) => ItemSource(
    type: p.text('type') ?? 'manual',
    id: p.text('id'),
    quantity: double.tryParse(p.text('quantity') ?? ''),
    unit: Unit.values.asNameMap()[p.text('unit')],
    label: p.text('label'),
  );
}

/// One line on a list (spec §4 `shopping_list_item`, kind 8).
class ShoppingItemPayload {
  ShoppingItemPayload._(this.payload);

  static const version = 1;

  factory ShoppingItemPayload.read(Payload payload) =>
      ShoppingItemPayload._(payload);

  factory ShoppingItemPayload.write({
    Payload? existing,
    required String listId,
    required String name,
    String? key,
    double? quantity,
    Unit? unit,
    Aisle category = Aisle.other,
    ItemState state = ItemState.needed,
    String? checkedBy,
    DateTime? checkedAt,
    String? note,
    List<ItemSource> sources = const [],
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('list', listId)
      ..setText('name', name)
      ..setText('key', key)
      ..setText('quantity', quantity?.toString())
      ..setText('unit', unit?.name)
      ..setText('category', category.name)
      ..setText('state', state.name)
      ..setText('checkedBy', checkedBy)
      ..setText('checkedAt', checkedAt?.toUtc().toIso8601String())
      ..setText('note', note)
      ..setNestedList('sources', [for (final s in sources) s.toPayload()]);
    return ShoppingItemPayload._(p);
  }

  final Payload payload;

  String get listId => payload.text('list') ?? '';
  String get name => payload.text('name') ?? '';

  /// The catalogue ingredient, or null for free text.
  String? get key => payload.text('key');
  double? get quantity => double.tryParse(payload.text('quantity') ?? '');
  Unit? get unit => Unit.values.asNameMap()[payload.text('unit')];
  Aisle get category =>
      Aisle.values.asNameMap()[payload.text('category')] ?? Aisle.other;
  ItemState get state =>
      ItemState.values.asNameMap()[payload.text('state')] ?? ItemState.needed;
  String? get checkedBy => payload.text('checkedBy');
  String? get note => payload.text('note');
  List<ItemSource> get sources => [
    for (final s in payload.nestedList('sources') ?? const <Payload>[])
      ItemSource.read(s),
  ];

  String describe() => describeAmount(quantity, unit, name);

  /// This item with [changes] applied, keeping every other field.
  ShoppingItemPayload copyWith({
    double? quantity,
    Unit? unit,
    bool clearQuantity = false,
    ItemState? state,
    String? checkedBy,
    DateTime? checkedAt,
    List<ItemSource>? sources,
  }) {
    final p = Payload.decode(payload.encode());
    if (clearQuantity) {
      p
        ..setText('quantity', null)
        ..setText('unit', null);
    }
    if (quantity != null) p.setText('quantity', quantity.toString());
    if (unit != null) p.setText('unit', unit.name);
    if (state != null) p.setText('state', state.name);
    if (checkedBy != null) p.setText('checkedBy', checkedBy);
    if (checkedAt != null) {
      p.setText('checkedAt', checkedAt.toUtc().toIso8601String());
    }
    if (sources != null) {
      p.setNestedList('sources', [for (final s in sources) s.toPayload()]);
    }
    return ShoppingItemPayload._(p);
  }
}

/// A recipe the family keeps (spec §4 `recipe`, kind 6): the link, the
/// ingredient lines and the family's own notes. The method stays on the
/// site it came from.
class RecipePayload {
  RecipePayload._(this.payload);

  static const version = 1;

  factory RecipePayload.read(Payload payload) => RecipePayload._(payload);

  factory RecipePayload.write({
    Payload? existing,
    required String title,
    required List<String> ingredients,
    String? url,
    int? servings,
    int? minutes,
    String? imageUrl,
    List<String> tags = const [],
    String? notes,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setTexts('ingredients', ingredients)
      ..setText('url', url)
      ..setInteger('servings', servings)
      ..setInteger('minutes', minutes)
      ..setText('image', imageUrl)
      ..setTexts('tags', tags)
      ..setText('notes', notes);
    return RecipePayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  List<String> get ingredients => payload.texts('ingredients') ?? const [];
  String? get url => payload.text('url');
  int? get servings => payload.integer('servings');
  int? get minutes => payload.integer('minutes');
  String? get imageUrl => payload.text('image');
  List<String> get tags => payload.texts('tags') ?? const [];
  String? get notes => payload.text('notes');
}
