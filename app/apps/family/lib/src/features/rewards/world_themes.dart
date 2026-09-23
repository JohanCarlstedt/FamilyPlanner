import 'package:family_data/family_data.dart';

import '../../common/l10n.dart';

/// Something a child can put in their world, and how much they must have
/// done before it is offered.
class WorldThing {
  const WorldThing(this.key, this.symbol, this.unlocksAt);

  /// Stored in the world payload. Never rename one: a child's world keeps
  /// the key it was placed with.
  final String key;

  /// Drawn as plain Unicode, like emoji everywhere else in the app: every
  /// phone already has pictures of fish and rockets, and a seven-year-old
  /// reads them faster than any icon.
  final String symbol;

  /// Seeds earned, ever, before this is offered. The first few are there
  /// from the start, so the first seed is never a disappointment.
  final int unlocksAt;
}

/// One theme's things, the sprout shown on the day something is placed,
/// and the name a child sees.
class WorldLook {
  const WorldLook(this.theme, this.sprout, this.things);

  final WorldTheme theme;

  /// What a thing looks like on the day it is placed. It is its full self
  /// from the next day, which is a reason to come back that is not a nag.
  final String sprout;

  final List<WorldThing> things;

  /// What [seeds] earned so far have unlocked, in the order they unlock.
  List<WorldThing> unlocked(int seeds) => [
    for (final t in things)
      if (t.unlocksAt <= seeds) t,
  ];

  /// The next thing still to come, and how many more seeds it needs.
  (WorldThing, int)? next(int seeds) {
    for (final t in things) {
      if (t.unlocksAt > seeds) return (t, t.unlocksAt - seeds);
    }
    return null;
  }

  /// How a placed thing is drawn. A key this version does not know — from
  /// a newer version, or a theme changed since — is still drawn as
  /// something rather than dropped.
  String symbolFor(String key) =>
      things.where((t) => t.key == key).firstOrNull?.symbol ??
      _anyTheme(key) ??
      '•';

  static String? _anyTheme(String key) {
    for (final look in all.values) {
      for (final t in look.things) {
        if (t.key == key) return t.symbol;
      }
    }
    return null;
  }

  static final all = <WorldTheme, WorldLook>{
    WorldTheme.garden: const WorldLook(WorldTheme.garden, '🌱', [
      WorldThing('tulip', '🌷', 0),
      WorldThing('sunflower', '🌻', 0),
      WorldThing('daisy', '🌼', 0),
      WorldThing('tree', '🌳', 8),
      WorldThing('strawberry', '🍓', 12),
      WorldThing('bee', '🐝', 20),
      WorldThing('butterfly', '🦋', 28),
      WorldThing('ladybird', '🐞', 36),
      WorldThing('mushroom', '🍄', 44),
      WorldThing('hedgehog', '🦔', 56),
    ]),
    WorldTheme.aquarium: const WorldLook(WorldTheme.aquarium, '🫧', [
      WorldThing('fish', '🐟', 0),
      WorldThing('tropical', '🐠', 0),
      WorldThing('seaweed', '🌿', 0),
      WorldThing('shell', '🐚', 8),
      WorldThing('crab', '🦀', 12),
      WorldThing('octopus', '🐙', 20),
      WorldThing('turtle', '🐢', 28),
      WorldThing('puffer', '🐡', 36),
      WorldThing('squid', '🦑', 44),
      WorldThing('dolphin', '🐬', 56),
    ]),
    WorldTheme.space: const WorldLook(WorldTheme.space, '✨', [
      WorldThing('star', '⭐', 0),
      WorldThing('moon', '🌙', 0),
      WorldThing('comet', '☄️', 0),
      WorldThing('planet', '🪐', 8),
      WorldThing('satellite', '🛰️', 12),
      WorldThing('rocket', '🚀', 20),
      WorldThing('alien', '👽', 28),
      WorldThing('earth', '🌍', 36),
      WorldThing('galaxy', '🌌', 44),
      WorldThing('ufo', '🛸', 56),
    ]),
    WorldTheme.town: const WorldLook(WorldTheme.town, '🚧', [
      WorldThing('house', '🏠', 0),
      WorldThing('cottage', '🏡', 0),
      WorldThing('park', '🌳', 0),
      WorldThing('shop', '🏪', 8),
      WorldThing('bus', '🚌', 12),
      WorldThing('school', '🏫', 20),
      WorldThing('wheel', '🎡', 28),
      WorldThing('firetruck', '🚒', 36),
      WorldThing('castle', '🏰', 44),
      WorldThing('train', '🚂', 56),
    ]),
  };
}

String themeName(AppLocalizations l10n, WorldTheme theme) => switch (theme) {
  WorldTheme.garden => l10n.worldGarden,
  WorldTheme.aquarium => l10n.worldAquarium,
  WorldTheme.space => l10n.worldSpace,
  WorldTheme.town => l10n.worldTown,
};
