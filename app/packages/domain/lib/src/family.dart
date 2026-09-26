/// Spec §2. A helper (babysitter, grandparent) sees the calendar of the
/// children they cover, for a time, and can be the one responsible.
enum MemberRole { parent, child, helper }

/// Spec §2: a child's capability follows their tier, set by a parent and
/// independent of their age. Parents have none.
enum MaturityTier {
  /// Under about 8: read-only, today and tomorrow, icon-led.
  little,

  /// About 8–12.
  kid,

  /// About 13+: adds their own events, can be responsible for younger ones.
  teen,
}

/// Family membership, per spec §3 `member`. Only the fields domain logic
/// needs; accounts, devices and avatars live elsewhere.
class Member {
  final String id;
  final String displayName;
  final MemberRole role;

  /// Per-member calendar colour as `#RRGGBB`. Null until a parent picks one,
  /// in which case the UI assigns from its default palette.
  final String? color;

  /// Children only; null for parents.
  final MaturityTier? tier;

  /// Set when they've left or been removed (spec §9 `membership_end`). A
  /// former member keeps their name in history and nothing else.
  final DateTime? endedAt;

  /// The children this member shares with this family from another home
  /// (spec §3 custody): a co-parent sees and edits what concerns them only.
  final Set<String> coParentOf;

  /// A relative, such as a grandparent: a helper who sees the family's gift
  /// lists and can take a gift to buy, and nothing else of the family's.
  final bool relative;

  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    this.color,
    this.tier,
    this.endedAt,
    this.coParentOf = const {},
    this.relative = false,
  });

  bool get isCoParent => coParentOf.isNotEmpty;

  bool get isRelative => relative && role == MemberRole.helper;

  bool get isActive => endedAt == null;

  bool get isChild => role == MemberRole.child;

  bool get isParent => role == MemberRole.parent;

  /// Only parents hold the `adults` key; a helper holds their own group's.
  bool get canHoldAdults => isParent;
}

/// Who may be marked responsible for an event with [participants].
///
/// Spec §2: parents and helpers for anyone, and a teen for a younger
/// sibling — pickup duty is a thing a thirteen-year-old can hold.
///
/// Beyond the spec, and deliberately: a child of any tier may be
/// responsible for an event that is only theirs. "Who is taking Maja to
/// football" has an honest answer when Maja walks there herself, and
/// refusing to record it leaves the event flagged as nobody's for as long
/// as it exists. What a young child still cannot be is the answer for a
/// sibling; that is what the teen tier is for.
List<Member> whoCanBeResponsible(
  List<Member> members,
  List<String> participants,
) {
  final children = {
    for (final m in members)
      if (m.isChild && participants.contains(m.id)) m.id,
  };
  return [
    for (final m in members)
      if (m.isActive)
        if (!m.isChild ||
            m.tier == MaturityTier.teen ||
            (children.length == 1 && children.contains(m.id)))
          m,
  ];
}
