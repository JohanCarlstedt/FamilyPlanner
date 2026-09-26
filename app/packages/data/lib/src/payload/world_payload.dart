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
    List<CityLot>? city,
    List<Sale>? sales,
    List<Gift>? gifts,
    List<CityGift>? presents,
    String? goal,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', memberId)
      ..setText('theme', theme.name)
      ..setNestedList('placed', [for (final x in placements) x.toPayload()]);
    // Beside the older placements, never instead of them (invariant 3):
    // a world placed in before the city existed keeps what it had.
    if (city != null) {
      // Entries a newer version wrote and this one cannot read are kept
      // as they were. Rewriting the list from what this version
      // understood would quietly delete them.
      final unread = [
        for (final e in p.nestedList('city') ?? const <Payload>[])
          if (_readLot(e) == null) e,
      ];
      p.setNestedList('city', [
        for (final l in city) _lotPayload(l),
        ...unread,
      ]);
    }
    if (sales != null) {
      p.setNestedList('sales', [
        for (final s in sales)
          Payload.map()
            ..setText('id', s.id)
            ..setText('good', s.good.name)
            ..setInteger('count', s.count)
            ..setText('at', s.at.toUtc().toIso8601String()),
      ]);
    }
    if (gifts != null) {
      p.setNestedList('gifts', [
        for (final g in gifts)
          Payload.map()
            ..setText('good', g.good.name)
            ..setInteger('count', g.count)
            ..setText('at', g.at.toUtc().toIso8601String()),
      ]);
    }
    if (presents != null) {
      p.setNestedList('presents', [
        for (final g in presents)
          Payload.map()
            ..setText('to', g.to)
            ..setText('at', g.at.toUtc().toIso8601String())
            ..setInteger('coins', g.coins == 0 ? null : g.coins)
            ..setText('good', g.good?.name)
            ..setInteger('count', g.count == 0 ? null : g.count)
            ..setText('note', g.note),
      ]);
    }
    // Empty clears it.
    if (goal != null) p.setText('goal', goal.isEmpty ? null : goal);
    return WorldPayload._(p);
  }

  static CityLot? _readLot(Payload p) => switch ((
    p.integer('x'),
    p.integer('y'),
    Zone.values.asNameMap()[p.text('zone')],
    DateTime.tryParse(p.text('at') ?? ''),
  )) {
    (final x?, final y?, final zone?, final at?) => CityLot(
      x: x,
      y: y,
      zone: zone,
      at: at,
      good: Good.values.asNameMap()[p.text('good')],
      landmark: Landmark.values.asNameMap()[p.text('landmark')],
      service: Service.values.asNameMap()[p.text('service')],
      sport: Sport.values.asNameMap()[p.text('sport')],
      paid: _counted(p.texts('paid')),
      // A path this version does not know is left out, not guessed at;
      // the building keeps the size it counts for.
      upgrades: [
        for (final u in p.nestedList('upgrades') ?? const <Payload>[])
          if ((
            UpgradePath.values.asNameMap()[u.text('path')],
            DateTime.tryParse(u.text('at') ?? ''),
          )
              case (final path?, final at?))
            Upgrade(path, at),
      ],
    ),
    _ => null,
  };

  /// Goods listed one entry each, counted.
  static Map<Good, int> _counted(List<String>? names) {
    final out = <Good, int>{};
    for (final n in names ?? const <String>[]) {
      if (Good.values.asNameMap()[n] case final g?) out[g] = (out[g] ?? 0) + 1;
    }
    return out;
  }

  static Payload _lotPayload(CityLot l) => Payload.map()
    ..setInteger('x', l.x)
    ..setInteger('y', l.y)
    ..setText('zone', l.zone.name)
    ..setText('at', l.at.toUtc().toIso8601String())
    ..setText('good', l.good?.name)
    ..setText('landmark', l.landmark?.name)
    ..setText('service', l.service?.name)
    ..setText('sport', l.sport?.name)
    ..setNestedList('upgrades', [
      for (final u in l.upgrades)
        Payload.map()
          ..setText('path', u.path.name)
          ..setText('at', u.at.toUtc().toIso8601String()),
    ])
    ..setTexts('paid', [
      for (final MapEntry(key: g, value: n) in l.paid.entries)
        for (var i = 0; i < n; i++) g.name,
    ]);

  /// What the child has built in their city. A zone this version does not
  /// know is left out of the city but kept in the payload.
  List<CityLot> get city => [
    for (final p in payload.nestedList('city') ?? const <Payload>[])
      ?_readLot(p),
  ];

  /// Goods this child sold at their trading house.
  List<Sale> get sales => [
    for (final p in payload.nestedList('sales') ?? const <Payload>[])
      if ((
        p.text('id'),
        Good.values.asNameMap()[p.text('good')],
        p.integer('count'),
        DateTime.tryParse(p.text('at') ?? ''),
      )
          case (final id?, final good?, final count?, final at?))
        Sale(id: id, member: memberId, good: good, count: count, at: at),
  ];

  /// Goods this child gave to the family's project.
  List<Gift> get gifts => [
    for (final p in payload.nestedList('gifts') ?? const <Payload>[])
      if ((
        Good.values.asNameMap()[p.text('good')],
        p.integer('count'),
        DateTime.tryParse(p.text('at') ?? ''),
      )
          case (final good?, final count?, final at?))
        Gift(member: memberId, good: good, count: count, at: at),
  ];

  /// Presents this member, a parent, has given: to a child's city or to
  /// the family's project. Kept with the giver, so a present never has to
  /// be written into someone else's city.
  List<CityGift> get presents => [
    for (final p in payload.nestedList('presents') ?? const <Payload>[])
      if ((p.text('to'), DateTime.tryParse(p.text('at') ?? ''))
          case (final to?, final at?))
        CityGift(
          from: memberId,
          to: to,
          at: at,
          coins: p.integer('coins') ?? 0,
          good: Good.values.asNameMap()[p.text('good')],
          count: p.integer('count') ?? 0,
          note: p.text('note'),
        ),
  ];

  /// What the child is saving for, as `landmark:castle` or
  /// `service:fire`; null when nothing.
  String? get goal => payload.text('goal');

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
