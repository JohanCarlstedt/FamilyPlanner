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

  const Place({
    required this.id,
    required this.name,
    this.address,
    this.isHome = false,
    this.parkingBufferMinutes = 0,
  });
}
