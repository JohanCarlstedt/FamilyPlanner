import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';

final absencePayloadsProvider = StreamProvider<List<(String, AbsencePayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchAbsences();
});

/// "Höstlov · Maja", for a band over the days it covers.
String describeAbsence(
  AppLocalizations l10n,
  Absence a,
  Map<String, String> names,
) => l10n.awayBand(
  a.title,
  a.memberIds.isEmpty
      ? l10n.awayEveryone
      : a.memberIds.map((m) => names[m] ?? '—').join(', '),
);

/// Spec §3 `absence` and the school breaks of §5: holidays, trips and lov
/// that pause what they cover, with nothing deleted.
class AwayScreen extends ConsumerWidget {
  const AwayScreen({super.key});

  static const segment = 'away';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final today = DateTime.now().toUtc();
    final all = [
      for (final a
          in ref.watch(absencePayloadsProvider).value ??
              const <(String, AbsencePayload)>[])
        if (!(a.$2.endsOn?.isBefore(today.subtract(const Duration(days: 1))) ??
            true))
          a,
    ]..sort((a, b) => a.$2.startsOn!.compareTo(b.$2.startsOn!));
    final range = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.away)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'break',
            onPressed: () => _edit(context, ref, schoolBreak: true),
            icon: const Icon(Icons.school_outlined),
            label: Text(l10n.addBreak),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'away',
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.luggage_outlined),
            label: Text(l10n.addAway),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 160),
        children: [
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.awayEmpty),
            ),
          for (final (id, a) in all)
            ListTile(
              leading: Icon(
                a.schoolBreak ? Icons.school_outlined : Icons.luggage_outlined,
              ),
              title: Text(describeAbsence(l10n, a.toDomain(id)!, names)),
              subtitle: Text(
                l10n.awayRange(
                  range.format(a.startsOn!),
                  range.format(a.endsOn!),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final store = await ref.read(familyStoreProvider.future);
                  await store.delete(ObjectKind.absence, id);
                  ref.read(syncControllerProvider.notifier).syncNow();
                },
              ),
              onTap: () => _edit(context, ref, id: id, existing: a),
            ),
        ],
      ),
    );
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    String? id,
    AbsencePayload? existing,
    bool schoolBreak = false,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _AwayDialog(
      ref: ref,
      id: id,
      existing: existing,
      schoolBreak: existing?.schoolBreak ?? schoolBreak,
    ),
  );
}

class _AwayDialog extends StatefulWidget {
  const _AwayDialog({
    required this.ref,
    required this.schoolBreak,
    this.id,
    this.existing,
  });

  final WidgetRef ref;
  final bool schoolBreak;
  final String? id;
  final AbsencePayload? existing;

  @override
  State<_AwayDialog> createState() => _AwayDialogState();
}

class _AwayDialogState extends State<_AwayDialog> {
  late final _title = TextEditingController(text: widget.existing?.title);
  DateTimeRange? _range;
  late final _who = <String>{...?widget.existing?.memberIds};
  late final _kinds = <EventKind>{
    ...(widget.existing?.suppressKinds ??
        (widget.schoolBreak
            // A break pauses school, not football (spec §5: breaks pause
            // routine blocks).
            ? const {EventKind.routine}
            : const {EventKind.activity, EventKind.routine})),
  };
  late var _silence = widget.existing?.suppressReminders ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.existing case final e?) {
      _range = DateTimeRange(
        start: DateTime(e.startsOn!.year, e.startsOn!.month, e.startsOn!.day),
        end: DateTime(e.endsOn!.year, e.endsOn!.month, e.endsOn!.day),
      );
    } else if (widget.schoolBreak) {
      // Children are the ones on a school break.
      for (final m
          in widget.ref.read(membersProvider).value ?? const <Member>[]) {
        if (m.isChild) _who.add(m.id);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = widget.ref.watch(membersProvider).value ?? const <Member>[];
    final range = _range;
    return AlertDialog(
      title: Text(widget.schoolBreak ? l10n.addBreak : l10n.addAway),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.awayTitle,
                hintText: l10n.awayTitleHint,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: Text(
                range == null
                    ? l10n.awayDates
                    : l10n.awayRange(
                        DateFormat('d MMM').format(range.start),
                        DateFormat('d MMM').format(range.end),
                      ),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 2),
                  initialDateRange: range,
                );
                if (picked != null) setState(() => _range = picked);
              },
            ),
            Text(l10n.awayWho, style: Theme.of(context).textTheme.labelLarge),
            Text(
              l10n.awayWhoHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final m in members)
                  FilterChip(
                    label: Text(m.displayName),
                    selected: _who.contains(m.id),
                    onSelected: (on) =>
                        setState(() => on ? _who.add(m.id) : _who.remove(m.id)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.awayPauses,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final (kind, label) in [
                  (EventKind.activity, l10n.kindActivities),
                  (EventKind.routine, l10n.kindRoutines),
                  (EventKind.homework, l10n.kindHomework),
                  (EventKind.appointment, l10n.kindAppointments),
                ])
                  FilterChip(
                    label: Text(label),
                    selected: _kinds.contains(kind),
                    onSelected: (on) => setState(
                      () => on ? _kinds.add(kind) : _kinds.remove(kind),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _silence,
              onChanged: (v) => setState(() => _silence = v),
              title: Text(l10n.awaySilence),
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
            final title = _title.text.trim();
            if (title.isEmpty || range == null) return;
            final ref = widget.ref;
            final store = await ref.read(familyStoreProvider.future);
            await store.saveAbsence(
              AbsencePayload.write(
                existing: widget.existing?.payload,
                title: title,
                startsOn: DateTime.utc(
                  range.start.year,
                  range.start.month,
                  range.start.day,
                ),
                endsOn: DateTime.utc(
                  range.end.year,
                  range.end.month,
                  range.end.day,
                ),
                memberIds: _who,
                suppressKinds: _kinds,
                suppressReminders: _silence,
                schoolBreak: widget.schoolBreak,
              ),
              id: widget.id,
            );
            ref.read(syncControllerProvider.notifier).syncNow();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
