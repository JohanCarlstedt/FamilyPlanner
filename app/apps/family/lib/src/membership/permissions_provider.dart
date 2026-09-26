import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_repository.dart';
import 'membership.dart';

/// What the member using this device may do (spec §2). Until their profile
/// has synced, a parent's device counts as a parent's and any other as a
/// kid's: never more than the keys it holds allow.
final permissionsProvider = Provider<Permissions>((ref) {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const Permissions(null);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final found = members.where((m) => m.id == membership.memberId).firstOrNull;
  // A co-parent shares the children their arrangements name.
  final shared = {
    for (final c in ref.watch(custodyProvider))
      if (c.coParentId == membership.memberId) c.childId,
  };
  final me = found == null || shared.isEmpty
      ? found
      : Member(
          id: found.id,
          displayName: found.displayName,
          role: found.role,
          color: found.color,
          tier: found.tier,
          endedAt: found.endedAt,
          coParentOf: shared,
          relative: found.relative,
        );
  return Permissions(
    me ??
        Member(
          id: membership.memberId,
          displayName: '',
          role: membership.isParent ? MemberRole.parent : MemberRole.child,
          tier: membership.isParent ? null : MaturityTier.kid,
        ),
  );
});
