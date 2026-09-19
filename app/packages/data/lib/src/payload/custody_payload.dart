import 'package:domain/domain.dart';

import 'payload.dart';

/// Where a child of two homes is when (spec §3 `custody_arrangement`, kind
/// 26): sealed to the parents here and to the co-parent, who both need it.
class CustodyPayload {
  CustodyPayload._(this.payload);

  static const version = 1;

  factory CustodyPayload.read(Payload payload) => CustodyPayload._(payload);

  factory CustodyPayload.write({
    Payload? existing,
    required String childId,
    required CustodyPattern pattern,
    required DateTime reference,
    String? coParentId,
    List<CustodySwap> swaps = const [],
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('child', childId)
      ..setText('coParent', coParentId)
      ..setText('pattern', pattern.name)
      ..setText('reference', _wall(reference))
      ..setNestedList('swaps', [
        for (final s in swaps)
          Payload.map()
            ..setText('from', _wall(s.from))
            ..setText('until', _wall(s.until))
            ..setBoolean('here', s.here),
      ]);
    return CustodyPayload._(p);
  }

  final Payload payload;

  String get childId => payload.text('child') ?? '';
  String? get coParentId => payload.text('coParent');
  CustodyPattern get pattern =>
      CustodyPattern.values.asNameMap()[payload.text('pattern')] ??
      CustodyPattern.alternatingWeeks;
  DateTime? get reference => _parse(payload.text('reference'));
  List<CustodySwap> get swaps => [
    for (final s in payload.nestedList('swaps') ?? const <Payload>[])
      if ((_parse(s.text('from')), _parse(s.text('until'))) case (
        final from?,
        final until?,
      ))
        CustodySwap(from: from, until: until, here: s.boolean('here') ?? true),
  ];

  CustodyArrangement? toDomain() => switch (reference) {
    final ref? => CustodyArrangement(
      childId: childId,
      coParentId: coParentId,
      pattern: pattern,
      reference: ref,
      swaps: swaps,
    ),
    null => null,
  };

  static String _wall(DateTime d) => DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
  ).toIso8601String().replaceAll('Z', '');

  static DateTime? _parse(String? s) =>
      s == null ? null : DateTime.tryParse('${s}Z');
}
