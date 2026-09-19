import 'package:domain/domain.dart';

import 'payload.dart';

/// Away mode or a school break (spec §3 `absence`, kind 24).
class AbsencePayload {
  AbsencePayload._(this.payload);

  static const version = 1;

  factory AbsencePayload.read(Payload payload) => AbsencePayload._(payload);

  factory AbsencePayload.write({
    Payload? existing,
    required String title,
    required DateTime startsOn,
    required DateTime endsOn,
    Set<String> memberIds = const {},
    Set<EventKind> suppressKinds = const {
      EventKind.activity,
      EventKind.routine,
    },
    bool suppressReminders = false,
    bool schoolBreak = false,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setText('from', _date(startsOn))
      ..setText('to', _date(endsOn))
      ..setTexts('members', memberIds.toList()..sort())
      ..setTexts('kinds', [for (final k in suppressKinds) k.name]..sort())
      ..setBoolean('silence', suppressReminders)
      ..setBoolean('break', schoolBreak);
    return AbsencePayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  DateTime? get startsOn => _parse(payload.text('from'));
  DateTime? get endsOn => _parse(payload.text('to'));
  Set<String> get memberIds => {...?payload.texts('members')};
  Set<EventKind> get suppressKinds => {
    for (final k in payload.texts('kinds') ?? const <String>[])
      ?EventKind.values.asNameMap()[k],
  };
  bool get suppressReminders => payload.boolean('silence') ?? false;

  /// A school break (sportlov, höstlov …) rather than a trip.
  bool get schoolBreak => payload.boolean('break') ?? false;

  Absence? toDomain(String id) {
    final from = startsOn;
    final to = endsOn;
    if (from == null || to == null) return null;
    return Absence(
      id: id,
      title: title,
      startsOn: from,
      endsOn: to,
      memberIds: memberIds,
      suppressKinds: suppressKinds,
      suppressReminders: suppressReminders,
    );
  }

  static DateTime? _parse(String? d) =>
      d == null ? null : DateTime.tryParse('${d}T00:00:00Z');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
