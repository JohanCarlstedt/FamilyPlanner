import 'package:domain/domain.dart';

import 'payload.dart';

/// Someone the family knows (spec §3 `person`, kind 4): a member, or
/// grandma, a cousin, a best friend. Kept minimal: a name, what they are
/// to the family, a day to celebrate and gift notes, nothing more.
class PersonPayload {
  PersonPayload._(this.payload);

  static const version = 1;

  factory PersonPayload.read(Payload payload) => PersonPayload._(payload);

  factory PersonPayload.write({
    Payload? existing,
    required String name,
    String? memberId,
    String? label,
    DateTime? date,
    CelebrationType type = CelebrationType.birthday,
    List<int> leadDays = const [14, 3, 0],
    String? notes,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('name', name)
      ..setText('member', memberId)
      ..setText('label', label)
      ..setText('date', date == null ? null : _date(date))
      ..setText('type', type.name)
      ..setTexts('lead', [for (final d in leadDays) '$d'])
      ..setText('notes', notes);
    return PersonPayload._(p);
  }

  final Payload payload;

  String get name => payload.text('name') ?? '';

  /// Set when they're in the household.
  String? get memberId => payload.text('member');

  /// What the family calls them: "Farmor", "bonuspappa" (spec §3: the
  /// label matters more than the type).
  String? get label => payload.text('label');

  /// The day, as `DateTime.utc` fields; the year is
  /// [Celebrations.unknownYear] when nobody knows it.
  DateTime? get date => DateTime.tryParse('${payload.text('date')}T00:00:00Z');
  CelebrationType get type =>
      CelebrationType.values.asNameMap()[payload.text('type')] ??
      CelebrationType.birthday;
  List<int> get leadDays => [
    for (final d in payload.texts('lead') ?? const <String>[]) ?int.tryParse(d),
  ];

  /// Sizes, gift ideas.
  String? get notes => payload.text('notes');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
