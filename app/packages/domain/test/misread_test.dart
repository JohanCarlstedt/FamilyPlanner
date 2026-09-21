import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Recognising text that was read with the wrong encoding, so the
/// unreadable copies that mistake left behind can be cleared away.
///
/// Homework imported before the encoding was fixed cannot be matched to
/// its corrected self: the id is derived from the title, so the repaired
/// text arrived as a new piece of homework and the broken one stayed
/// beside it. Both are on a real family's screen right now.
void main() {
  test('the marks of UTF-8 read a byte at a time', () {
    expect(looksMisread('Fundera pÃ¥ vad man ser'), isTrue);
    expect(looksMisread('LÃ¤suppdrag och veckans ord'), isTrue);
    expect(looksMisread('UpptÃ¤ck historia'), isTrue);
    expect(looksMisread('Hur uppfattar Ã¶gat det vi ser?'), isTrue);
  });

  test('Swedish that came through properly is left alone', () {
    // The whole point. Mistaking these for the broken ones would delete
    // a child's homework.
    expect(looksMisread('Fundera på vad man ser'), isFalse);
    expect(looksMisread('Läsuppdrag och veckans ord'), isFalse);
    expect(looksMisread('Upptäck historia'), isFalse);
    expect(looksMisread('Öva glosor'), isFalse);
    expect(looksMisread('Repetera s 52-55 Medeltiden'), isFalse);
  });

  test('a lone Ã is not enough to delete work over', () {
    expect(looksMisread('Ã'), isFalse);
  });
}
