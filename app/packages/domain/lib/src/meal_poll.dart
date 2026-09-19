/// One choice in a meal poll, and who put it forward.
class PollOption {
  const PollOption({required this.id, required this.proposer});

  final String id;
  final String proposer;
}

class PollResult {
  const PollResult({
    required this.tally,
    required this.votedBy,
    required this.winner,
  });

  /// Approvals per option.
  final Map<String, int> tally;

  /// Who has voted, which may be shown while the tally isn't.
  final Set<String> votedBy;

  /// Null if nobody voted.
  final String? winner;
}

/// Spec §4 "Use approval voting": each voter ticks every meal they'd be
/// happy with; the most ticks wins. Only [eligible] voters count (the
/// snapshot taken when the poll opened). A tie goes to the option whose
/// proposer has won least recently ([lastWin]; never having won is least
/// recent of all), then to the earlier option: published in advance, and
/// the same on every device.
PollResult tallyPoll({
  required List<PollOption> options,
  required Set<String> eligible,
  required Map<String, Set<String>> votes,
  Map<String, DateTime> lastWin = const {},
}) {
  final tally = {for (final o in options) o.id: 0};
  final votedBy = <String>{};
  for (final MapEntry(key: voter, value: ticks) in votes.entries) {
    if (!eligible.contains(voter)) continue;
    final counted = ticks.where(tally.containsKey).toSet();
    if (counted.isEmpty) continue;
    votedBy.add(voter);
    for (final t in counted) {
      tally[t] = tally[t]! + 1;
    }
  }
  String? winner;
  if (votedBy.isNotEmpty) {
    final ranked = [...options.indexed]..sort((a, b) {
        final byVotes = tally[b.$2.id]!.compareTo(tally[a.$2.id]!);
        if (byVotes != 0) return byVotes;
        final wonA = lastWin[a.$2.proposer];
        final wonB = lastWin[b.$2.proposer];
        if (wonA != wonB) {
          if (wonA == null) return -1;
          if (wonB == null) return 1;
          return wonA.compareTo(wonB);
        }
        return a.$1.compareTo(b.$1);
      });
    winner = ranked.first.$2.id;
  }
  return PollResult(tally: tally, votedBy: votedBy, winner: winner);
}
