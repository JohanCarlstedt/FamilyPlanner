import 'payload.dart';

/// One thing to bring.
class KitItem {
  const KitItem({required this.name, this.forMember, this.note});

  final String name;

  /// Who brings it; null: whoever's going (spec §3: the child brings
  /// boots, the parent the folding chair).
  final String? forMember;

  /// "Only match days", "if raining".
  final String? note;

  Payload toPayload() => Payload.map()
    ..setText('name', name)
    ..setText('for', forMember)
    ..setText('note', note);

  static KitItem read(Payload p) => KitItem(
    name: p.text('name') ?? '',
    forMember: p.text('for'),
    note: p.text('note'),
  );
}

/// A named, reusable kit list (spec §3 `equipment_set`, kind 12): "Football
/// kit", shared by every event that needs it, so a fix fixes all of them.
class EquipmentSetPayload {
  EquipmentSetPayload._(this.payload);

  static const version = 1;

  factory EquipmentSetPayload.read(Payload payload) =>
      EquipmentSetPayload._(payload);

  factory EquipmentSetPayload.write({
    Payload? existing,
    required String name,
    required List<KitItem> items,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('name', name)
      ..setNestedList('items', [for (final i in items) i.toPayload()]);
    return EquipmentSetPayload._(p);
  }

  final Payload payload;

  String get name => payload.text('name') ?? '';
  List<KitItem> get items => [
    for (final i in payload.nestedList('items') ?? const <Payload>[])
      KitItem.read(i),
  ];
}
