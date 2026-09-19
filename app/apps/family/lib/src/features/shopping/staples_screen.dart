import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import 'shopping_providers.dart';

/// The family's staples (spec §4 `template`): what goes on every list.
final staplesIdProvider = FutureProvider<String>((ref) async {
  final store = await ref.watch(familyStoreProvider.future);
  return store.staplesList(name: 'staples');
});

class StaplesScreen extends ConsumerStatefulWidget {
  const StaplesScreen({super.key});

  static const segment = 'staples';

  @override
  ConsumerState<StaplesScreen> createState() => _StaplesScreenState();
}

class _StaplesScreenState extends ConsumerState<StaplesScreen> {
  final _add = TextEditingController();
  final _focus = FocusNode();
  var _saving = Future<void>.value();

  @override
  void dispose() {
    _add.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addTyped() {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    _add.clear();
    _focus.requestFocus();
    _saving = _saving.then((_) async {
      final store = await ref.read(familyStoreProvider.future);
      final staples = await ref.read(staplesIdProvider.future);
      await store.addToList(staples, [
        ShoppingLine.fromIngredient(
          IngredientLine.parse(text),
          IngredientCatalogue.swedish,
        ),
      ], source: (_) => const ItemSource(type: 'manual'));
      ref.read(syncControllerProvider.notifier).syncNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final staplesId = ref.watch(staplesIdProvider).value;
    final items = [
      for (final i
          in ref.watch(shoppingItemsProvider).value ??
              const <(String, ShoppingItemPayload)>[])
        if (i.$2.listId == staplesId) i,
    ]..sort((a, b) => a.$2.name.compareTo(b.$2.name));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.staples)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _add,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _addTyped(),
              decoration: InputDecoration(
                hintText: l10n.staplesHint,
                prefixIcon: const Icon(Icons.add),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          for (final (id, item) in items)
            Dismissible(
              key: ValueKey(id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) async {
                final store = await ref.read(familyStoreProvider.future);
                await store.delete(ObjectKind.shoppingListItem, id);
              },
              background: Container(
                color: Theme.of(context).colorScheme.errorContainer,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(l10n.removeItem),
              ),
              child: ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(item.describe()),
              ),
            ),
        ],
      ),
    );
  }
}
