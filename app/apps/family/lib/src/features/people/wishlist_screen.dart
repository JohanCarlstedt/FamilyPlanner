import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'celebrations_screen.dart';

final wishlistsProvider = StreamProvider<List<(String, WishlistPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchWishlists();
});

final wishlistItemsProvider =
    StreamProvider<List<(String, WishlistItemPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchWishlistItems();
    });

/// Claims this device's member may see: none on their own lists.
final wishlistClaimsProvider =
    StreamProvider<List<(String, WishlistClaimPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      final me = await ref.watch(
        membershipProvider.selectAsync((m) => m?.memberId),
      );
      if (me == null) return;
      yield* store.watchClaimsFor(me);
    });

/// One person's current wishlist (spec §3 "Wishlists").
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final person =
        (ref.watch(peopleProvider).value ?? const <(String, PersonPayload)>[])
            .where((p) => p.$1 == personId)
            .firstOrNull
            ?.$2;
    final me = ref.watch(membershipProvider).value?.memberId;
    final mine = person?.memberId != null && person?.memberId == me;
    final list =
        (ref.watch(wishlistsProvider).value ??
                const <(String, WishlistPayload)>[])
            .where((l) => l.$2.personId == personId && l.$2.active)
            .firstOrNull;
    final items =
        [
          for (final i
              in ref.watch(wishlistItemsProvider).value ??
                  const <(String, WishlistItemPayload)>[])
            if (i.$2.wishlistId == list?.$1) i,
        ]..sort((a, b) {
          final r = (a.$2.received ? 1 : 0).compareTo(b.$2.received ? 1 : 0);
          return r != 0 ? r : a.$2.title.compareTo(b.$2.title);
        });
    final claims = mine
        ? const <(String, WishlistClaimPayload)>[]
        : ref.watch(wishlistClaimsProvider).value ??
              const <(String, WishlistClaimPayload)>[];
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final name = person?.label ?? person?.name ?? '';

    Future<String> listId() async {
      if (list != null) return list.$1;
      final store = await ref.read(familyStoreProvider.future);
      return store.saveWishlist(
        WishlistPayload.write(
          personId: personId,
          name: l10n.wishlistName(name, DateTime.now().year),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wishlistFor(name)),
        actions: [
          if (list != null)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.newWishlist),
                        content: Text(l10n.newWishlistBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              MaterialLocalizations.of(context)
                                  .cancelButtonLabel,
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l10n.newWishlist),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    final store = await ref.read(familyStoreProvider.future);
                    await store.carryForward(
                      list.$1,
                      name: l10n.wishlistName(name, DateTime.now().year + 1),
                    );
                    ref.read(syncControllerProvider.notifier).syncNow();
                  },
                  child: Text(l10n.newWishlist),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final wish = await showDialog<WishlistItemPayload>(
            context: context,
            builder: (_) => const _WishDialog(),
          );
          if (wish == null) return;
          final id = await listId();
          final store = await ref.read(familyStoreProvider.future);
          await store.saveWishlistItem(
            WishlistItemPayload.write(
              wishlistId: id,
              title: wish.title,
              url: wish.url,
              note: wish.note,
            ),
          );
          ref.read(syncControllerProvider.notifier).syncNow();
        },
        icon: const Icon(Icons.card_giftcard),
        label: Text(l10n.addWish),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.wishlistEmpty,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (id, item) in items)
            () {
              final claim = claims
                  .where((c) => c.$2.itemId == id)
                  .firstOrNull
                  ?.$2;
              final byMe = claim?.claimedBy == me;
              return Opacity(
                opacity: item.received ? 0.5 : 1,
                child: ListTile(
                  leading: Icon(
                    item.received
                        ? Icons.check_circle
                        : claim != null
                        ? Icons.shopping_bag
                        : Icons.card_giftcard,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    [
                      ?item.note,
                      if (claim != null && !mine)
                        l10n.wishClaimedBy(names[claim.claimedBy] ?? '—'),
                      if (item.received) l10n.wishReceived,
                    ].join(' · '),
                  ),
                  onTap: item.url == null
                      ? null
                      : () => launchUrl(
                          Uri.parse(item.url!),
                          mode: LaunchMode.externalApplication,
                        ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (what) async {
                      final store = await ref.read(familyStoreProvider.future);
                      switch (what) {
                        case 'claim':
                          await store.claimWish(id);
                        case 'unclaim':
                          await store.unclaimWish(id);
                        case 'received':
                          await store.saveWishlistItem(
                            WishlistItemPayload.write(
                              existing: item.payload,
                              wishlistId: item.wishlistId,
                              title: item.title,
                              url: item.url,
                              note: item.note,
                              size: item.size,
                              received: !item.received,
                            ),
                            id: id,
                          );
                        case 'remove':
                          await store.delete(ObjectKind.wishlistItem, id);
                      }
                      ref.read(syncControllerProvider.notifier).syncNow();
                    },
                    itemBuilder: (_) => [
                      // The owner can't claim: they'd see it.
                      if (!mine && claim == null && !item.received)
                        PopupMenuItem(
                          value: 'claim',
                          child: Text(l10n.wishClaim),
                        ),
                      if (!mine && byMe)
                        PopupMenuItem(
                          value: 'unclaim',
                          child: Text(l10n.wishUnclaim),
                        ),
                      PopupMenuItem(
                        value: 'received',
                        child: Text(l10n.wishReceived),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(l10n.removeItem),
                      ),
                    ],
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

class _WishDialog extends StatefulWidget {
  const _WishDialog();

  @override
  State<_WishDialog> createState() => _WishDialogState();
}

class _WishDialogState extends State<_WishDialog> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addWish),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.wishTitle),
          ),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: l10n.wishLink),
          ),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.wishNote),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              WishlistItemPayload.write(
                wishlistId: '',
                title: _title.text.trim(),
                url: _url.text.trim().isEmpty ? null : _url.text.trim(),
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
