import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../common/cancel_editing.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../members/sizes_screen.dart';
import '../../common/dictation.dart';

String thingCategoryName(AppLocalizations l10n, ThingCategory c) => switch (c) {
  ThingCategory.clothes => l10n.thingClothes,
  ThingCategory.shoes => l10n.thingShoes,
  ThingCategory.school => l10n.thingSchool,
  ThingCategory.sport => l10n.thingSport,
  ThingCategory.home => l10n.thingHome,
  ThingCategory.gift => l10n.thingGift,
  ThingCategory.other => l10n.thingOther,
};

IconData thingCategoryIcon(ThingCategory c) => switch (c) {
  ThingCategory.clothes => Icons.checkroom,
  ThingCategory.shoes => Icons.ice_skating_outlined,
  ThingCategory.school => Icons.backpack_outlined,
  ThingCategory.sport => Icons.sports_soccer,
  ThingCategory.home => Icons.chair_outlined,
  ThingCategory.gift => Icons.card_giftcard,
  ThingCategory.other => Icons.category_outlined,
};

/// The people a thing can be for or bought by: the family, not helpers,
/// and not those who have left.
List<Member> _household(WidgetRef ref) => [
  for (final m in ref.watch(membersProvider).value ?? const <Member>[])
    if (m.role != MemberRole.helper && m.endedAt == null) m,
];

/// A things list (docs: "Inköpslistan för hela familjen"): shoes, clothes,
/// what school and football ask for. Grouped by what each thing is, for
/// the shop, or by whom it is for, for planning; what is needed soonest
/// comes first in each group.
class ThingsList extends ConsumerStatefulWidget {
  const ThingsList({
    super.key,
    required this.listId,
    required this.items,
    required this.mayShop,
    required this.onToggle,
    required this.onRemove,
    required this.onHold,
    required this.onClearBought,
  });

  final String listId;
  final List<(String, ShoppingItemPayload)> items;
  final bool mayShop;
  final void Function(String id, ShoppingItemPayload item) onToggle;
  final void Function(List<(String, ShoppingItemPayload)> lines) onRemove;
  final void Function(String id)? onHold;
  final void Function(List<(String, ShoppingItemPayload)> bought) onClearBought;

  @override
  ConsumerState<ThingsList> createState() => _ThingsListState();
}

class _ThingsListState extends ConsumerState<ThingsList> {
  final _add = TextEditingController();
  final _focus = FocusNode();
  var _byPerson = false;
  var _showBought = false;

  @override
  void dispose() {
    _add.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<(String, String)> get _names => [
    for (final m in _household(ref)) (m.id, m.displayName),
  ];

  /// What was typed, as a thing: "fotbollsskor till Oliver" is Oliver's,
  /// in Oliver's size; the kind is guessed. A pasted link opens the sheet
  /// to say what it is.
  ///
  /// [spoken] splits a list: "benskydd och fotbollsskor till Oliver" is
  /// two things, both Oliver's.
  Future<void> _addTyped({bool spoken = false}) async {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    _add.clear();
    if (Uri.tryParse(text) case final uri?
        when !spoken && uri.scheme.startsWith('http') && uri.host.isNotEmpty) {
      _focus.unfocus();
      await _edit(null, null, link: text);
      return;
    }
    if (!spoken) _focus.requestFocus();
    final cards = ref.read(sizeCardsProvider).value ?? const {};
    final store = await ref.read(familyStoreProvider.future);
    for (final (name, member) in forWhomAll(
      spoken ? spokenItems(text) : [text],
      _names,
    )) {
      await store.saveShoppingItem(
        ShoppingItemPayload.thing(
          listId: widget.listId,
          name: name,
          category: guessThingCategory(name),
          forMember: member,
          size: member == null
              ? null
              : sizeFor(name, cards[member] ?? [])?.value,
          sources: [
            ItemSource(type: 'manual', id: 'manual:${const Uuid().v4()}'),
          ],
        ),
      );
    }
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  /// Opens a thing to change it, or a new one when [id] is null.
  Future<void> _edit(
    String? id,
    ShoppingItemPayload? item, {
    String? link,
  }) async {
    final result = await showModalBottomSheet<_ThingEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ThingSheet(item: item, link: link),
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      if (id != null && item != null) widget.onRemove([(id, item)]);
      return;
    }
    final me = ref.read(membershipProvider).value?.memberId;
    final base =
        item ??
        ShoppingItemPayload.thing(
          listId: widget.listId,
          name: result.name,
          category: result.category,
          sources: [
            ItemSource(type: 'manual', id: 'manual:${const Uuid().v4()}'),
          ],
        );
    var changed = base.withThing(
      name: result.name,
      category: result.category,
      forMember: result.forMember,
      size: result.size,
      neededBy: result.neededBy,
      link: result.link,
      buyer: result.buyer,
      note: result.note,
    );
    if (result.state != base.state) {
      changed = changed.copyWith(
        state: result.state,
        checkedBy: me,
        checkedAt: DateTime.now(),
      );
    }
    final store = await ref.read(familyStoreProvider.future);
    await store.saveShoppingItem(changed, id: id);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  static int _soonestFirst(
    (String, ShoppingItemPayload) a,
    (String, ShoppingItemPayload) b,
  ) {
    final da = a.$2.neededBy, db = b.$2.neededBy;
    if (da != null && db != null && da != db) return da.compareTo(db);
    if ((da == null) != (db == null)) return da == null ? 1 : -1;
    return a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final household = _household(ref);
    final names = {for (final m in household) m.id: m.displayName};
    final cards = ref.watch(sizeCardsProvider).value ?? const {};
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;
    final needed = [
      for (final i in widget.items)
        if (i.$2.state != ItemState.bought) i,
    ]..sort(_soonestFirst);
    final bought = [
      for (final i in widget.items)
        if (i.$2.state == ItemState.bought) i,
    ];

    Widget tile((String, ShoppingItemPayload) line) => _ThingTile(
      id: line.$1,
      item: line.$2,
      names: names,
      showWho: !_byPerson,
      showKind: _byPerson,
      onToggle: () => widget.onToggle(line.$1, line.$2),
      onRemove: () => widget.onRemove([line]),
      onEdit: widget.mayShop ? () => _edit(line.$1, line.$2) : null,
      onHold: widget.onHold == null ? null : () => widget.onHold!(line.$1),
    );

    Widget header(String text, {IconData? icon, VoidCallback? onTap}) =>
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    final groups = <Widget>[];
    if (_byPerson) {
      final byMember = <String?, List<(String, ShoppingItemPayload)>>{};
      for (final i in needed) {
        final who = names.containsKey(i.$2.forMember) ? i.$2.forMember : null;
        (byMember[who] ??= []).add(i);
      }
      for (final m in [...household.map((m) => m.id), null]) {
        final group = byMember[m];
        if (group == null) continue;
        final sizes = m == null ? const <SizeEntry>[] : cards[m] ?? const [];
        final member = household.where((x) => x.id == m).firstOrNull;
        groups
          ..add(
            header(
              [
                m == null ? l10n.thingsForAnyone : names[m]!,
                for (final s in sizes)
                  if (s.kind != SizeKind.custom)
                    '${sizeKindName(l10n, s)} ${s.value}',
              ].join(' · '),
              icon: m == null ? Icons.groups_outlined : Icons.person_outline,
              onTap: member != null && isParent
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SizesScreen(member: member),
                      ),
                    )
                  : null,
            ),
          )
          ..addAll(group.map(tile));
      }
    } else {
      final byKind = <ThingCategory, List<(String, ShoppingItemPayload)>>{};
      for (final i in needed) {
        (byKind[i.$2.thing ?? ThingCategory.other] ??= []).add(i);
      }
      for (final c in ThingCategory.values) {
        final group = byKind[c];
        if (group == null) continue;
        groups
          ..add(header(thingCategoryName(l10n, c), icon: thingCategoryIcon(c)))
          ..addAll(group.map(tile));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (widget.mayShop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _add,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _addTyped(),
              decoration: InputDecoration(
                hintText: l10n.thingsAddHint,
                prefixIcon: const Icon(Icons.add),
                suffixIcon: IconButton(
                  tooltip: l10n.thingEdit,
                  icon: const Icon(Icons.tune),
                  onPressed: () => _edit(null, null),
                ),
                border: const OutlineInputBorder(),
              ).withDictation(_add, onDone: (_) => _addTyped(spoken: true)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.category_outlined),
                label: Text(l10n.thingsByCategory),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.thingsByPerson),
              ),
            ],
            selected: {_byPerson},
            onSelectionChanged: (s) => setState(() => _byPerson = s.single),
          ),
        ),
        if (needed.isEmpty && bought.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.thingsEmpty,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...groups,
        if (bought.isNotEmpty) ...[
          const Divider(height: 32),
          ListTile(
            title: Text(l10n.shoppingBought(bought.length)),
            leading: Icon(_showBought ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _showBought = !_showBought),
            trailing: TextButton(
              onPressed: () => widget.onClearBought(bought),
              child: Text(l10n.shoppingClearBought),
            ),
          ),
          if (_showBought)
            for (final line in bought) Opacity(opacity: 0.5, child: tile(line)),
        ],
      ],
    );
  }
}

class _ThingTile extends StatelessWidget {
  const _ThingTile({
    required this.id,
    required this.item,
    required this.names,
    required this.showWho,
    required this.showKind,
    required this.onToggle,
    required this.onRemove,
    this.onEdit,
    this.onHold,
  });

  final String id;
  final ShoppingItemPayload item;
  final Map<String, String> names;
  final bool showWho;
  final bool showKind;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;
  final VoidCallback? onHold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bought = item.state == ItemState.bought;
    final ordered = item.state == ItemState.ordered;
    final today = DateTime.now();
    final soon =
        item.neededBy != null &&
        !bought &&
        item.neededBy!
                .difference(DateTime.utc(today.year, today.month, today.day))
                .inDays <=
            3;
    final parts = [
      if (ordered) l10n.thingOrdered,
      if (showWho && names[item.forMember] != null) names[item.forMember]!,
      if (showKind) thingCategoryName(l10n, item.thing ?? ThingCategory.other),
      if (item.size case final size?) l10n.thingSizeShort(size),
      if (item.neededBy case final by?)
        l10n.thingNeededByShort(DateFormat('d MMM').format(by)),
      if (names[item.buyer] case final buyer?) l10n.thingBuyerShort(buyer),
      if (item.link case final link?) Uri.tryParse(link)?.host ?? link,
      ?item.note,
    ];
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(l10n.removeItem),
      ),
      child: GestureDetector(
        onLongPress: onHold,
        child: CheckboxListTile(
          value: bought,
          onChanged: (_) => onToggle(),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 17,
              decoration: bought ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: parts.isEmpty
              ? null
              : Text(
                  parts.join(' · '),
                  style: soon || ordered
                      ? TextStyle(
                          color: soon
                              ? theme.colorScheme.error
                              : theme.colorScheme.tertiary,
                        )
                      : null,
                ),
          secondary: onEdit == null
              ? null
              : IconButton(
                  tooltip: l10n.thingEdit,
                  icon: Icon(
                    ordered
                        ? Icons.local_shipping_outlined
                        : Icons.edit_outlined,
                  ),
                  onPressed: onEdit,
                ),
        ),
      ),
    );
  }
}

/// What the sheet hands back.
class _ThingEdit {
  const _ThingEdit({
    required this.name,
    required this.category,
    required this.forMember,
    required this.size,
    required this.neededBy,
    required this.link,
    required this.buyer,
    required this.note,
    required this.state,
  }) : remove = false;

  const _ThingEdit.remove()
    : name = '',
      category = ThingCategory.other,
      forMember = null,
      size = null,
      neededBy = null,
      link = null,
      buyer = null,
      note = null,
      state = ItemState.needed,
      remove = true;

  final String name;
  final ThingCategory category;
  final String? forMember;
  final String? size;
  final DateTime? neededBy;
  final String? link;
  final String? buyer;
  final String? note;
  final ItemState state;
  final bool remove;
}

class _ThingSheet extends ConsumerStatefulWidget {
  const _ThingSheet({this.item, this.link});

  /// The thing being changed; null for a new one.
  final ShoppingItemPayload? item;

  /// A link someone pasted, for a new thing.
  final String? link;

  @override
  ConsumerState<_ThingSheet> createState() => _ThingSheetState();
}

class _ThingSheetState extends ConsumerState<_ThingSheet> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _size = TextEditingController(text: widget.item?.size);
  late final _link = TextEditingController(
    text: widget.item?.link ?? widget.link,
  );
  late final _note = TextEditingController(text: widget.item?.note);
  late var _category = widget.item?.thing ?? ThingCategory.other;
  late var _forMember = widget.item?.forMember;
  late var _neededBy = widget.item?.neededBy;
  late var _buyer = widget.item?.buyer;
  late var _state = switch (widget.item?.state) {
    ItemState.bought => ItemState.bought,
    ItemState.ordered => ItemState.ordered,
    _ => ItemState.needed,
  };

  /// The kind follows the name until someone picks one.
  late var _categoryChosen = widget.item != null;

  @override
  void dispose() {
    _name.dispose();
    _size.dispose();
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Fills in the size from the card when there is none yet.
  void _suggestSize() {
    if (_size.text.trim().isNotEmpty || _forMember == null) return;
    final card = ref.read(sizeCardsProvider).value?[_forMember] ?? const [];
    if (sizeFor(_name.text, card) case final s?) _size.text = s.value;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy == null
          ? now
          : DateTime(_neededBy!.year, _neededBy!.month, _neededBy!.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(
        () => _neededBy = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // Dictated words arrive without an onChanged, so the guess is made
    // here too.
    if (!_categoryChosen) _category = guessThingCategory(name);
    _suggestSize();
    Navigator.pop(
      context,
      _ThingEdit(
        name: name,
        category: _category,
        forMember: _forMember,
        size: _size.text,
        neededBy: _neededBy,
        link: _link.text,
        buyer: _buyer,
        note: _note.text,
        state: _state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final household = _household(ref);
    final me = ref.watch(membershipProvider).value?.memberId;
    final known = {for (final m in household) m.id};
    final link = _link.text.trim();
    final linkUri = Uri.tryParse(link);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.thingEdit, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: widget.item == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.thingName)
                  .withDictation(_name),
              onChanged: (v) {
                if (!_categoryChosen) {
                  setState(() => _category = guessThingCategory(v));
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ThingCategory>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.thingCategory),
                    items: [
                      for (final c in ThingCategory.values)
                        DropdownMenuItem(
                          value: c,
                          child: Text(thingCategoryName(l10n, c)),
                        ),
                    ],
                    onChanged: (c) => setState(() {
                      _category = c ?? _category;
                      _categoryChosen = true;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: known.contains(_forMember)
                        ? _forMember
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.thingFor),
                    items: [
                      DropdownMenuItem(child: Text(l10n.thingsForAnyone)),
                      for (final m in household)
                        DropdownMenuItem(
                          value: m.id,
                          child: Text(m.displayName),
                        ),
                    ],
                    onChanged: (m) {
                      setState(() => _forMember = m);
                      _suggestSize();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _size,
                    decoration: InputDecoration(labelText: l10n.thingSize),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.thingNeededBy,
                      suffixIcon: _neededBy == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _neededBy = null),
                            ),
                    ),
                    child: InkWell(
                      onTap: _pickDate,
                      child: Text(
                        _neededBy == null
                            ? l10n.thingNoDate
                            : DateFormat('d MMM y').format(_neededBy!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.thingLink,
                suffixIcon:
                    linkUri != null &&
                        linkUri.scheme.startsWith('http') &&
                        linkUri.host.isNotEmpty
                    ? IconButton(
                        tooltip: l10n.thingOpenLink,
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => launchUrl(
                          linkUri,
                          mode: LaunchMode.externalApplication,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_buyer),
                    initialValue: known.contains(_buyer) ? _buyer : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.thingBuyer),
                    items: [
                      DropdownMenuItem(child: Text(l10n.thingNobodyYet)),
                      for (final m in household)
                        DropdownMenuItem(
                          value: m.id,
                          child: Text(m.displayName),
                        ),
                    ],
                    onChanged: (m) => setState(() => _buyer = m),
                  ),
                ),
                if (me != null && _buyer != me) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _buyer = me),
                    child: Text(l10n.thingIllGetIt),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ItemState>(
              segments: [
                ButtonSegment(
                  value: ItemState.needed,
                  label: Text(l10n.thingNeeded),
                ),
                ButtonSegment(
                  value: ItemState.ordered,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text(l10n.thingOrdered),
                ),
                ButtonSegment(
                  value: ItemState.bought,
                  label: Text(l10n.thingBought),
                ),
              ],
              selected: {_state},
              onSelectionChanged: (s) => setState(() => _state = s.single),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.shoppingNote)
                  .withDictation(_note),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.item != null)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, const _ThingEdit.remove()),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.removeItem),
                  ),
                const Spacer(),
                const CancelButton(),
                FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
