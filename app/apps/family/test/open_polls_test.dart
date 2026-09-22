import 'package:family/src/features/polls/open_polls.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// What still needs an answer from the person holding the phone.
///
/// A badge is only worth reading if the number can reach zero. Count
/// polls this member has already answered, or was never asked, and it
/// never does — and then nobody reads it at all.
void main() {
  final now = DateTime.utc(2026, 9, 22, 12);

  (String, MealPollPayload) poll(
    String id, {
    PollState state = PollState.open,
    DateTime? closesAt,
    List<String> eligible = const [],
    String title = 'Vart åker vi i höstlovet?',
  }) {
    final written = MealPollPayload.write(
      title: title,
      topic: PollTopic.anything,
      options: const [],
      eligible: eligible,
      createdBy: 'anna',
      closesAt: closesAt ?? DateTime.utc(2026, 9, 24),
    );
    if (state != PollState.open) {
      written.payload.setText('state', state.name);
    }
    return (id, written);
  }

  (String, MealVotePayload) vote(String pollId, String member) => (
    'v-$pollId-$member',
    MealVotePayload.write(
      pollId: pollId,
      memberId: member,
      options: const {'a'},
    ),
  );

  List<(String, MealPollPayload)> awaiting(
    List<(String, MealPollPayload)> polls, {
    List<(String, MealVotePayload)> votes = const [],
    String? me = 'erik',
  }) => pollsAwaiting(polls: polls, votes: votes, me: me, now: now);

  test('an open question nobody has answered is waiting', () {
    expect(awaiting([poll('p1')]).map((p) => p.$1), ['p1']);
  });

  test('one I have answered is not a question any more', () {
    expect(awaiting([poll('p1')], votes: [vote('p1', 'erik')]), isEmpty);
  });

  test('somebody else answering does not answer it for me', () {
    expect(
      awaiting([poll('p1')], votes: [vote('p1', 'anna')]).map((p) => p.$1),
      ['p1'],
    );
  });

  test('a closed question is not waiting', () {
    expect(awaiting([poll('p1', state: PollState.closed)]), isEmpty);
    expect(awaiting([poll('p1', state: PollState.cancelled)]), isEmpty);
  });

  test('one whose time has passed is not waiting either', () {
    // Still open only because no device has closed it yet. Asking for an
    // answer nobody wants any more makes the app look broken.
    expect(
      awaiting([poll('p1', closesAt: DateTime.utc(2026, 9, 22, 8))]),
      isEmpty,
    );
    expect(
      awaiting([poll('p1', closesAt: DateTime.utc(2026, 9, 22, 20))])
          .map((p) => p.$1),
      ['p1'],
    );
  });

  test('a question I was never asked is not mine to answer', () {
    // Who may vote is fixed when a poll opens, so somebody who joined
    // afterwards is not being asked about it.
    expect(awaiting([poll('p1', eligible: ['anna', 'maja'])]), isEmpty);
    expect(
      awaiting([poll('p1', eligible: ['anna', 'erik'])]).map((p) => p.$1),
      ['p1'],
    );
  });

  test('soonest to close comes first', () {
    final order = awaiting([
      poll('later', closesAt: DateTime.utc(2026, 9, 25)),
      poll('latest', closesAt: DateTime.utc(2026, 9, 30)),
      poll('soon', closesAt: DateTime.utc(2026, 9, 22, 18)),
    ]).map((p) => p.$1);
    expect(order, ['soon', 'later', 'latest']);
  });

  test('a device with no member is asked nothing', () {
    expect(awaiting([poll('p1')], me: null), isEmpty);
  });
}
