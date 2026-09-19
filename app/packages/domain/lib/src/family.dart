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

  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    this.color,
    this.tier,
    this.endedAt,
    this.coParentOf = const {},
  });

  bool get isCoParent => coParentOf.isNotEmpty;

  bool get isActive => endedAt == null;

  bool get isChild => role == MemberRole.child;

  bool get isParent => role == MemberRole.parent;

  /// Only parents hold the `adults` key; a helper holds their own group's.
  bool get canHoldAdults => isParent;
}
