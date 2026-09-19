import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const tacos = PollOption(id: 'tacos', proposer: 'maja');
  const pasta = PollOption(id: 'pasta', proposer: 'erik');
  const soup = PollOption(id: 'soup', proposer: 'anna');
  const family = {'anna', 'erik', 'maja', 'ella'};

  test('approval: the meal the most people would happily eat wins', () {
    final r = tallyPoll(
      options: [tacos, pasta, soup],
      eligible: family,
      votes: {
        'anna': {'pasta', 'soup'},
        'erik': {'pasta'},
        'maja': {'tacos', 'pasta'},
        'ella': {'tacos'},
      },
    );
    expect(r.tally, {'tacos': 2, 'pasta': 3, 'soup': 1});
    expect(r.winner, 'pasta');
  });

  test('only the voters snapshotted when the poll opened count', () {
    final r = tallyPoll(
      options: [tacos, pasta],
      eligible: {'anna', 'maja'},
      votes: {
        'anna': {'pasta'},
        'maja': {'tacos'},
        'visitor': {'tacos'},
      },
      lastWin: {'erik': DateTime.utc(2026, 9, 1)},
    );
    expect(r.tally, {'tacos': 1, 'pasta': 1});
    expect(r.votedBy, {'anna', 'maja'});
  });

  test('a tie goes to whoever proposed and has won least recently', () {
    final votes = {
      'anna': {'tacos'},
      'erik': {'pasta'},
    };
    expect(
      tallyPoll(
        options: [tacos, pasta],
        eligible: family,
        votes: votes,
        lastWin: {
          'maja': DateTime.utc(2026, 9, 10),
          'erik': DateTime.utc(2026, 8, 1),
        },
      ).winner,
      'pasta',
    );
    // Never won beats any win.
    expect(
      tallyPoll(
        options: [tacos, pasta],
        eligible: family,
        votes: votes,
        lastWin: {'erik': DateTime.utc(2026, 8, 1)},
      ).winner,
      'tacos',
    );
  });

  test('no votes, no winner', () {
    expect(
      tallyPoll(options: [tacos], eligible: family, votes: const {}).winner,
      isNull,
    );
  });
}
