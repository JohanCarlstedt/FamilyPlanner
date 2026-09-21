import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../common/l10n.dart';
import '../more/more_screen.dart';
import '../more/recently_deleted_screen.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../membership/permissions_provider.dart';
import 'menu_screen.dart';
import 'recipes_screen.dart';
import 'staples_screen.dart';
import 'shopping_providers.dart';

String aisleName(AppLocalizations l10n, Aisle aisle) => switch (aisle) {
  Aisle.produce => l10n.aisleProduce,
  Aisle.bakery => l10n.aisleBakery,
  Aisle.dairy => l10n.aisleDairy,
  Aisle.meat => l10n.aisleMeat,
  Aisle.frozen => l10n.aisleFrozen,
  Aisle.pantry => l10n.aislePantry,
  Aisle.household => l10n.aisleHousehold,
  Aisle.other => l10n.aisleOther,
};

/// The family's shopping list (spec §4 "Shopping in the store"): grouped by
/// aisle, big targets, and what's bought folds into a dimmed footer rather
/// than vanishing, so a slip of the thumb can be undone. Works offline; ticks
/// sync when there's signal.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  static const path = '/shopping';

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _add = TextEditingController();
  final _focus = FocusNode();
  var _showBought = false;

  @override
  void dispose() {
    _add.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The first list is made on first use, so there's always one to add to.
  Future<String> _listId() async {
    final name = context.l10n.shoppingDefaultList;
    if (await ref.read(currentListProvider.future) case final id?) return id;
    final store = await ref.read(familyStoreProvider.future);
    final id = await store.saveShoppingList(
      ShoppingListPayload.write(name: name),
    );
    await ref.read(currentListProvider.notifier).choose(id);
    return id;
  }

  /// Entries are taken off the field at once and saved in order, so typing
  /// the next while the last is saving loses nothing.
  var _saving = Future<void>.value();

  void _addTyped() {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    _add.clear();
    // A pasted recipe link imports the recipe rather than buying a URL.
    if (Uri.tryParse(text) case final uri?
        when uri.scheme.startsWith('http') && uri.host.isNotEmpty) {
      _focus.unfocus();
      importRecipe(context, url: text);
      return;
    }
    _focus.requestFocus();
    _saving = _saving.then((_) async {
      final listId = await _listId();
      final store = await ref.read(familyStoreProvider.future);
      final line = ShoppingLine.fromIngredient(
        IngredientLine.parse(text),
        IngredientCatalogue.swedish,
      );
      await store.addToList(
        listId,
        [line],
        source: (l) => ItemSource(
          type: 'manual',
          id: 'manual:${const Uuid().v4()}',
          quantity: l.quantity,
          unit: l.unit,
        ),
      );
      ref.read(syncControllerProvider.notifier).syncNow();
    });
  }

  Future<void> _addStaples(String listId) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final store = await ref.read(familyStoreProvider.future);
    await store.staplesToList(listId, await ref.read(staplesIdProvider.future));
    ref.read(syncControllerProvider.notifier).syncNow();
    messenger.showSnackBar(SnackBar(content: Text(l10n.staplesAdded)));
  }

  Future<void> _toggle(String id, ShoppingItemPayload item) async {
    final store = await ref.read(familyStoreProvider.future);
    final bought = item.state == ItemState.bought;
    await store.saveShoppingItem(
      item.copyWith(
        state: bought ? ItemState.needed : ItemState.bought,
        checkedBy: ref.read(membershipProvider).value?.memberId,
        checkedAt: DateTime.now(),
      ),
      id: id,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  Future<void> _remove(String id) async {
    final store = await ref.read(familyStoreProvider.future);
    await store.delete(ObjectKind.shoppingListItem, id);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  Future<void> _clearBought(List<(String, ShoppingItemPayload)> bought) async {
    final store = await ref.read(familyStoreProvider.future);
    for (final (id, _) in bought) {
      await store.delete(ObjectKind.shoppingListItem, id);
    }
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  Future<void> _newList() async {
    final l10n = context.l10n;
    final name = TextEditingController();
    var withStaples = true;
    final created = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shoppingNewList),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.shoppingListName),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: withStaples,
                onChanged: (v) => setDialogState(() => withStaples = v!),
                title: Text(l10n.startWithStaples),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    name.dispose();
    if (created == null || created.trim().isEmpty) return;
    final store = await ref.read(familyStoreProvider.future);
    final id = await store.saveShoppingList(
      ShoppingListPayload.write(name: created.trim()),
    );
    await ref.read(currentListProvider.notifier).choose(id);
    if (withStaples) await _addStaples(id);
  }

  /// Empties the list, with a way back: clearing is one tap and an
  /// accident is cheap to make, so it says what it did and offers undo for
  /// as long as the snack bar is up.
  Future<void> _clear(String listId, bool boughtOnly) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final store = await ref.read(familyStoreProvider.future);
    if (!mounted) return;
    if (!boughtOnly) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.clearEverything),
          content: Text(l10n.clearEverythingExplain),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.clearList),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    final cleared = await store.clearShoppingList(
      listId,
      boughtOnly: boughtOnly,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
    if (cleared == 0) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.clearedItems(cleared)),
        action: SnackBarAction(
          label: l10n.undo,
          // Deleted objects are recoverable for the restore window, which
          // is what More > Recently deleted is.
          onPressed: () => context.go(
            '${MoreScreen.path}/${RecentlyDeletedScreen.segment}',
          ),
        ),
      ),
    );
  }

  /// The list as plain text, handed to whatever the family shops with —
  /// ICA's app, Coop's, a message to someone already at the shop.
  ///
  /// Not an ICA account integration: that needs their private API, which
  /// wants a personnummer and password, refuses any address outside Sweden,
  /// and is nobody's published contract. Handing over the text works with
  /// every shop's app and asks the family for nothing (docs/ica.md).
  Future<void> _sendToShop(List<(String, ShoppingItemPayload)> items) async {
    // What is still needed: a list someone has already walked is not a
    // list worth sending. `describe` is the same wording the screen shows,
    // amounts and units included.
    final text = [
      for (final (_, i) in items)
        if (i.state == ItemState.needed) i.describe(),
    ].join('\n');
    if (text.isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    final current = ref.watch(currentListProvider).value;
    final mayShop = ref.watch(permissionsProvider).shop;
    final listName =
        lists.where((l) => l.$1 == current).firstOrNull?.$2.name ??
        l10n.tabShopping;
    final items = <(String, ShoppingItemPayload)>[
      for (final i
          in ref.watch(shoppingItemsProvider).value ??
              const <(String, ShoppingItemPayload)>[])
        if (i.$2.listId == current) i,
    ];
    final needed = [
      for (final i in items)
        if (i.$2.state != ItemState.bought) i,
    ];
    final bought = [
      for (final i in items)
        if (i.$2.state == ItemState.bought) i,
    ];
    final byAisle = <Aisle, List<(String, ShoppingItemPayload)>>{};
    for (final i in needed) {
      (byAisle[i.$2.category] ??= []).add(i);
    }
    for (final group in byAisle.values) {
      group.sort((a, b) => a.$2.name.compareTo(b.$2.name));
    }

    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          tooltip: '',
          onSelected: (id) => id.isEmpty
              ? _newList()
              : ref.read(currentListProvider.notifier).choose(id),
          itemBuilder: (_) => [
            for (final (id, l) in lists)
              CheckedPopupMenuItem(
                value: id,
                checked: id == current,
                child: Text(l.name),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(value: '', child: Text(l10n.shoppingNewList)),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(listName, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: l10n.sendToShop,
              icon: const Icon(Icons.ios_share),
              onPressed: () => _sendToShop(items),
            ),
          if (items.isNotEmpty && current != null && mayShop)
            PopupMenuButton<bool>(
              tooltip: l10n.clearList,
              icon: const Icon(Icons.playlist_remove),
              onSelected: (boughtOnly) => _clear(current, boughtOnly),
              itemBuilder: (_) => [
                // The everyday one first: home from the shop, ticked items
                // gone, whatever nobody found still wanted.
                PopupMenuItem(value: true, child: Text(l10n.clearTicked)),
                PopupMenuItem(value: false, child: Text(l10n.clearEverything)),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.restaurant_outlined),
                  label: Text(l10n.menu),
                  onPressed: () => context.go(
                    '${ShoppingScreen.path}/${MenuScreen.segment}',
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.menu_book_outlined),
                  label: Text(l10n.recipes),
                  onPressed: () => context.go(
                    '${ShoppingScreen.path}/${RecipesScreen.segment}',
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.push_pin_outlined),
                  label: Text(l10n.staples),
                  onPressed: () => context.go(
                    '${ShoppingScreen.path}/${StaplesScreen.segment}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (mayShop)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _add,
                    focusNode: _focus,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addTyped(),
                    decoration: InputDecoration(
                      hintText: l10n.shoppingAddHint,
                      prefixIcon: const Icon(Icons.add),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              if (current != null && mayShop)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton.icon(
                      onPressed: () => _addStaples(current),
                      icon: const Icon(Icons.push_pin_outlined),
                      label: Text(l10n.addStaples),
                    ),
                  ),
                ),
              if (needed.isEmpty && bought.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.shoppingEmpty,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final aisle in Aisle.values)
                if (byAisle[aisle] case final group?) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      aisleName(l10n, aisle),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final (id, item) in group)
                    _ItemTile(
                      id: id,
                      item: item,
                      onToggle: () => _toggle(id, item),
                      onRemove: () => _remove(id),
                    ),
                ],
              if (bought.isNotEmpty) ...[
                const Divider(height: 32),
                ListTile(
                  title: Text(l10n.shoppingBought(bought.length)),
                  leading: Icon(
                    _showBought ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() => _showBought = !_showBought),
                  trailing: TextButton(
                    onPressed: () => _clearBought(bought),
                    child: Text(l10n.shoppingClearBought),
                  ),
                ),
                if (_showBought)
                  for (final (id, item) in bought)
                    Opacity(
                      opacity: 0.5,
                      child: _ItemTile(
                        id: id,
                        item: item,
                        onToggle: () => _toggle(id, item),
                        onRemove: () => _remove(id),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.id,
    required this.item,
    required this.onToggle,
    required this.onRemove,
  });

  final String id;
  final ShoppingItemPayload item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bought = item.state == ItemState.bought;
    final from = {for (final s in item.sources) ?s.label};
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(l10n.removeItem),
      ),
      child: CheckboxListTile(
        value: bought,
        onChanged: (_) => onToggle(),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          item.describe(),
          style: TextStyle(
            fontSize: 17,
            decoration: bought ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: from.isEmpty ? null : Text(l10n.shoppingFor(from.join(', '))),
      ),
    );
  }
}
