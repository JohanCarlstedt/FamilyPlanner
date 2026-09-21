/// Sending the family's shopping list to the shop's own list.
///
/// ICA's list is worth reaching for one reason: it syncs to the hand
/// scanners in the store, which nothing else here can do. What arrives
/// there is a copy, not a shared truth — the family's list stays the
/// source, and this only ever pushes towards the shop (docs/ica.md).
///
/// Nothing in this file knows about ICA: it is a reconciliation between
/// two lists of names, which is the part worth proving.
library;

/// One line of the family's list, reduced to what a shop can hold.
class ListedItem {
  const ListedItem({
    required this.name,
    this.quantity,
    this.unit,
    this.bought = false,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final bool bought;
}

/// A row already on the shop's list.
class ShopRow {
  const ShopRow({
    required this.id,
    required this.name,
    this.struckThrough = false,
    this.ours = false,
  });

  final String id;
  final String name;

  /// Already ticked off in the shop's own app.
  final bool struckThrough;

  /// Put there by us on an earlier push, rather than typed into the
  /// shop's app by a person.
  final bool ours;
}

/// What to send: rows to add, and rows of ours to strike through.
class ShopPush {
  const ShopPush({required this.add, required this.strike});

  final List<ListedItem> add;
  final List<String> strike;

  bool get isEmpty => add.isEmpty && strike.isEmpty;
  int get count => add.length + strike.length;
}

/// Works out the smallest push that makes the shop's list useful.
///
/// Three rules, and the second is the one that matters:
///
/// 1. Anything still needed here and not there is added.
/// 2. **Rows we did not create are never touched.** Someone may have
///    typed milk into ICA's own app while standing in the kitchen, and a
///    sync that quietly removes it is worse than no sync at all. The same
///    rule the school week plan follows.
/// 3. A row of ours whose item has been bought is struck through rather
///    than deleted, because that is what the shop's own app does when you
///    tick something off, and a struck row is a record rather than a
///    disappearance.
///
/// Matching is by name, folded for case and surrounding space, because
/// the shop's list has no room for our ids. Names are compared as the
/// person wrote them otherwise — "Ägg" and "ägg" are the same thing,
/// "ägg" and "äggula" are not.
ShopPush planShopPush(List<ListedItem> ours, List<ShopRow> theirs) {
  String key(String name) => name.trim().toLowerCase();

  final there = <String, ShopRow>{};
  for (final row in theirs) {
    // First wins: a duplicate row is the shop's business, not ours, and
    // striking the first is enough to say the thing was bought.
    there.putIfAbsent(key(row.name), () => row);
  }

  final add = <ListedItem>[];
  final strike = <String>[];

  for (final item in ours) {
    final row = there[key(item.name)];

    if (!item.bought) {
      // Needed. Add it if it is missing; if it is there but struck
      // through by us, leave it — unticking someone else's tick in the
      // shop is presumptuous, and the name is on the list either way.
      if (row == null) add.add(item);
      continue;
    }

    // Bought here. Only our own rows are ours to mark.
    if (row != null && row.ours && !row.struckThrough) strike.add(row.id);
  }

  return ShopPush(add: add, strike: strike);
}
