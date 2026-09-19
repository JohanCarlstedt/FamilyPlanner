import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
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
            TemplateTile(id: id, template: t, names: names, ref: ref),
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
  });

  final String id;
  final ActionTemplatePayload template;
  final Map<String, String> names;
  final WidgetRef ref;
  final String? describeWhen;

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
      child: SwitchListTile(
        value: !template.paused,
        onChanged: (on) async {
          final store = await ref.read(familyStoreProvider.future);
          final p = Payload.decode(template.payload.encode())
            ..setBoolean('paused', !on);
          await store.saveActionTemplate(ActionTemplatePayload.read(p), id: id);
          ref.read(syncControllerProvider.notifier).syncNow();
        },
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

/// A new recurring chore: which days, when, how often, and whose turn.
class ChoreDialog extends StatefulWidget {
  const ChoreDialog({super.key, required this.ref});

  final WidgetRef ref;

  @override
  State<ChoreDialog> createState() => _ChoreDialogState();
}

class _ChoreDialogState extends State<ChoreDialog> {
  final _title = TextEditingController();
  final _days = <Weekday>{Weekday.values[DateTime.now().weekday - 1]};
  var _time = const TimeOfDay(hour: 18, minute: 0);
  var _interval = 1;
  var _turns = <String>[];
  var _approval = false;

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
      title: Text(l10n.newChore),
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
            if (title.isEmpty || _days.isEmpty) return;
            final now = DateTime.now();
            final store = await ref.read(familyStoreProvider.future);
            await store.saveActionTemplate(
              ActionTemplatePayload.write(
                title: title,
                schedule: EventPayload.write(
                  title: title,
                  kind: EventKind.actionBlock,
                  localStart: DateTime.utc(
                    now.year,
                    now.month,
                    now.day,
                    _time.hour,
                    _time.minute,
                  ),
                  duration: Duration.zero,
                  timeZone: familyTimeZone,
                  rule: RecurrenceRule(
                    frequency: Frequency.weekly,
                    interval: _interval,
                    byWeekday: {..._days},
                  ),
                ),
                assignee: _turns.length == 1 ? _turns.single : null,
                rotateAmong: _turns.length > 1 ? _turns : const [],
                requiresApproval: _approval,
              ),
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
  const _PrepDialog({required this.eventId, required this.ref});

  final String eventId;
  final WidgetRef ref;

  @override
  State<_PrepDialog> createState() => _PrepDialogState();
}

class _PrepDialogState extends State<_PrepDialog> {
  final _title = TextEditingController();
  var _before = 1440;
  var _turns = <String>[];
  var _blocking = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addPrep),
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
                title: title,
                kind: ActionKind.prep,
                offsetMinutes: -_before,
                eventId: widget.eventId,
                assignee: _turns.length == 1 ? _turns.single : null,
                rotateAmong: _turns.length > 1 ? _turns : const [],
                blocking: _blocking,
              ),
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
