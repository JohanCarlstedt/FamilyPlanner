import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../common/cancel_editing.dart';
import '../../common/l10n.dart';
import '../../data/store_providers.dart';

/// Every current member's size card, by member id: for the things list
/// to fill in the size of what is bought for them.
final sizeCardsProvider = StreamProvider<Map<String, List<SizeEntry>>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchProfiles().map(
    (profiles) => {
      for (final (id, p) in profiles)
        if (p.endedAt == null && p.sizes.isNotEmpty) id: p.sizes,
    },
  );
});

String sizeKindName(AppLocalizations l10n, SizeEntry e) => switch (e.kind) {
  SizeKind.shoe => l10n.sizeShoe,
  SizeKind.clothes => l10n.sizeClothes,
  SizeKind.custom => e.label ?? '',
};

/// One member's size card: shoes and clothes always there to fill in,
/// and rows of the family's own (a helmet, shin pads).
class SizesScreen extends ConsumerWidget {
  const SizesScreen({super.key, required this.member});

  final Member member;

  Future<void> _save(WidgetRef ref, List<SizeEntry> sizes) async {
    final store = await ref.read(familyStoreProvider.future);
    final existing = await store.payloadOf(member.id);
    if (existing == null) return;
    await store.saveProfile(
      member.id,
      MemberProfile.read(existing).withSizes([
        for (final s in sizes)
          if (s.value.trim().isNotEmpty) s,
      ]),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  /// Asks for a size; the day it was checked is today.
  Future<SizeEntry?> _ask(
    BuildContext context, {
    required SizeKind kind,
    SizeEntry? current,
  }) => showDialog<SizeEntry>(
    context: context,
    builder: (_) => _SizeDialog(kind: kind, current: current),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sizes =
        ref.watch(sizeCardsProvider).value?[member.id] ?? const <SizeEntry>[];
    final day = DateFormat('d MMM y');
    final now = DateTime.now().toUtc();

    Widget row(SizeEntry? entry, SizeKind kind, String title) => ListTile(
      title: Text(title),
      subtitle: switch (entry?.measuredAt) {
        final at? => Text(
          entry!.isStale(now)
              ? l10n.sizeStale(day.format(at))
              : l10n.sizeChecked(day.format(at)),
          style: entry.isStale(now)
              ? TextStyle(color: theme.colorScheme.error)
              : null,
        ),
        null => null,
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry?.value ?? l10n.sizeNotSet,
            style: entry == null
                ? theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.titleMedium,
          ),
          if (kind == SizeKind.custom && entry != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _save(ref, [
                for (final s in sizes)
                  if (!identical(s, entry)) s,
              ]),
            ),
        ],
      ),
      onTap: () async {
        final changed = await _ask(context, kind: kind, current: entry);
        if (changed == null) return;
        await _save(ref, [
          for (final s in sizes)
            if (!identical(s, entry)) s,
          changed,
        ]);
      },
    );

    final shoe = sizes.where((s) => s.kind == SizeKind.shoe).firstOrNull;
    final clothes = sizes.where((s) => s.kind == SizeKind.clothes).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('${member.displayName} · ${l10n.sizesTitle}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await _ask(context, kind: SizeKind.custom);
          if (added != null) await _save(ref, [...sizes, added]);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.sizesAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          row(shoe, SizeKind.shoe, l10n.sizeShoe),
          row(clothes, SizeKind.clothes, l10n.sizeClothes),
          for (final s in sizes)
            if (s.kind == SizeKind.custom)
              row(s, SizeKind.custom, s.label ?? ''),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.sizesNote(member.displayName),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeDialog extends StatefulWidget {
  const _SizeDialog({required this.kind, this.current});

  final SizeKind kind;
  final SizeEntry? current;

  @override
  State<_SizeDialog> createState() => _SizeDialogState();
}

class _SizeDialogState extends State<_SizeDialog> {
  late final _label = TextEditingController(text: widget.current?.label);
  late final _value = TextEditingController(text: widget.current?.value);

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  void _done() {
    final value = _value.text.trim();
    final label = _label.text.trim();
    if (value.isEmpty) return;
    if (widget.kind == SizeKind.custom && label.isEmpty) return;
    final today = DateTime.now();
    Navigator.pop(
      context,
      SizeEntry(
        kind: widget.kind,
        label: widget.kind == SizeKind.custom ? label : null,
        value: value,
        measuredAt: DateTime.utc(today.year, today.month, today.day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = widget.kind == SizeKind.custom;
    return AlertDialog(
      title: Text(switch (widget.kind) {
        SizeKind.shoe => l10n.sizeShoe,
        SizeKind.clothes => l10n.sizeClothes,
        SizeKind.custom => widget.current?.label ?? l10n.sizesAdd,
      }),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (custom)
            TextField(
              controller: _label,
              autofocus: widget.current == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.sizeLabel,
                hintText: l10n.sizeLabelHint,
              ),
            ),
          TextField(
            controller: _value,
            autofocus: !custom || widget.current != null,
            decoration: InputDecoration(
              labelText: l10n.sizeValue,
              hintText: l10n.sizeValueHint,
            ),
            onSubmitted: (_) => _done(),
          ),
        ],
      ),
      actions: [
        const CancelButton(),
        FilledButton(onPressed: _done, child: Text(l10n.save)),
      ],
    );
  }
}
