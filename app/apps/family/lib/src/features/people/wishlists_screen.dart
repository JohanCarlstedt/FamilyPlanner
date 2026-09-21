import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'celebrations_screen.dart' show peopleProvider;
import 'wishlist_screen.dart';

/// Everyone's gift list, in one place.
///
/// The lists, and the part that makes them work — a claim the owner never
/// sees — have existed since the wishlist was built. What did not exist
/// was any way to reach them: the only door was the search box, so unless
/// you already knew to type a name, the feature was invisible and the
/// family reasonably believed it was not there.
///
/// Whose list is whose is the whole of this screen. Opening your own
/// shows what you asked for; opening someone else's shows theirs, and
/// what the rest of the family has quietly claimed.
class WishlistsScreen extends ConsumerWidget {
  const WishlistsScreen({super.key});

  static const segment = 'wishlists';

  /// Opens [member]'s list, making the person record it hangs off if this
  /// family has none yet.
  ///
  /// A list belongs to a *person* (kind 4), not to a member: the family
  /// keeps lists for grandparents and godchildren too. The first version
  /// of this screen handed the member's id straight to the list screen,
  /// which found no such person — and a list with no owner is a list the
  /// app cannot tell is yours. It showed the owner what everyone had
  /// claimed, which is the one thing the feature exists to hide.
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    Member member, {
    String? personId,
  }) async {
    var id = personId;
    if (id == null) {
      final store = await ref.read(familyStoreProvider.future);
      id = await store.savePerson(
        PersonPayload.write(name: member.displayName, memberId: member.id),
        id: FamilyStore.personIdForMember(member.id),
        timeZone: familyTimeZone,
      );
    }
    if (!context.mounted) return;
    final opening = id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WishlistScreen(personId: opening),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final me = ref.watch(membershipProvider).value?.memberId;
    final listed = [
      for (final m in members)
        if (m.isActive && m.role != MemberRole.helper) m,
    ];
    // Watched, not read on tap: a provider nobody is listening to answers
    // "loading" the first time it is read, which sent the screen off to
    // create a person record that already existed.
    final people = ref.watch(peopleProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wishlists)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.wishlistsHelp,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          for (final (i, m) in listed.indexed)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: MemberStyle.colorOf(m, i),
                child: Text(
                  MemberStyle.initialsFor(listed)[m.id] ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                m.id == me ? l10n.wishlistMine(m.displayName) : m.displayName,
              ),
              subtitle: Text(
                m.id == me ? l10n.wishlistMineHint : l10n.wishlistTheirsHint,
              ),
              onTap: () => open(
                context,
                ref,
                m,
                personId: people
                    .where((p) => p.$2.memberId == m.id)
                    .firstOrNull
                    ?.$1,
              ),
            ),
        ],
      ),
    );
  }
}
