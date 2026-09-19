import 'payload.dart';

/// A helper's access (spec §2 `helper`, crypto doc §3 `adults+helper:{id}`):
/// who helps, with which children, until when. Sealed to `adults`: the helper
/// never reads their own grant, only what it lets them see.
class HelperGrantPayload {
  HelperGrantPayload._(this.payload);

  static const version = 1;

  factory HelperGrantPayload.read(Payload payload) =>
      HelperGrantPayload._(payload);

  factory HelperGrantPayload.write({
    Payload? existing,
    required String helperMemberId,
    required List<String> childIds,
    DateTime? until,
    DateTime? endedAt,
    bool coParent = false,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('helper', helperMemberId)
      ..setTexts('children', childIds)
      ..setText('until', until?.toUtc().toIso8601String())
      ..setText('endedAt', endedAt?.toUtc().toIso8601String())
      ..setBoolean('coParent', coParent);
    return HelperGrantPayload._(p);
  }

  final Payload payload;

  String get helperMemberId => payload.text('helper') ?? '';

  List<String> get childIds => payload.texts('children') ?? const [];

  DateTime? get until => DateTime.tryParse(payload.text('until') ?? '');

  /// Set once the access has been wound up (devices revoked).
  DateTime? get endedAt => DateTime.tryParse(payload.text('endedAt') ?? '');

  /// The audience group only the parents and this helper hold.
  String get group => helperGroup(helperMemberId);

  /// A parent from the other home (spec §3 custody): like a helper for the
  /// children they share, with no end date.
  bool get coParent => payload.boolean('coParent') ?? false;

  bool activeAt(DateTime now) =>
      endedAt == null && (coParent || (until?.isAfter(now) ?? false));
}

/// The group a helper's content is also wrapped to: crypto doc §3.
String helperGroup(String helperMemberId) => 'adults+helper:$helperMemberId';
