import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../shopping/ideas_screen.dart' show pollsProvider, votesProvider;

/// Asking the family something and counting the answers.
///
/// The machinery was already here for dinners — approval voting, a
/// closing time, a tally that is the same on every device — and knew
/// nothing about meals; only the screens did. This is the same poll with
/// the question and the options written by whoever asks.
///
/// Approval voting, as for meals (spec §4): tick everything you would be
/// happy with rather than picking one. It is harder to game and kinder to
/// the person whose favourite comes second.
class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  static const segment = 'polls';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value?.memberId;
    final all = ref.watch(pollsProvider).value ?? const [];
    final polls = [
      for (final (id, p) in all)
        if (p.topic == PollTopic.anything) (id, p),
    ]..sort((a, b) {
      // Open first, then by when they close — the one that needs an
      // answer soonest is the one worth seeing.
      if ((a.$2.state == PollState.open) != (b.$2.state == PollState.open)) {
        return a.$2.state == PollState.open ? -1 : 1;
      }
      return (a.$2.closesAt ?? DateTime(0)).compareTo(
        b.$2.closesAt ?? DateTime(0),
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.polls)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ask(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.pollAsk),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.pollsHelp, style: theme.textTheme.bodyMedium),
          ),
          if (polls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.pollsEmpty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (id, poll) in polls)
            _PollCard(id: id, poll: poll, me: me),
        ],
      ),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final made = await showDialog<_Asked>(
      context: context,
      builder: (_) => const _AskDialog(),
    );
    if (made == null) return;
    final store = await ref.read(familyStoreProvider.future);
    final me = ref.read(membershipProvider).value?.memberId ?? '';
    final members = await ref.read(membersProvider.future);
    await store.savePoll(
      MealPollPayload.write(
        title: made.question,
        // No date: this is not about a Tuesday's dinner.
        closesAt: made.closesAt,
        topic: PollTopic.anything,
        createdBy: me,
        // Who may vote is fixed when it opens, so someone joining the
        // family halfway through does not change what a majority means.
        eligible: [
          for (final m in members)
            if (m.isActive && m.role != MemberRole.helper) m.id,
        ],
        options: [
          for (final text in made.options)
            MealPollOption(
              id: const Uuid().v4(),
              proposer: me,
              title: text,
            ),
        ],
      ),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({required this.id, required this.poll, required this.me});

  final String id;
  final MealPollPayload poll;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open = poll.state == PollState.open;
    final votes = ref.watch(votesProvider).value ?? const [];
    final mine = {
      for (final (_, v) in votes)
        if (v.pollId == id && v.memberId == me) ...v.options,
    };
    final voters = {
      for (final (_, v) in votes)
        if (v.pollId == id) v.memberId,
    };
    final winner = poll.winner;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              open
                  ? l10n.pollCloses(
                      DateFormat(
                        'EEE d MMM HH:mm',
                      ).format(poll.closesAt!.toLocal()),
                    )
                  : l10n.pollIsClosed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final option in poll.options)
              if (open)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: mine.contains(option.id),
                  title: Text(option.title ?? ''),
                  onChanged: me == null || !poll.eligible.contains(me)
                      ? null
                      : (on) async {
                          final store = await ref.read(
                            familyStoreProvider.future,
                          );
                          // Approval voting: the whole set each time,
                          // with this one in or out of it.
                          final ticks = {...mine};
                          if (on ?? false) {
                            ticks.add(option.id);
                          } else {
                            ticks.remove(option.id);
                          }
                          await store.castVote(id, me!, ticks);
                          ref.read(syncControllerProvider.notifier).syncNow();
                        },
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    option.id == winner
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: option.id == winner
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(option.title ?? ''),
                ),
            if (open)
              Text(
                // Who has answered, never who voted for what: a tally
                // shown early is a tally that changes the vote.
                l10n.pollVotedSoFar(voters.length, poll.eligible.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Asked {
  const _Asked(this.question, this.options, this.closesAt);

  final String question;
  final List<String> options;
  final DateTime closesAt;
}

class _AskDialog extends StatefulWidget {
  const _AskDialog();

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  DateTime _closesAt = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _question.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _pickClosing() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _closesAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_closesAt),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(
      () => _closesAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pollAsk),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _question,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.pollQuestion,
                hintText: l10n.pollQuestionHint,
              ),
            ),
            const SizedBox(height: 12),
            for (final (i, option) in _options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: option,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.pollOptionNumber(i + 1),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _options.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: Text(l10n.pollAddOption),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickClosing,
              icon: const Icon(Icons.schedule),
              label: Text(
                l10n.pollCloses(
                  DateFormat('EEE d MMM HH:mm').format(_closesAt),
                ),
              ),
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
          onPressed: () {
            final question = _question.text.trim();
            final options = [
              for (final o in _options)
                if (o.text.trim().isNotEmpty) o.text.trim(),
            ];
            // Two is the fewest that is a question rather than a statement.
            if (question.isEmpty || options.length < 2) return;
            Navigator.pop(
              context,
              _Asked(question, options, _closesAt.toUtc()),
            );
          },
          child: Text(l10n.pollAskIt),
        ),
      ],
    );
  }
}
