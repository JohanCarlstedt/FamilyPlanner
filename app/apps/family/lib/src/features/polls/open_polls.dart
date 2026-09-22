import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/l10n.dart';
import '../../membership/membership.dart';
import '../more/more_screen.dart';
import '../shopping/ideas_screen.dart' show pollsProvider, votesProvider;
import 'polls_screen.dart';

/// The polls still waiting on *this* member.
///
/// Not "open polls": one already answered is not a question any more, and
/// counting it would make the badge a number nobody can ever get down to
/// zero — which is how a badge stops being read at all.
///
/// Eligibility matters too. A poll fixes who may vote when it opens, so a
/// child added to the family on Tuesday is not being asked about Monday's
/// question, and should not be told they are.
List<(String, MealPollPayload)> pollsAwaiting({
  required List<(String, MealPollPayload)> polls,
  required List<(String, MealVotePayload)> votes,
  required String? me,
  required DateTime now,
}) {
  if (me == null) return const [];
  final answered = {
    for (final (_, v) in votes)
      if (v.memberId == me) v.pollId,
  };
  return [
    for (final (id, p) in polls)
      if (p.state == PollState.open &&
          !answered.contains(id) &&
          (p.eligible.isEmpty || p.eligible.contains(me)) &&
          // Past its time and not yet closed by anyone's device: the
          // answer is no longer wanted, and asking for it looks broken.
          !(p.closesAt?.isBefore(now) ?? false))
        (id, p),
  ]..sort(
    (a, b) => (a.$2.closesAt ?? DateTime.utc(9999)).compareTo(
      b.$2.closesAt ?? DateTime.utc(9999),
    ),
  );
}

/// How many questions are waiting on this device's member.
final awaitingAnswerProvider = Provider<List<(String, MealPollPayload)>>((ref) {
  return pollsAwaiting(
    polls: ref.watch(pollsProvider).value ?? const [],
    votes: ref.watch(votesProvider).value ?? const [],
    me: ref.watch(membershipProvider).value?.memberId,
    now: DateTime.now().toUtc(),
  );
});

/// What the family is still waiting for an answer to, on the dashboard.
///
/// A question with a closing time is the one thing here that expires: miss
/// it and the family decided without you, which is worse than a to-do left
/// undone. It belongs where the day is read, not three taps into More.
class AwaitingAnswerCard extends ConsumerWidget {
  const AwaitingAnswerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(awaitingAnswerProvider);
    if (waiting.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: ListTile(
          leading: Badge.count(
            count: waiting.length,
            child: const Icon(Icons.how_to_vote_outlined),
          ),
          title: Text(l10n.pollsAwaiting(waiting.length)),
          subtitle: Text(
            [for (final (_, p) in waiting.take(3)) p.title].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.go('${MoreScreen.path}/${PollsScreen.segment}'),
        ),
      ),
    );
  }
}
