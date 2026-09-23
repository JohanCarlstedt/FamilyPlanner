/// Spec section 3, "Contributions": the family jar and each child's world.
///
/// Rewards that rank nobody. The jar counts what the whole family did this
/// week; a child's world counts only what they did, is never shown beside
/// a sibling's, and never loses anything for a quiet week. Both are
/// counted from what already happened, never stored, so there is no score
/// to edit and nothing new for the server to hold.

/// One finished thing, reduced to what the rewards need to know.
class Contribution {
  const Contribution({
    required this.memberId,
    required this.at,
    required this.growsWorld,
  });

  /// Who did it — not who it was assigned to.
  final String memberId;

  /// When it was finished, as an instant.
  final DateTime at;

  /// Whether it counts towards the member's own world as well as the jar.
  ///
  /// False for homework no parent has seen done yet: homework "done" is
  /// self-reported, and rewarding it directly rewards ticking the box.
  final bool growsWorld;
}

/// How full the family's jar is this week.
class JarProgress {
  const JarProgress({required this.filled, required this.size});

  /// Never more than [size]: a full jar is full, not 140 per cent.
  final int filled;

  /// What the family decided a full jar is.
  final int size;

  bool get isFull => filled >= size;
}

/// The jar for the week in [from, until): everyone's, whoever did it.
///
/// The bounds are instants, computed by the caller from the family's
/// Monday in its own zone (invariant 4), so this stays free of zones.
JarProgress familyJar(
  Iterable<Contribution> contributions, {
  required DateTime from,
  required DateTime until,
  required int size,
}) {
  var filled = 0;
  for (final c in contributions) {
    if (!c.at.isBefore(from) && c.at.isBefore(until)) filled++;
  }
  return JarProgress(filled: filled < size ? filled : size, size: size);
}

/// Where a child's own world has got to.
class WorldProgress {
  const WorldProgress({
    required this.seeds,
    required this.level,
    required this.filled,
    required this.room,
  });

  /// Room in the first world. Small enough that a child doing two
  /// things a week fills it in about a month.
  static const firstRoom = 8;

  /// Each world after is this much roomier...
  static const growth = 4;

  /// ...up to here. Without a ceiling the fourth or fifth world would
  /// take a term to fill, and a goal that far away is not one.
  static const largestRoom = 24;

  static int roomAt(int level) {
    final room = firstRoom + growth * (level - 1);
    return room < largestRoom ? room : largestRoom;
  }

  /// Everything this child has ever earned towards it.
  final int seeds;

  /// Which world they are on, from 1.
  final int level;

  /// How much of the current world is filled.
  final int filled;

  /// How much room the current world has.
  final int room;

  bool get isFull => filled >= room;
}

/// [memberId]'s own world, counted from everything that grows it.
///
/// A full world moves straight up a level: exactly full is the moment,
/// not one seed later, and what is left over starts the next world.
WorldProgress worldOf(String memberId, Iterable<Contribution> contributions) {
  var seeds = 0;
  for (final c in contributions) {
    if (c.memberId == memberId && c.growsWorld) seeds++;
  }
  var level = 1;
  var left = seeds;
  while (left >= WorldProgress.roomAt(level)) {
    left -= WorldProgress.roomAt(level);
    level++;
  }
  return WorldProgress(
    seeds: seeds,
    level: level,
    filled: left,
    room: WorldProgress.roomAt(level),
  );
}
