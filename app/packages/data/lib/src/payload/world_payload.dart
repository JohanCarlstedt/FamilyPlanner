import 'package:domain/domain.dart';

import 'payload.dart';

/// Which kind of world a child has chosen (spec section 3,
/// "Contributions"). The same idea in four clothes, so a fourteen-year-old
/// is not handed flowers and no two children's worlds line up to compare.
enum WorldTheme { garden, aquarium, space, town }

/// One thing a child has put somewhere: which world it belongs to, where
/// in it, and what they chose to grow there.
class WorldPlacement {
  const WorldPlacement({
    required this.level,
    required this.spot,
    required this.thing,
    required this.at,
  });

  /// The world it is in, from 1. A finished world keeps its things.
  final int level;

  /// Where in that world, from 0.
  final int spot;

  /// What it is, as a name the theme knows ("sunflower", "clownfish").
  /// A name a later version does not recognise is still kept and drawn as
  /// something, never dropped (invariant 3).
  final String thing;

  /// When it was put there, so it can be a sprout on the day and grown
  /// after.
  final DateTime at;

  Payload toPayload() => Payload.map()
    ..setInteger('level', level)
    ..setInteger('spot', spot)
    ..setText('thing', thing)
    ..setText('at', at.toUtc().toIso8601String());

  static WorldPlacement? read(Payload p) {
    final level = p.integer('level');
    final spot = p.integer('spot');
    final thing = p.text('thing');
    final at = DateTime.tryParse(p.text('at') ?? '');
    if (level == null || spot == null || thing == null || at == null) {
      return null;
    }
    return WorldPlacement(level: level, spot: spot, thing: thing, at: at);
  }
}

/// A child's world (kind 31): the theme they chose and what they have put
/// where. How far they have come is not in here — it is counted from what
/// they have done (`worldOf` in domain), so there is nothing to edit that
/// would move them up.
class WorldPayload {
  WorldPayload._(this.payload);

  static const version = 1;

  factory WorldPayload.read(Payload payload) => WorldPayload._(payload);

  factory WorldPayload.write({
    Payload? existing,
    required String memberId,
    required WorldTheme theme,
    List<WorldPlacement> placements = const [],
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', memberId)
      ..setText('theme', theme.name)
      ..setNestedList('placed', [for (final x in placements) x.toPayload()]);
    return WorldPayload._(p);
  }

  final Payload payload;

  String get memberId => payload.text('member') ?? '';

  WorldTheme get theme =>
      WorldTheme.values.asNameMap()[payload.text('theme')] ?? WorldTheme.garden;

  List<WorldPlacement> get placements => [
    for (final p in payload.nestedList('placed') ?? const <Payload>[])
      ?WorldPlacement.read(p),
  ];

  /// What is placed in [level], one per spot. If two devices ever placed
  /// something in the same spot, the later one is what is there.
  Map<int, WorldPlacement> placedIn(int level) {
    final out = <int, WorldPlacement>{};
    for (final x in placements) {
      if (x.level != level) continue;
      final was = out[x.spot];
      if (was == null || x.at.isAfter(was.at)) out[x.spot] = x;
    }
    return out;
  }

  /// Seeds this child has earned in their current world but not yet put
  /// anywhere.
  int waiting(WorldProgress progress) {
    final placed = placedIn(progress.level).length;
    final left = progress.filled - placed;
    return left > 0 ? left : 0;
  }
}
