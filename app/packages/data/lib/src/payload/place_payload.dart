import 'package:domain/domain.dart';

import 'payload.dart';

/// Schema of a place's payload (spec §3 `place`). Geocoding fields arrive
/// with a provider; until then every place is `unresolved` and events at it
/// use a fixed-lead reminder, as the spec's geocoding rules say.
class PlacePayload {
  PlacePayload._(this.payload);

  static const version = 1;

  factory PlacePayload.read(Payload payload) => PlacePayload._(payload);

  factory PlacePayload.write({
    Payload? existing,
    required String name,
    String? address,
    bool isHome = false,
    int parkingBufferMinutes = 0,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('name', name)
      ..setText('address', address)
      ..setBoolean('home', isHome)
      ..setInteger('parkingMinutes', parkingBufferMinutes);
    if (!p.has('geocode')) p.setText('geocode', 'unresolved');
    return PlacePayload._(p);
  }

  final Payload payload;

  /// Sets where the place is and how far "at it" reaches (spec §7), or
  /// clears it. Microdegrees: whole numbers travel exactly.
  PlacePayload withLocation(GeoPoint? at, {double radiusMeters = 100}) {
    payload
      ..setInteger('latE6', at == null ? null : (at.lat * 1e6).round())
      ..setInteger('lngE6', at == null ? null : (at.lng * 1e6).round())
      ..setInteger('radius', at == null ? null : radiusMeters.round());
    return this;
  }

  GeoPoint? get location =>
      switch ((payload.integer('latE6'), payload.integer('lngE6'))) {
        (final lat?, final lng?) => GeoPoint(lat / 1e6, lng / 1e6),
        _ => null,
      };

  String get name => payload.text('name') ?? '';

  String? get address => payload.text('address');

  bool get isHome => payload.boolean('home') ?? false;

  int get parkingBufferMinutes => payload.integer('parkingMinutes') ?? 0;

  Place toDomain(String id) => Place(
    id: id,
    name: name,
    address: address,
    isHome: isHome,
    parkingBufferMinutes: parkingBufferMinutes,
    location: location,
    radiusMeters: (payload.integer('radius') ?? 100).toDouble(),
  );
}
