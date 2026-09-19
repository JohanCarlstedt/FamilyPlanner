import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/permissions_provider.dart';

/// Spec §3 "Custody across two households": each shared child's schedule,
/// the other home's parent, and swaps for holidays.
class CustodyScreen extends ConsumerWidget {
  const CustodyScreen({super.key});

  static const segment = 'custody';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final names = {for (final m in members) m.id: m.displayName};
    final all =
        ref.watch(custodyPayloadsProvider).value ??
        const <(String, CustodyPayload)>[];
    final mayEdit = ref.watch(permissionsProvider).manageFamily;
    final format = DateFormat('EEEE d MMM HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.custody)),
      floatingActionButton: mayEdit
          ? FloatingActionButton.extended(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _CustodyDialog(ref: ref),
              ),
              icon: const Icon(Icons.add_home_outlined),
              label: Text(l10n.custodyAdd),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.custodyNone),
            ),
          for (final (id, c) in all)
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: Text(l10n.custodyFor(names[c.childId] ?? '—')),
              subtitle: Text(
                [
                  c.pattern == CustodyPattern.alternatingWeeks
                      ? l10n.custodyWeeks
                      : l10n.custodyWeekends,
                  if (c.reference case final r?) format.format(r),
                  names[c.coParentId] ?? l10n.custodyNoCoParent,
                ].join(' · '),
              ),
              onTap: mayEdit
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _CustodyDialog(ref: ref, id: id, existing: c),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _CustodyDialog extends StatefulWidget {
  const _CustodyDialog({required this.ref, this.id, this.existing});

  final WidgetRef ref;
  final String? id;
  final CustodyPayload? existing;

  @override
  State<_CustodyDialog> createState() => _CustodyDialogState();
}

class _CustodyDialogState extends State<_CustodyDialog> {
  late String? _child = widget.existing?.childId;
  late String? _coParent = widget.existing?.coParentId;
  late var _pattern =
      widget.existing?.pattern ?? CustodyPattern.alternatingWeeks;
  late DateTime? _reference = widget.existing?.reference;
  late final _swaps = <CustodySwap>[...?widget.existing?.swaps];

  Future<void> _pickReference() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _reference ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (time == null) return;
    setState(
      () => _reference = DateTime.utc(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _addSwap() async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (range == null || !mounted) return;
    final here = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.custodySwapHere),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.custodySwapThere),
          ),
        ],
      ),
    );
    if (here == null) return;
    setState(
      () => _swaps.add(
        CustodySwap(
          from: DateTime.utc(
            range.start.year,
            range.start.month,
            range.start.day,
          ),
          until: DateTime.utc(
            range.end.year,
            range.end.month,
            range.end.day + 1,
          ),
          here: here,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = widget.ref.watch(membersProvider).value ?? const <Member>[];
    final children = [
      for (final m in members)
        if (m.isChild) m,
    ];
    final helpers = [
      for (final m in members)
        if (m.role == MemberRole.helper) m,
    ];
    final childName =
        members.where((m) => m.id == _child).firstOrNull?.displayName ?? '';
    final reference = _reference;
    final days = DateFormat('d MMM');
    return AlertDialog(
      title: Text(l10n.custody),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _child,
              decoration: InputDecoration(labelText: l10n.hwWho),
              items: [
                for (final c in children)
                  DropdownMenuItem(value: c.id, child: Text(c.displayName)),
              ],
              onChanged: widget.existing == null
                  ? (c) => setState(() => _child = c)
                  : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<CustodyPattern>(
              segments: [
                ButtonSegment(
                  value: CustodyPattern.alternatingWeeks,
                  label: Text(l10n.custodyWeeks),
                ),
                ButtonSegment(
                  value: CustodyPattern.alternatingWeekends,
                  label: Text(l10n.custodyWeekends),
                ),
              ],
              selected: {_pattern},
              onSelectionChanged: (v) => setState(() => _pattern = v.single),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz),
              title: Text(
                reference == null
                    ? l10n.custodyChangeover
                    : DateFormat('EEEE d MMM HH:mm').format(reference),
              ),
              subtitle: Text(
                _pattern == CustodyPattern.alternatingWeeks
                    ? l10n.custodyChangeoverWeeksHint(childName)
                    : l10n.custodyChangeoverWeekendsHint(childName),
              ),
              onTap: _pickReference,
            ),
            DropdownButtonFormField<String?>(
              initialValue: _coParent,
              decoration: InputDecoration(labelText: l10n.custodyCoParent),
              items: [
                DropdownMenuItem(child: Text(l10n.custodyNoCoParent)),
                for (final h in helpers)
                  DropdownMenuItem(value: h.id, child: Text(h.displayName)),
              ],
              onChanged: (h) => setState(() => _coParent = h),
            ),
            const SizedBox(height: 8),
            for (final (i, s) in _swaps.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${days.format(s.from)} – '
                  '${days.format(s.until.subtract(const Duration(days: 1)))}',
                ),
                subtitle: Text(
                  s.here ? l10n.custodySwapHere : l10n.custodySwapThere,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _swaps.removeAt(i)),
                ),
              ),
            TextButton.icon(
              onPressed: _addSwap,
              icon: const Icon(Icons.event_repeat),
              label: Text(l10n.custodySwap),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.id case final id?)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final store = await widget.ref.read(familyStoreProvider.future);
              await store.deleteCustody(id);
              widget.ref.read(syncControllerProvider.notifier).syncNow();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.removeCustody),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            final child = _child;
            final ref = _reference;
            if (child == null || ref == null) return;
            final store = await widget.ref.read(familyStoreProvider.future);
            final other =
                members
                    .where((m) => m.id == _coParent)
                    .firstOrNull
                    ?.displayName ??
                l10n.custodyOtherHome;
            await store.saveCustody(
              CustodyPayload.write(
                existing: widget.existing?.payload,
                childId: child,
                coParentId: _coParent,
                pattern: _pattern,
                reference: ref,
                swaps: _swaps,
              ),
              id: widget.id,
              timeZone: familyTimeZone,
              toUs: l10n.custodyToUs(childName),
              toThem: l10n.custodyToThem(childName, other),
            );
            widget.ref.read(syncControllerProvider.notifier).syncNow();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
