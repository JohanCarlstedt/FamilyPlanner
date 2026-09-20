import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// The map when there is no Google Maps key: OpenStreetMap's own tiles,
/// which need no account, no key and no card, so the family map works on a
/// fresh checkout and on a phone belonging to someone who will never set up
/// a billing project (docs/google-maps.md).
///
/// It is kept in its own file because `flutter_map` and
/// `google_maps_flutter` both export `Marker`, `Circle` and `LatLng`;
/// importing them side by side means prefixing every one of them.
///
/// OpenStreetMap's tiles are donated. Their usage policy asks for an
/// identifying user agent and no bulk downloading, both of which a family
/// panning a map now and then satisfies. A crowd would not, and that day
/// this becomes a keyed provider's free tier.
class OsmMap extends StatelessWidget {
  const OsmMap({
    super.key,
    required this.camera,
    required this.dots,
    required this.places,
    required this.colorOf,
    required this.onTap,
  });

  /// Whose dot is drawn, in the order the rest of the screen uses.
  final List<(Member, GeoPoint)> dots;

  /// Places with a location: the circle each one covers.
  final List<Place> places;

  final OsmCamera camera;
  final Color Function(Member) colorOf;
  final void Function(Member) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterMap(
      mapController: camera.controller,
      options: MapOptions(
        initialCameraFit: dots.length < 2
            ? null
            : CameraFit.coordinates(
                coordinates: [for (final (_, p) in dots) LatLng(p.lat, p.lng)],
                padding: const EdgeInsets.all(48),
                maxZoom: 16,
              ),
        initialCenter: dots.isEmpty
            ? const LatLng(0, 0)
            : LatLng(dots.first.$2.lat, dots.first.$2.lng),
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'io.github.johancarlstedt.family',
        ),
        CircleLayer(
          circles: [
            for (final p in places)
              CircleMarker(
                point: LatLng(p.location!.lat, p.location!.lng),
                radius: p.radiusMeters,
                useRadiusInMeter: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderColor: theme.colorScheme.primary,
                borderStrokeWidth: 1,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final (m, p) in dots)
              Marker(
                point: LatLng(p.lat, p.lng),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => onTap(m),
                  child: CircleAvatar(
                    backgroundColor: colorOf(m),
                    foregroundColor: Colors.white,
                    child: Text(m.displayName.characters.first),
                  ),
                ),
              ),
          ],
        ),
        // Required by the tile licence, not decoration.
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

/// Moving the OpenStreetMap view, with the `flutter_map` types kept inside
/// this file so the screen can talk to either map the same way.
class OsmCamera {
  final MapController controller = MapController();

  /// Everyone at once, or one person close up — the same two moves the
  /// Google map makes.
  void lookAt(Iterable<GeoPoint> points) {
    final at = points.toList();
    if (at.isEmpty) return;
    try {
      if (at.length == 1) {
        controller.move(LatLng(at.first.lat, at.first.lng), 15);
        return;
      }
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: [for (final p in at) LatLng(p.lat, p.lng)],
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    } on Object {
      // The controller throws until the map has been laid out; the view
      // it would have moved to is the one it starts at anyway.
    }
  }

  void dispose() => controller.dispose();
}
