import 'package:family/src/common/repeat_span.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repeating thing goes on for ever, or between two days.
///
/// "Ends, but we never said when" is the state this removes: a term's
/// glosor used to run into the summer holiday because nothing ever asked.
void main() {
  final september = DateTime.utc(2026, 9, 22);

  test('no end is for ever, and that is a real answer', () {
    final forever = RepeatSpan(startsOn: september);
    expect(forever.isForever, isTrue);
    expect(forever.isUsable, isTrue);
  });

  test('an end after the start is a span', () {
    final term = RepeatSpan(startsOn: september, until: DateTime.utc(2026, 12, 19));
    expect(term.isForever, isFalse);
    expect(term.isUsable, isTrue);
  });

  test('an end before the start is not', () {
    // The planner would dutifully produce nothing, and the person who
    // set it would see a chore that never appeared and no reason why.
    final backwards = RepeatSpan(startsOn: september, until: DateTime.utc(2026, 9, 1));
    expect(backwards.isUsable, isFalse);
  });

  test('ending on the day it starts is one day, not nothing', () {
    final oneDay = RepeatSpan(startsOn: september, until: september);
    expect(oneDay.isUsable, isTrue);
  });
}
