import 'dart:convert';
import 'dart:ui' as ui;

import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One picture of the city and where its plot's centre is in it
/// (tool/city3d/render.py writes these).
class CitySprite {
  const CitySprite(
    this.image, {
    required this.anchor,
    required this.plotPx,
    this.evening = false,
  });

  final ui.Image image;

  /// Rendered for the evening: moonlit, windows lit. Drawn as it is at
  /// night, where a day picture is dimmed.
  final bool evening;

  /// Where the middle of the plot it stands on falls in the picture.
  final ui.Offset anchor;

  /// How wide one plot is in the picture.
  final double plotPx;
}

/// The city's pictures, rendered once from Kenney's CC0 3D kits.
///
/// Nothing about a child's city is stored as a picture: it is still what
/// they built where and when, and the pictures are only how that is drawn
/// now. A city built before there were pictures looks like this at once,
/// and anything without a picture of its own is drawn as it always was.
class CitySprites {
  CitySprites(this._sprites);

  final Map<String, CitySprite> _sprites;

  CitySprite? operator [](String? name) => name == null ? null : _sprites[name];

  bool get isEmpty => _sprites.isEmpty;

  static Future<CitySprites> load(AssetBundle bundle) async {
    final index = jsonDecode(
      await bundle.loadString('assets/city/sprites.json'),
    ) as Map<String, dynamic>;
    final sprites = <String, CitySprite>{};
    for (final MapEntry(key: name, value: entry) in index.entries) {
      final e = entry as Map<String, dynamic>;
      final data = await bundle.load('assets/city/${e['file']}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      sprites[name] = CitySprite(
        frame.image,
        anchor: ui.Offset(
          (e['anchorX'] as num).toDouble(),
          (e['anchorY'] as num).toDouble(),
        ),
        plotPx: (e['plotPx'] as num).toDouble(),
        evening: name.endsWith('@night'),
      );
    }
    return CitySprites(sprites);
  }
}

/// Loaded once for the app's life. A failure leaves the city drawn as it
/// was, never blank.
final citySpritesProvider = FutureProvider<CitySprites>((ref) async {
  try {
    return await CitySprites.load(rootBundle);
  } on Object {
    return CitySprites(const {});
  }
});

/// How many pictures there are of each kind (tool/city3d/manifest.py).
const _homes = [5, 6, 5, 6];
const _parks = [2, 2, 3, 2];
const _trees = 6;
const _sites = 3;
const _autumnTrees = 3;

/// The picture for what stands at (x, y), or null to draw it as before:
/// water, a construction site, a fountain, and what no kit has yet.
///
/// Which of several pictures is the city's own dice (`cityNoise`), so a
/// street is never all one house, and every phone and every opening
/// draws the same one.
String? citySpriteName(City city, int x, int y, {required int month}) {
  if (!city.isOpen(x, y) || city.isWater(x, y)) return null;
  double n(int salt) => cityNoise(city.seed, x, y, salt);
  int pick(int count, int salt) => (n(salt) * count).floor() % count;

  final civic = City.civicPlots.entries
      .where((e) => e.value == (x, y) && city.civic.contains(e.key))
      .firstOrNull
      ?.key;
  if (civic != null) {
    return switch (civic) {
      Civic.hall => 'civic_hall',
      Civic.school => 'civic_school',
      Civic.library => 'civic_library',
      Civic.observatory => 'civic_observatory',
      Civic.university => 'civic_university',
      Civic.fountain => null,
    };
  }

  if (city.isRoad(x, y)) {
    bool road(int dx, int dy) =>
        city.isOpen(x + dx, y + dy) && city.isRoad(x + dx, y + dy);
    final mask =
        (road(0, -1) ? 1 : 0) |
        (road(1, 0) ? 2 : 0) |
        (road(0, 1) ? 4 : 0) |
        (road(-1, 0) ? 8 : 0);
    return 'road_$mask';
  }

  final lot = city.lotAt(x, y);
  // The family's own buildings; the Ferris wheel is drawn, turning.
  for (final MapEntry(key: project, value: at) in city.projectPlots.entries) {
    if (at == (x, y)) {
      return project == FamilyProject.ferrisWheel
          ? null
          : 'project_${project.name}';
    }
  }
  if (lot == null) {
    // The same few plots have trees as before, now the kit's, turning in
    // the autumn.
    if (n(11) >= 0.28) return null;
    final autumn = month >= 9 && month <= 11;
    return autumn && n(13) < 0.7
        ? 'treefall_${pick(_autumnTrees, 12)}'
        : 'tree_${pick(_trees, 12)}';
  }
  // Being built today: a crane over a concrete frame, a dig with a piling
  // rig, or a frame going up beside a smaller crane.
  if (city.underConstruction(x, y)) return 'site_${pick(_sites, 61)}';
  final size = city.sizeOf(x, y);
  return switch (lot.zone) {
    Zone.home => 'home${size}_${pick(_homes[size], 21)}',
    Zone.shop => 'shop${size}_0',
    Zone.park => 'park${size}_${pick(_parks[size], 31)}',
    Zone.market => 'market',
    Zone.road => null,
    Zone.service => switch (lot.service) {
      final service? => 'service_${service.name}',
      null => null,
    },
    Zone.landmark => switch (lot.landmark) {
      Landmark.castle => 'landmark_castle',
      Landmark.bakery => 'landmark_bakery',
      _ => null,
    },
  };
}
