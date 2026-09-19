import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const catalogue = IngredientCatalogue.swedish;
  const nuts = DietNote(
    memberId: 'maja',
    type: DietType.allergy,
    value: 'nuts',
    strict: true,
  );
  const onion = DietNote(
    memberId: 'erik',
    type: DietType.dislike,
    value: 'lök',
  );

  test('a note on a catalogue ingredient catches every way of writing it', () {
    final hits = dietConflicts(
      ['1 dl skalade rostade hasselnötter', '2 dl grädde'],
      [nuts],
      catalogue,
    );
    expect(hits.single.note, nuts);
    expect(hits.single.line, '1 dl skalade rostade hasselnötter');
  });

  test('free text matches the words in a line', () {
    expect(
      dietConflicts(['2 gula lökar', '1 msk olja'], [onion], catalogue)
          .map((h) => h.line),
      ['2 gula lökar'],
    );
    expect(dietConflicts(['1 msk olja'], [onion], catalogue), isEmpty);
  });

  test('only strict notes keep a recipe out of a poll', () {
    final lines = ['2 gula lökar', '1 dl hasselnötter'];
    expect(excludedFromPolls(lines, [onion], catalogue), isFalse);
    expect(excludedFromPolls(lines, [onion, nuts], catalogue), isTrue);
  });

  test('a note reads back from what it stores', () {
    expect(
      DietNote.values(
        memberId: 'maja',
        type: 'allergy',
        value: 'nuts',
        strict: true,
      ),
      nuts,
    );
  });
}
