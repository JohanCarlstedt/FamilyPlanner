import 'location.dart';

/// Spec §3 `place`: an address belongs to a venue, not to an event. One
/// place, referenced by every event held there.
class Place {
  final String id;

  /// "Sportshallen", "Grandma", "Tandläkaren".
  final String name;

  /// Single-line display form, exactly as typed: Swedish addresses arrive as
  /// anything from "Idrottsvägen 3, 181 41 Lidingö" to "bakom ishallen".
  final String? address;

  /// The default origin for departure maths.
  final bool isHome;

  /// Per-venue arrival friction: the sports hall car park is always full.
  final int parkingBufferMinutes;

  /// Where it is, set from a phone standing there or a tap on the map: no
  /// geocoding provider needed (spec open question 12).
  final GeoPoint? location;

  /// Spec §7 geofence: inside this, a member is "at" the place.
  final double radiusMeters;

  const Place({
    required this.id,
    required this.name,
    this.address,
    this.isHome = false,
    this.parkingBufferMinutes = 0,
    this.location,
    this.radiusMeters = 100,
  });
}
