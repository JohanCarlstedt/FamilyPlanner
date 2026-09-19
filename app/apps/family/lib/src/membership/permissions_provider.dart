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
  final me = members.where((m) => m.id == membership.memberId).firstOrNull;
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
