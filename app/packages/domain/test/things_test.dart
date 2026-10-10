import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// The family's things list: what a thing is, whose size it takes, and
/// who it is for when someone says so.
void main() {
  group('guessThingCategory', () {
    test('clothes, Swedish compounds included', () {
      for (final name in [
        'Vinteroverall',
        'regnbyxor',
        'Strumpor',
        'mjukisbyxor',
        'tröja',
        'Vantar',
        'winter jacket',
      ]) {
        expect(guessThingCategory(name), ThingCategory.clothes, reason: name);
      }
    });

    test('shoes, and a school bag is not a shoe', () {
      for (final name in [
        'Vinterkängor',
        'gympaskor',
        'stövlar',
        'innetofflor',
        'trainers',
      ]) {
        expect(guessThingCategory(name), ThingCategory.shoes, reason: name);
      }
      expect(guessThingCategory('skolväska'), ThingCategory.school);
    });

    test('school', () {
      for (final name in [
        'Ryggsäck',
        'pennfodral',
        'miniräknare',
        'gympapåse',
        'hörlurar',
        'pencil case',
      ]) {
        expect(guessThingCategory(name), ThingCategory.school, reason: name);
      }
    });

    test('sport wins over the shoe or sock it is', () {
      for (final name in [
        'Fotbollsskor',
        'benskydd',
        'matchstrumpor',
        'simglasögon',
        'innebandyklubba',
        'football boots',
      ]) {
        expect(guessThingCategory(name), ThingCategory.sport, reason: name);
      }
    });

    test('home and gifts', () {
      expect(guessThingCategory('glödlampor'), ThingCategory.home);
      expect(guessThingCategory('batterier AA'), ThingCategory.home);
      expect(guessThingCategory('Påslakan'), ThingCategory.home);
      expect(guessThingCategory('kalaspresent till Ella'), ThingCategory.gift);
      expect(guessThingCategory('inslagspapper'), ThingCategory.gift);
    });

    test('anything else is other', () {
      expect(guessThingCategory('mobilskal'), ThingCategory.other);
      expect(guessThingCategory(''), ThingCategory.other);
    });
  });

  group('sizeFor', () {
    final measured = DateTime.utc(2026, 8, 12);
    final card = [
      SizeEntry(kind: SizeKind.shoe, value: '35', measuredAt: measured),
      SizeEntry(kind: SizeKind.clothes, value: '140', measuredAt: measured),
      SizeEntry(
        kind: SizeKind.custom,
        label: 'Hjälm',
        value: '52–56',
        measuredAt: measured,
      ),
    ];

    test('shoes take the shoe size, sport shoes too', () {
      expect(sizeFor('Vinterkängor', card)?.value, '35');
      expect(sizeFor('Fotbollsskor', card)?.value, '35');
    });

    test('clothes take the clothes size', () {
      expect(sizeFor('regnbyxor', card)?.value, '140');
      expect(sizeFor('matchstrumpor', card)?.value, '140');
    });

    test('a row of their own is matched by its name', () {
      expect(sizeFor('cykelhjälm', card)?.value, '52–56');
    });

    test('no size for what has none', () {
      expect(sizeFor('pennfodral', card), isNull);
      expect(sizeFor('Vinterkängor', const []), isNull);
    });

    test('a size goes stale after six months', () {
      expect(card.first.isStale(DateTime.utc(2026, 12, 1)), isFalse);
      expect(card.first.isStale(DateTime.utc(2027, 2, 20)), isTrue);
      expect(
        const SizeEntry(kind: SizeKind.shoe, value: '35').isStale(measured),
        isFalse,
      );
    });
  });

  group('forWhom', () {
    const family = [('o', 'Oliver'), ('j', 'Junie'), ('a', 'Anna Ek')];

    test('"till", "åt", "för" and "for" a member', () {
      expect(forWhom('Fotbollsskor till Oliver', family), (
        'Fotbollsskor',
        'o',
      ));
      expect(forWhom('vantar åt junie', family), ('vantar', 'j'));
      expect(forWhom('regnjacka för Oliver.', family), ('regnjacka', 'o'));
      expect(forWhom('trainers for Junie', family), ('trainers', 'j'));
    });

    test('a first name is enough', () {
      expect(forWhom('handskar till Anna', family), ('handskar', 'a'));
    });

    test('someone not in the family stays in the words', () {
      expect(forWhom('kalaspresent till Ella', family), (
        'kalaspresent till Ella',
        null,
      ));
      expect(forWhom('stövlar', family), ('stövlar', null));
    });

    test('one name at the end goes for the whole spoken list', () {
      expect(forWhomAll(['fotbollsskor', 'benskydd till Oliver'], family), [
        ('fotbollsskor', 'o'),
        ('benskydd', 'o'),
      ]);
      expect(forWhomAll(['vantar till Junie', 'mössa till Oliver'], family), [
        ('vantar', 'j'),
        ('mössa', 'o'),
      ]);
      expect(forWhomAll(['mjölk', 'ägg'], family), [
        ('mjölk', null),
        ('ägg', null),
      ]);
    });
  });
}
