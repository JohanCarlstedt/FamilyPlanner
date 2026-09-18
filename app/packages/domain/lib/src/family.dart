enum MemberRole { parent, child }

/// Family membership, per spec §3 `member`. Only the fields domain logic
/// needs; accounts, devices and avatars live elsewhere.
class Member {
  final String id;
  final String displayName;
  final MemberRole role;

  /// Per-member calendar colour as `#RRGGBB`. Null until a parent picks one,
  /// in which case the UI assigns from its default palette.
  final String? color;

  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    this.color,
  });

  bool get isChild => role == MemberRole.child;
}
