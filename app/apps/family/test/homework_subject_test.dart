import 'package:family/src/features/homework/homework_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adding a subject crashed the dialog it was added from.
///
/// The new subject was selected the instant it was saved, but the list of
/// subjects comes from the store's stream and had not caught up — so the
/// dropdown was handed a value with no item to match it, and Flutter
/// asserts there is exactly one of those. Reported from a real phone, in
/// the middle of entering the week's homework.
void main() {
  const swedish = ('s1', 'Svenska');
  const maths = ('s2', 'Matematik');

  test('a subject just made is offered and chosen before it arrives', () {
    final r = subjectChoice(
      stored: const [swedish],
      justMade: maths,
      wanted: maths.$1,
    );
    expect(r.choices, [swedish, maths]);
    expect(r.chosen, maths.$1);
  });

  test('and is not offered twice once it does arrive', () {
    final r = subjectChoice(
      stored: const [swedish, maths],
      justMade: maths,
      wanted: maths.$1,
    );
    expect(r.choices, [swedish, maths]);
    expect(r.chosen, maths.$1);
  });

  test('a chosen subject the list does not hold is no longer chosen', () {
    // Switching child empties the list under a selection made for the
    // other one. Any value with no item is the same crash.
    final r = subjectChoice(
      stored: const [],
      justMade: null,
      wanted: maths.$1,
    );
    expect(r.choices, isEmpty);
    expect(r.chosen, isNull);
  });

  test('nothing chosen stays nothing chosen', () {
    final r = subjectChoice(
      stored: const [swedish],
      justMade: null,
      wanted: null,
    );
    expect(r.chosen, isNull);
  });

  test('the chosen value always has exactly one item', () {
    // The assertion Flutter makes, made here instead.
    for (final wanted in [null, 's1', 's2', 'gone']) {
      final r = subjectChoice(
        stored: const [swedish],
        justMade: maths,
        wanted: wanted,
      );
      expect(
        r.choices.where((s) => s.$1 == r.chosen).length,
        r.chosen == null ? 0 : 1,
        reason: 'wanted $wanted',
      );
    }
  });
}
