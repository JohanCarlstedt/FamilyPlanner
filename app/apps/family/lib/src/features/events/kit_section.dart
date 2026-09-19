import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../shopping/shopping_providers.dart';

final equipmentSetsProvider =
    StreamProvider<List<(String, EquipmentSetPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchEquipmentSets();
    });

/// Kit lists on an event (spec §3 "Equipment lists"): optional, shared by
/// every occurrence. Ticking is per occurrence, kept on this phone only,
/// and forgotten once the day has passed: no history, no scores.
class KitSection extends ConsumerStatefulWidget {
  const KitSection({
    super.key,
    required this.eventId,
    required this.title,
    required this.setIds,
    required this.occurrence,
    required this.mayEdit,
  });

  final String eventId;
  final String title;
  final List<String> setIds;

  /// The occurrence shown; ticks belong to it.
  final DateTime? occurrence;
  final bool mayEdit;

  @override
  ConsumerState<KitSection> createState() => _KitSectionState();
}

class _KitSectionState extends ConsumerState<KitSection> {
  final _ticked = <String>{};

  String get _prefix =>
      'kit/${widget.eventId}/${widget.occurrence?.toIso8601String() ?? 'next'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ref.read(devicePreferencesProvider.future);
    final stored = await prefs.read(_prefix);
    if (stored != null && mounted) {
      setState(
        () => _ticked.addAll(stored.split('\n').where((s) => s.isNotEmpty)),
      );
    }
  }

  Future<void> _tick(String key, bool on) async {
    setState(() => on ? _ticked.add(key) : _ticked.remove(key));
    final prefs = await ref.read(devicePreferencesProvider.future);
    await prefs.write(_prefix, _ticked.join('\n'));
  }

  Future<void> _replace(KitItem item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final store = await ref.read(familyStoreProvider.future);
    var listId = await ref.read(currentListProvider.future);
    if (listId == null) {
      listId = await store.saveShoppingList(
        ShoppingListPayload.write(name: l10n.shoppingDefaultList),
      );
      await ref.read(currentListProvider.notifier).choose(listId);
    }
    // Spec §3: the one moment the family notices kit needs replacing.
    await store.addToList(
      listId,
      [ShoppingLine(name: item.name)],
      source: (_) => ItemSource(
        type: 'manual',
        id: 'kit:${widget.eventId}:${item.name}',
        label: widget.title,
      ),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
    final name = (await ref.read(shoppingListsProvider.future))
        .where((l) => l.$1 == listId)
        .firstOrNull
        ?.$2
        .name;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.kitToShopping(item.name, name ?? ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sets = {
      for (final s
          in ref.watch(equipmentSetsProvider).value ??
              const <(String, EquipmentSetPayload)>[])
        s.$1: s.$2,
    };
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final attached = [
      for (final id in widget.setIds)
        if (sets[id] case final set?) (id, set),
    ];
    if (attached.isEmpty && !widget.mayEdit) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.kit, style: theme.textTheme.titleSmall),
        for (final (setId, set) in attached) ...[
          if (attached.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(set.name, style: theme.textTheme.labelLarge),
            ),
          for (final (i, item) in set.items.indexed)
            GestureDetector(
              onLongPress: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => ListTile(
                  leading: const Icon(Icons.add_shopping_cart),
                  title: Text(l10n.kitNeedsReplacing),
                  onTap: () {
                    Navigator.pop(context);
                    _replace(item);
                  },
                ),
              ),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _ticked.contains('$setId/$i'),
                onChanged: (on) => _tick('$setId/$i', on ?? false),
                title: Text(item.name),
                subtitle: item.forMember == null && item.note == null
                    ? null
                    : Text([?names[item.forMember], ?item.note].join(' · ')),
              ),
            ),
        ],
        if (widget.mayEdit)
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _KitDialog(
                ref: ref,
                eventId: widget.eventId,
                attached: widget.setIds,
              ),
            ),
            icon: const Icon(Icons.backpack_outlined),
            label: Text(l10n.addKit),
          ),
      ],
    );
  }
}

/// Picks the kit lists an event carries, or makes a new one.
class _KitDialog extends StatefulWidget {
  const _KitDialog({
    required this.ref,
    required this.eventId,
    required this.attached,
  });

  final WidgetRef ref;
  final String eventId;
  final List<String> attached;

  @override
  State<_KitDialog> createState() => _KitDialogState();
}

class _KitDialogState extends State<_KitDialog> {
  late final _chosen = {...widget.attached};
  final _name = TextEditingController();
  final _items = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _items.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sets =
        widget.ref.watch(equipmentSetsProvider).value ??
        const <(String, EquipmentSetPayload)>[];
    return AlertDialog(
      title: Text(l10n.addKit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (id, set) in sets)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _chosen.contains(id),
                onChanged: (on) =>
                    setState(() => on! ? _chosen.add(id) : _chosen.remove(id)),
                title: Text(set.name),
                subtitle: Text(set.items.map((i) => i.name).join(', ')),
              ),
            const SizedBox(height: 8),
            Text(l10n.newKit, style: Theme.of(context).textTheme.labelLarge),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.kitName,
                hintText: l10n.kitNameHint,
              ),
            ),
            TextField(
              controller: _items,
              minLines: 3,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.kitItems),
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
          onPressed: () async {
            final ref = widget.ref;
            final store = await ref.read(familyStoreProvider.future);
            final items = [
              for (final line in _items.text.split('\n'))
                if (line.trim().isNotEmpty) KitItem(name: line.trim()),
            ];
            if (_name.text.trim().isNotEmpty && items.isNotEmpty) {
              _chosen.add(
                await store.saveEquipmentSet(
                  EquipmentSetPayload.write(
                    name: _name.text.trim(),
                    items: items,
                  ),
                ),
              );
            }
            await store.setEventEquipment(widget.eventId, _chosen.toList());
            ref.read(syncControllerProvider.notifier).syncNow();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
