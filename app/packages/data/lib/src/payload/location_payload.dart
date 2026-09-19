import 'package:domain/domain.dart';

import 'payload.dart';

/// Schema of a member's location sharing (spec §7 `location_share_setting`),
/// sealed to the whole family: everyone on the map can see who sees them.
class LocationSharePayload {
  LocationSharePayload._(this.payload);

  static const version = 1;

  factory LocationSharePayload.read(Payload payload) =>
      LocationSharePayload._(payload);

  factory LocationSharePayload.write({
    Payload? existing,
    required LocationShare share,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', share.memberId)
      ..setText('mode', share.mode.name)
      ..setText('audience', share.audience.name)
      ..setText('precision', share.precision.name)
      ..setText('floor', share.floor?.name)
      ..setText('pausedUntil', share.pausedUntil?.toUtc().toIso8601String());
    return LocationSharePayload._(p);
  }

  final Payload payload;

  LocationShare? toDomain() {
    final member = payload.text('member');
    if (member == null) return null;
    T? pick<T extends Enum>(List<T> values, String key) =>
        values.asNameMap()[payload.text(key)];
    return LocationShare(
      memberId: member,
      mode: pick(ShareMode.values, 'mode') ?? ShareMode.off,
      audience: pick(ShareAudience.values, 'audience') ?? ShareAudience.parents,
      precision:
          pick(SharePrecision.values, 'precision') ?? SharePrecision.exact,
      floor: pick(ShareMode.values, 'floor'),
      pausedUntil: DateTime.tryParse(payload.text('pausedUntil') ?? '')
          ?.toUtc(),
    );
  }
}

/// What a sharer last said, as its location group carries it.
enum PositionState { sharing, paused, off }

/// One position message (spec §7 `member_location`): already reduced to its
/// precision on the sharer's phone.
class PositionMessage {
  const PositionMessage({required this.state, this.position, this.pausedUntil});

  final PositionState state;
  final SharedPosition? position;
  final DateTime? pausedUntil;

  static const type = 'position';

  Payload encode() {
    final p = Payload.create(1)
      ..setText('type', type)
      ..setText('state', state.name)
      ..setText('pausedUntil', pausedUntil?.toUtc().toIso8601String());
    final pos = position;
    if (pos != null) {
      p
        ..setInteger(
          'latE6',
          pos.point == null ? null : (pos.point!.lat * 1e6).round(),
        )
        ..setInteger(
          'lngE6',
          pos.point == null ? null : (pos.point!.lng * 1e6).round(),
        )
        ..setInteger('accuracy', pos.accuracyMeters?.round())
        ..setText('place', pos.placeId)
        ..setText('since', pos.since.toUtc().toIso8601String())
        ..setText('at', pos.capturedAt.toUtc().toIso8601String())
        ..setInteger('battery', pos.battery);
    } else {
      p.setText('at', DateTime.now().toUtc().toIso8601String());
    }
    return p;
  }

  static PositionMessage? decode(Payload p) {
    if (p.text('type') != type) return null;
    final state =
        PositionState.values.asNameMap()[p.text('state')] ?? PositionState.off;
    final at = DateTime.tryParse(p.text('at') ?? '')?.toUtc();
    final since = DateTime.tryParse(p.text('since') ?? '')?.toUtc();
    final lat = p.integer('latE6');
    final lng = p.integer('lngE6');
    return PositionMessage(
      state: state,
      pausedUntil: DateTime.tryParse(p.text('pausedUntil') ?? '')?.toUtc(),
      position: at == null || since == null
          ? null
          : SharedPosition(
              point: lat == null || lng == null
                  ? null
                  : GeoPoint(lat / 1e6, lng / 1e6),
              accuracyMeters: p.integer('accuracy')?.toDouble(),
              placeId: p.text('place'),
              since: since,
              capturedAt: at,
              battery: p.integer('battery'),
            ),
    );
  }
}
