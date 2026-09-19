import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import 'wishlist_screen.dart';

final peopleProvider = StreamProvider<List<(String, PersonPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchPeople();
});

String celebrationTypeName(AppLocalizations l10n, CelebrationType t) =>
    switch (t) {
      CelebrationType.birthday => l10n.typeBirthday,
      CelebrationType.nameday => l10n.typeNameday,
      CelebrationType.anniversary => l10n.typeAnniversary,
      CelebrationType.other => l10n.typeOther,
    };

/// The next time [date]'s day comes round from [today] (both `DateTime.utc`
/// date fields); 29 February is the 28th in a common year.
DateTime nextCelebration(DateTime date, DateTime today) {
  DateTime on(int year) {
    final lastDay = DateTime.utc(year, date.month + 1, 0).day;
    return DateTime.utc(year, date.month, date.day.clamp(1, lastDay));
  }

  final thisYear = on(today.year);
  return thisYear.isBefore(today) ? on(today.year + 1) : thisYear;
}

/// Spec §10 "Celebrations": upcoming days with how far off they are, what
/// someone turns, and their gift notes.
class CelebrationsScreen extends ConsumerWidget {
  const CelebrationsScreen({super.key});

  static const segment = 'celebrations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    final today = DateTime.utc(now.year, now.month, now.day);
    final people = [
      for (final p
          in ref.watch(peopleProvider).value ??
              const <(String, PersonPayload)>[])
        if (p.$2.date != null) (p.$1, p.$2, nextCelebration(p.$2.date!, today)),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
    final undated = [
      for (final p
          in ref.watch(peopleProvider).value ??
              const <(String, PersonPayload)>[])
        if (p.$2.date == null) p,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.celebrations)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editPerson(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.addPerson),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (people.isEmpty && undated.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.noCelebrations,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (id, p, next) in people)
            ListTile(
              leading: CircleAvatar(
                child: Text(p.type == CelebrationType.birthday ? '🎂' : '🎉'),
              ),
              title: Text(switch (Celebrations.ageOn(p.date!, next)) {
                final age? when p.type == CelebrationType.birthday =>
                  l10n.celebrationTurns(p.label ?? p.name, age),
                _ => p.label ?? p.name,
              }),
              subtitle: Text(
                [
                  if (p.label != null && p.label != p.name) p.name,
                  if (p.type != CelebrationType.birthday)
                    celebrationTypeName(l10n, p.type),
                  DateFormat('d MMMM').format(next),
                  l10n.inDays(next.difference(today).inDays),
                  ?p.notes,
                ].join(' · '),
              ),
              onTap: () => editPerson(context, ref, id: id, person: p),
              trailing: IconButton(
                tooltip: l10n.wishlist,
                icon: const Icon(Icons.card_giftcard),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WishlistScreen(personId: id),
                  ),
                ),
              ),
            ),
          for (final (id, p) in undated)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(p.label ?? p.name),
              onTap: () => editPerson(context, ref, id: id, person: p),
            ),
        ],
      ),
    );
  }
}

Future<void> editPerson(
  BuildContext context,
  WidgetRef ref, {
  String? id,
  PersonPayload? person,
  Member? member,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _PersonDialog(ref: ref, id: id, person: person, member: member),
);

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({required this.ref, this.id, this.person, this.member});

  final WidgetRef ref;
  final String? id;
  final PersonPayload? person;

  /// Making the person for a member: named after them and linked.
  final Member? member;

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  late final _name = TextEditingController(
    text: widget.person?.name ?? widget.member?.displayName,
  );
  late final _label = TextEditingController(text: widget.person?.label);
  late final _notes = TextEditingController(text: widget.person?.notes);
  late DateTime? _date = widget.person?.date;
  late bool _yearUnknown =
      (widget.person?.date?.year ?? 2000) <= Celebrations.unknownYear;
  late var _type = widget.person?.type ?? CelebrationType.birthday;
  late final _lead = <int>{
    ...(widget.person?.leadDays ?? const [14, 3, 0]),
  };

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date == null
          ? DateTime(now.year - 30, now.month, now.day)
          : DateTime(
              _date!.year <= Celebrations.unknownYear ? 2000 : _date!.year,
              _date!.month,
              _date!.day,
            ),
      firstDate: DateTime(1901),
      lastDate: now,
    );
    if (picked != null) {
      setState(
        () => _date = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = _date;
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.person == null && widget.member == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.personName),
            ),
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.personLabel,
                hintText: l10n.personLabelHint,
              ),
            ),
            DropdownButtonFormField<CelebrationType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.personType),
              items: [
                for (final t in CelebrationType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(celebrationTypeName(l10n, t)),
                  ),
              ],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(
                date == null
                    ? l10n.personDay
                    : _yearUnknown
                    ? DateFormat('d MMMM').format(date)
                    : DateFormat('d MMMM y').format(date),
              ),
              onTap: _pickDate,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _yearUnknown,
              onChanged: (v) => setState(() => _yearUnknown = v ?? false),
              title: Text(l10n.personYearUnknown),
            ),
            Text(
              l10n.personLead,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final d in const [14, 7, 3, 1, 0])
                  FilterChip(
                    label: Text(l10n.personLeadDays(d)),
                    selected: _lead.contains(d),
                    onSelected: (on) =>
                        setState(() => on ? _lead.add(d) : _lead.remove(d)),
                  ),
              ],
            ),
            TextField(
              controller: _notes,
              maxLines: null,
              decoration: InputDecoration(labelText: l10n.personNotes),
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
              await store.deletePerson(id);
              widget.ref.read(syncControllerProvider.notifier).syncNow();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.removePerson),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final ref = widget.ref;
            final store = await ref.read(familyStoreProvider.future);
            await store.savePerson(
              PersonPayload.write(
                existing: widget.person?.payload,
                name: name,
                memberId: widget.person?.memberId ?? widget.member?.id,
                label: _label.text.trim().isEmpty ? null : _label.text.trim(),
                date: date == null
                    ? null
                    : DateTime.utc(
                        _yearUnknown ? Celebrations.unknownYear : date.year,
                        date.month,
                        date.day,
                      ),
                type: _type,
                leadDays: (_lead.toList()..sort((a, b) => b - a)),
                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              ),
              id: widget.id,
              timeZone: familyTimeZone,
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
