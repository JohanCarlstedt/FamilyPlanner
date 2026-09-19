import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../membership/permissions_provider.dart';
import '../events/occurrence_editing.dart';
import '../more/more_screen.dart';
import 'actions_providers.dart';
import 'recurring_screen.dart';

/// Spec §10 "Actions": the family pool, each member's list, the delegation
/// inbox and the approval queue.
class ActionsScreen extends ConsumerStatefulWidget {
  const ActionsScreen({super.key});

  static const segment = 'todos';

  @override
  ConsumerState<ActionsScreen> createState() => _ActionsScreenState();
}

enum _View { mine, family, inbox }

class _ActionsScreenState extends ConsumerState<ActionsScreen> {
  var _view = _View.mine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value?.memberId;
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final all =
        [
          for (final a
              in ref.watch(actionsProvider).value ??
                  const <(String, ActionPayload)>[])
            if (a.$2.state != ActionState.cancelled &&
                a.$2.state != ActionState.skipped)
              a,
        ]..sort((a, b) {
          final da = a.$2.dueAt, db = b.$2.dueAt;
          if (da == null && db == null) return a.$2.title.compareTo(b.$2.title);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    final inbox = [
      for (final a in all)
        if ((a.$2.delegation?.to == me && a.$2.isOpen) ||
            (isParent && a.$2.awaitingApproval))
          a,
    ];
    final shown = switch (_view) {
      _View.mine => [
        for (final a in all)
          if (a.$2.assignedTo == me && a.$2.isOpen) a,
      ],
      _View.family => [
        for (final a in all)
          if (a.$2.isOpen && a.$2.assignedTo != me) a,
      ],
      _View.inbox => inbox,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todos),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(
              '${MoreScreen.path}/${ActionsScreen.segment}/'
              '${RecurringScreen.segment}',
            ),
            icon: const Icon(Icons.repeat),
            label: Text(l10n.recurring),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SegmentedButton<_View>(
              segments: [
                ButtonSegment(value: _View.mine, label: Text(l10n.todoMine)),
                ButtonSegment(
                  value: _View.family,
                  label: Text(l10n.todoFamily),
                ),
                ButtonSegment(
                  value: _View.inbox,
                  label: Badge(
                    isLabelVisible: inbox.isNotEmpty,
                    label: Text('${inbox.length}'),
                    child: Text(l10n.todoInbox),
                  ),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (v) => setState(() => _view = v.single),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _NewActionDialog(ref: ref),
        ),
        icon: const Icon(Icons.add_task),
        label: Text(l10n.newTodo),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                switch (_view) {
                  _View.mine => l10n.todoEmptyMine,
                  _View.family => l10n.todoEmptyFamily,
                  _View.inbox => l10n.todoEmptyInbox,
                },
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (id, a) in shown)
            ActionTile(id: id, action: a, names: names, me: me),
        ],
      ),
    );
  }
}

/// One action in a list; tap for what can be done with it.
class ActionTile extends ConsumerWidget {
  const ActionTile({
    super.key,
    required this.id,
    required this.action,
    required this.names,
    required this.me,
  });

  final String id;
  final ActionPayload action;
  final Map<String, String> names;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final due = action.dueAt;
    final overdue =
        due != null && action.isOpen && due.isBefore(DateTime.now().toUtc());
    final subtitle = [
      if (action.delegation case final d? when d.to == me)
        l10n.todoAskedBy(names[d.from] ?? '—')
      else if (action.awaitingApproval)
        l10n.todoAwaiting(names[action.completedBy] ?? '—')
      else if (action.assignedTo case final who? when who != me)
        names[who] ?? '—',
      if (due != null)
        overdue
            ? l10n.todoOverdue
            : l10n.todoDueAt(
                DateFormat('EEE d/M HH:mm')
                    .format(wallClock(due, familyTimeZone)),
              ),
    ].join(' · ');
    return ListTile(
      leading: Icon(
        action.blocking ? Icons.priority_high : Icons.check_circle_outline,
        color: overdue ? theme.colorScheme.error : null,
      ),
      title: Text(action.title),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
            ),
      trailing: action.isOpen && action.assignedTo == null
          ? TextButton(
              onPressed: () async {
                final store = await ref.read(familyStoreProvider.future);
                await store.claimAction(id);
                ref.read(syncControllerProvider.notifier).syncNow();
              },
              child: Text(l10n.todoClaim),
            )
          : null,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ActionSheet(id: id, ref: ref),
      ),
    );
  }
}

/// What can be done with one action, and what already happened to it.
class ActionSheet extends ConsumerWidget {
  const ActionSheet({super.key, required this.id, required this.ref});

  final String id;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final action =
        (ref.watch(actionsProvider).value ?? const <(String, ActionPayload)>[])
            .where((a) => a.$1 == id)
            .firstOrNull
            ?.$2;
    if (action == null) return const SizedBox(height: 120);
    final me = ref.watch(membershipProvider).value?.memberId;
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final names = {for (final m in members) m.id: m.displayName};

    Future<void> run(Future<void> Function(FamilyStore) f) async {
      final store = await ref.read(familyStoreProvider.future);
      await f(store);
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    Future<String?> note() => showDialog<String>(
      context: context,
      builder: (context) {
        final text = TextEditingController();
        return AlertDialog(
          content: TextField(
            controller: text,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.todoNote),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, text.text.trim()),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    Future<Member?> pickMember() => showDialog<Member>(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          for (final m in members)
            if (m.id != me)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, m),
                child: Text(m.displayName),
              ),
        ],
      ),
    );

    String step(ActionStep s) {
      final who = names[s.by] ?? '—';
      final to = names[s.to] ?? '—';
      final what = switch (s.what) {
        'claimed' => l10n.histClaimed,
        'unclaimed' => l10n.histUnclaimed,
        'assigned' => l10n.histAssigned(to),
        'delegated' => l10n.histDelegated(to),
        'accepted' => l10n.histAccepted,
        'declined' => l10n.histDeclined(to),
        'done' => l10n.histDone,
        'approved' => l10n.histApproved,
        'reopened' => l10n.histReopened,
        'skipped' => l10n.histSkipped,
        'moved' => l10n.histMoved,
        'cancelled' => l10n.histCancelled,
        _ => l10n.histCreated,
      };
      final when = DateFormat('d/M HH:mm')
          .format(wallClock(s.at, familyTimeZone));
      final line = s.what == 'moved' || s.what == 'cancelled'
          ? what
          : '$who $what';
      return '$when  $line${s.note == null || s.note!.isEmpty ? '' : ' – "${s.note}"'}';
    }

    final delegation = action.delegation;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(action.title, style: theme.textTheme.titleLarge),
            if (action.description case final d?) Text(d),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (delegation != null && delegation.to == me) ...[
                  FilledButton(
                    onPressed: () =>
                        run((s) => s.answerDelegation(id, accept: true)),
                    child: Text(l10n.todoAccept),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final n = await note();
                      await run(
                        (s) => s.answerDelegation(id, accept: false, note: n),
                      );
                    },
                    child: Text(l10n.todoDecline),
                  ),
                ],
                if (action.isOpen)
                  FilledButton.icon(
                    onPressed: () => run((s) => s.completeAction(id)),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.todoDone),
                  ),
                if (action.isOpen && action.assignedTo == null)
                  OutlinedButton(
                    onPressed: () => run((s) => s.claimAction(id)),
                    child: Text(l10n.todoClaim),
                  ),
                if (action.isOpen && action.assignedTo == me)
                  OutlinedButton(
                    onPressed: () => run((s) => s.unclaimAction(id)),
                    child: Text(l10n.todoUnclaim),
                  ),
                if (action.isOpen && delegation == null)
                  OutlinedButton(
                    onPressed: () async {
                      final to = await pickMember();
                      if (to == null) return;
                      final n = await note();
                      await run((s) => s.delegateAction(id, to.id, note: n));
                    },
                    child: Text(l10n.todoAskSomeone),
                  ),
                if (isParent && action.isOpen)
                  OutlinedButton(
                    onPressed: () async {
                      final to = await pickMember();
                      if (to != null) {
                        await run((s) => s.assignAction(id, to.id));
                      }
                    },
                    child: Text(l10n.todoAssign),
                  ),
                if (isParent && action.awaitingApproval)
                  FilledButton(
                    onPressed: () => run((s) => s.approveAction(id)),
                    child: Text(l10n.todoApprove),
                  ),
                if (!action.isOpen)
                  OutlinedButton(
                    onPressed: () => run((s) => s.reopenAction(id)),
                    child: Text(l10n.todoReopen),
                  ),
                if (action.isOpen && action.templateId != null)
                  TextButton(
                    onPressed: () => run((s) => s.skipAction(id)),
                    child: Text(l10n.todoSkip),
                  ),
              ],
            ),
            if (action.history.isNotEmpty) ...[
              const Divider(height: 32),
              Text(l10n.todoHistory, style: theme.textTheme.titleSmall),
              for (final s in action.history.reversed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(step(s), style: theme.textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewActionDialog extends StatefulWidget {
  const _NewActionDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_NewActionDialog> createState() => _NewActionDialogState();
}

class _NewActionDialogState extends State<_NewActionDialog> {
  final _title = TextEditingController();
  DateTime? _due;
  String? _who;
  var _approval = false;

  @override
  void initState() {
    super.initState();
    // Your own to-do unless you choose otherwise.
    _who = widget.ref.read(membershipProvider).value?.memberId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null) return;
    setState(
      () => _due = instantOf(
        DateTime.utc(day.year, day.month, day.day, time.hour, time.minute),
        familyTimeZone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ref = widget.ref;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final isParent = ref.watch(permissionsProvider).manageFamily;
    return AlertDialog(
      title: Text(l10n.newTodo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.todoTitle),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                _due == null
                    ? l10n.todoNoDue
                    : DateFormat('EEEE d/M HH:mm')
                          .format(wallClock(_due!, familyTimeZone)),
              ),
              onTap: _pickDue,
            ),
            DropdownButtonFormField<String?>(
              initialValue: _who,
              decoration: InputDecoration(labelText: l10n.todoWho),
              items: [
                DropdownMenuItem(child: Text(l10n.todoPool)),
                for (final m in members)
                  DropdownMenuItem(value: m.id, child: Text(m.displayName)),
              ],
              onChanged: (m) => setState(() => _who = m),
            ),
            if (isParent)
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
            if (title.isEmpty) return;
            final store = await ref.read(familyStoreProvider.future);
            await store.saveAction(
              ActionPayload.write(
                title: title,
                assignedTo: _who,
                dueAt: _due,
                requiresApproval: _approval,
              ),
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
