import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final me = ref.watch(membershipProvider).value?.memberId;
    final people = [
      for (final m in members)
        if (m.isActive && m.role != MemberRole.helper) m,
    ];

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
          for (final (i, m) in people.indexed)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: MemberStyle.colorOf(m, i),
                child: Text(
                  MemberStyle.initialsFor(people)[m.id] ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                m.id == me ? l10n.wishlistMine(m.displayName) : m.displayName,
              ),
              subtitle: Text(
                m.id == me ? l10n.wishlistMineHint : l10n.wishlistTheirsHint,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WishlistScreen(personId: m.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
