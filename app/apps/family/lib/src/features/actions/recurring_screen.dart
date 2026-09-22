import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../common/repeat_span.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../events/occurrence_editing.dart';
import 'actions_providers.dart';

/// Chores on a schedule (spec §3 `action_template` without an event): the
/// bins every other Tuesday, whoever's turn it is.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  static const segment = 'recurring';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final chores = [
      for (final t
          in ref.watch(actionTemplatesProvider).value ??
              const <(String, ActionTemplatePayload)>[])
        if (t.$2.eventId == null) t,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurring)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => ChoreDialog(ref: ref),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.newChore),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.recurringSubtitle),
          ),
          for (final (id, t) in chores)
            TemplateTile(
              id: id,
              template: t,
              names: names,
              ref: ref,
              onEdit: () => showDialog<void>(
                context: context,
                builder: (_) => ChoreDialog(ref: ref, id: id, existing: t),
              ),
            ),
        ],
      ),
    );
  }
}

/// A template in a list: who's on it, and a switch to pause it.
class TemplateTile extends StatelessWidget {
  const TemplateTile({
    super.key,
    required this.id,
    required this.template,
    required this.names,
    required this.ref,
    this.describeWhen,
    this.onEdit,
  });

  final String id;
  final ActionTemplatePayload template;
  final Map<String, String> names;
  final WidgetRef ref;
  final String? describeWhen;

  /// Opens this one to be changed. Supplied by whoever placed the tile,
  /// because a chore and a prep are not edited in the same dialog — one
  /// asks which weekdays, the other how long before an event.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final who = template.rotateAmong.isNotEmpty
        ? template.rotateAmong.map((m) => names[m] ?? '—').join(' ⇄ ')
        : names[template.assignee] ?? l10n.todoPool;
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        final store = await ref.read(familyStoreProvider.future);
        await store.delete(ObjectKind.actionTemplate, id);
        ref.read(syncControllerProvider.notifier).syncNow();
      },
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(l10n.removeItem),
      ),
      // A row rather than a SwitchListTile, so the switch and the row can
      // do different things: the switch pauses, the rest opens the chore to
      // be changed. Both are wanted often — "not this week", and "actually,
      // Tuesdays".
      child: ListTile(
        onTap: onEdit,
        trailing: Switch(
          value: !template.paused,
          onChanged: (on) async {
            final store = await ref.read(familyStoreProvider.future);
            final p = Payload.decode(template.payload.encode())
              ..setBoolean('paused', !on);
            await store.saveActionTemplate(
              ActionTemplatePayload.read(p),
              id: id,
            );
            ref.read(syncControllerProvider.notifier).syncNow();
          },
        ),
        title: Text(template.title),
        subtitle: Text(
          [
            ?describeWhen,
            who,
            if (template.paused) l10n.chorePaused,
          ].join(' · '),
        ),
      ),
    );
  }
}

/// Who takes turns: one chosen always does it, several rotate, none leaves
/// it to the family pool.
class TurnsPicker extends ConsumerWidget {
  const TurnsPicker({super.key, required this.chosen, required this.onChanged});

  final List<String> chosen;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.choreTurns, style: Theme.of(context).textTheme.labelLarge),
        Text(l10n.choreTurnsHint, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 8,
          children: [
            for (final m in members)
              FilterChip(
                label: Text(m.displayName),
                selected: chosen.contains(m.id),
                onSelected: (on) => onChanged(
                  on
                      ? [...chosen, m.id]
                      : [
                          for (final x in chosen)
                            if (x != m.id) x,
                        ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A recurring chore — which days, when, how often, whose turn — being
/// made, or an existing one opened to be changed.
///
/// Editing arrived late: a chore could be swiped away or paused and not
/// otherwise touched, so changing the day or who does it meant deleting it
/// and building it again — losing the turn order along with it.
class ChoreDialog extends StatefulWidget {
  const ChoreDialog({super.key, required this.ref, this.id, this.existing});

  final WidgetRef ref;

  /// The template being changed, or null for a new one. Saving with the
  /// same id rewrites it in place, so already-planned chores keep the ids
  /// they were planned under and nothing is duplicated.
  final String? id;
  final ActionTemplatePayload? existing;

  @override
  State<ChoreDialog> createState() => _ChoreDialogState();
}

class _ChoreDialogState extends State<ChoreDialog> {
  final _title = TextEditingController();
  late final Set<Weekday> _days;
  late TimeOfDay _time;
  late int _interval;
  late RepeatSpan _span;
  late List<String> _turns;
  late bool _approval;

  @override
  void initState() {
    super.initState();
    final was = widget.existing;
    final series = was?.schedule;
    final rule = series?.rule;
    _title.text = was?.title ?? '';
    _days = {
      ...?rule?.byWeekday,
      if (rule?.byWeekday == null || rule!.byWeekday.isEmpty)
        Weekday.values[DateTime.now().weekday - 1],
    };
    final start = series?.localStart;
    _time = start == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay(hour: start.hour, minute: start.minute);
    _interval = rule?.interval ?? 1;
    // Seeded from the schedule rather than from today, so editing a rota
    // in November does not quietly move its start to November.
    final today = DateTime.now();
    _span = RepeatSpan(
      startsOn: start == null
          ? DateTime.utc(today.year, today.month, today.day)
          : DateTime.utc(start.year, start.month, start.day),
      until: rule?.until,
    );
    _turns = [
      ...was?.rotateAmong ?? const [],
      if ((was?.rotateAmong.isEmpty ?? true) && was?.assignee != null)
        was!.assignee!,
    ];
    _approval = was?.requiresApproval ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ref = widget.ref;
    return AlertDialog(
      title: Text(widget.id == null ? l10n.newChore : l10n.editChore),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.todoTitle),
            ),
            const SizedBox(height: 12),
            Text(l10n.choreDays, style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 4,
              children: [
                for (final d in Weekday.values)
                  FilterChip(
                    label: Text(weekdayName(d).substring(0, 2)),
                    selected: _days.contains(d),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.choreTime),
              trailing: Text(_time.format(context)),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (t != null) setState(() => _time = t);
              },
            ),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 1, label: Text(l10n.choreWeekly)),
                ButtonSegment(value: 2, label: Text(l10n.choreBiweekly)),
              ],
              selected: {_interval},
              onSelectionChanged: (v) => setState(() => _interval = v.single),
            ),
            const SizedBox(height: 12),
            TurnsPicker(
              chosen: _turns,
              onChanged: (v) => setState(() => _turns = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _approval,
              onChanged: (v) => setState(() => _approval = v),
              title: Text(l10n.todoApproval),
            ),
            RepeatSpanField(
              span: _span,
              onChanged: (v) => setState(() => _span = v),
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
            if (title.isEmpty || _days.isEmpty || !_span.isUsable) return;
            final store = await ref.read(familyStoreProvider.future);
            await store.saveActionTemplate(
              ActionTemplatePayload.write(
                // Kept so that what this dialog does not ask about — a
                // pause, and any field a later version adds — survives an
                // edit rather than being quietly reset to its default.
                existing: widget.existing?.payload,
                title: title,
                schedule: EventPayload.write(
                  title: title,
                  kind: EventKind.actionBlock,
                  localStart: DateTime.utc(
                    _span.startsOn.year,
                    _span.startsOn.month,
                    _span.startsOn.day,
                    _time.hour,
                    _time.minute,
                  ),
                  duration: Duration.zero,
                  timeZone: familyTimeZone,
                  rule: RecurrenceRule(
                    frequency: Frequency.weekly,
                    interval: _interval,
                    byWeekday: {..._days},
                    // Null is "for ever", and is a choice made rather
                    // than a default fallen into.
                    until: _span.until,
                  ),
                ),
                assignee: _turns.length == 1 ? _turns.single : null,
                rotateAmong: _turns.length > 1 ? _turns : const [],
                requiresApproval: _approval,
              ),
              // In place when editing: the chores already planned from this
              // template are keyed to its id, so a new id would leave them
              // orphaned and plan the whole series a second time.
              id: widget.id,
            );
            await store.planActionsAhead(await ref.read(eventsProvider.future));
            ref.read(syncControllerProvider.notifier).syncNow();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Offsets offered for prep, in minutes before the start.
const prepOffsets = [0, 60, 180, 1440, 2880, 10080];

String describeOffset(AppLocalizations l10n, int minutesBefore) =>
    switch (minutesBefore) {
      0 => l10n.prepSameTime,
      < 1440 => l10n.prepHoursBefore(minutesBefore ~/ 60),
      _ => l10n.prepDaysBefore(minutesBefore ~/ 1440),
    };

/// Prep on an event (spec §3: "wash the kit two days before each match"),
/// shown on the event and added from it.
class PrepSection extends ConsumerWidget {
  const PrepSection({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final templates = [
      for (final t
          in ref.watch(actionTemplatesProvider).value ??
              const <(String, ActionTemplatePayload)>[])
        if (t.$2.eventId == eventId) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.prep, style: Theme.of(context).textTheme.titleSmall),
        for (final (id, t) in templates)
          TemplateTile(
            id: id,
            template: t,
            names: names,
            ref: ref,
            describeWhen: describeOffset(l10n, -t.offsetMinutes),
            onEdit: () => showDialog<void>(
              context: context,
              builder: (_) => _PrepDialog(
                eventId: eventId,
                ref: ref,
                id: id,
                existing: t,
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _PrepDialog(eventId: eventId, ref: ref),
          ),
          icon: const Icon(Icons.add),
          label: Text(l10n.addPrep),
        ),
      ],
    );
  }
}

class _PrepDialog extends StatefulWidget {
  const _PrepDialog({
    required this.eventId,
    required this.ref,
    this.id,
    this.existing,
  });

  final String eventId;
  final WidgetRef ref;

  /// The prep being changed, or null for a new one. As with a chore,
  /// saving under the same id keeps what has already been planned from it.
  final String? id;
  final ActionTemplatePayload? existing;

  @override
  State<_PrepDialog> createState() => _PrepDialogState();
}

class _PrepDialogState extends State<_PrepDialog> {
  final _title = TextEditingController();
  late int _before;
  late List<String> _turns;
  late bool _blocking;

  @override
  void initState() {
    super.initState();
    final was = widget.existing;
    _title.text = was?.title ?? '';
    // Offsets are stored as minutes before the start, negated.
    _before = was == null ? 1440 : -was.offsetMinutes;
    _turns = [
      ...was?.rotateAmong ?? const [],
      if ((was?.rotateAmong.isEmpty ?? true) && was?.assignee != null)
        was!.assignee!,
    ];
    _blocking = was?.blocking ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.id == null ? l10n.addPrep : l10n.editChore),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.todoTitle),
            ),
            DropdownButtonFormField<int>(
              initialValue: _before,
              decoration: InputDecoration(labelText: l10n.prepWhen),
              items: [
                for (final m in prepOffsets)
                  DropdownMenuItem(
                    value: m,
                    child: Text(describeOffset(l10n, m)),
                  ),
              ],
              onChanged: (m) => setState(() => _before = m ?? _before),
            ),
            const SizedBox(height: 12),
            TurnsPicker(
              chosen: _turns,
              onChanged: (v) => setState(() => _turns = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _blocking,
              onChanged: (v) => setState(() => _blocking = v),
              title: Text(l10n.todoBlocking),
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
            if (title.isEmpty) return;
            final ref = widget.ref;
            final store = await ref.read(familyStoreProvider.future);
            await store.saveActionTemplate(
              ActionTemplatePayload.write(
                existing: widget.existing?.payload,
                title: title,
                kind: ActionKind.prep,
                offsetMinutes: -_before,
                eventId: widget.eventId,
                assignee: _turns.length == 1 ? _turns.single : null,
                rotateAmong: _turns.length > 1 ? _turns : const [],
                blocking: _blocking,
              ),
              id: widget.id,
            );
            await store.planActionsAhead(await ref.read(eventsProvider.future));
            ref.read(syncControllerProvider.notifier).syncNow();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
