import 'dart:io';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ingredient lines, as Swedish recipes write them', () {
    IngredientLine p(String s) => IngredientLine.parse(s);

    test('amount, unit, name and a note in brackets', () {
      final l = p('900 g blå potatis (gärna doubble fun eller violett queen)');
      expect(l.quantity, 900);
      expect(l.unit, Unit.g);
      expect(l.name, 'blå potatis');
      expect(l.note, 'gärna doubble fun eller violett queen');
    });

    test('mixed fractions, unicode fractions and decimal commas', () {
      expect(p('1 1/2 dl neutral rapsolja').quantity, 1.5);
      expect(p('½ tsk dijonsenap').quantity, 0.5);
      expect(p('1/2 tsk dijonsenap').unit, Unit.tsk);
      expect(p('0,5 l mjölk').quantity, 0.5);
      expect(p('0,5 l mjölk').unit, Unit.l);
    });

    test('a range buys the upper end', () {
      final l = p('1 -  2 msk rapsolja');
      expect(l.quantity, 2);
      expect(l.unit, Unit.msk);
      expect(l.name, 'rapsolja');
      expect(p('2–3 gula lökar').quantity, 3);
    });

    test('a count without a unit is pieces; no amount is just a name', () {
      final eggs = p('2 äggulor');
      expect((eggs.quantity, eggs.unit, eggs.name), (2, Unit.st, 'äggulor'));
      final salt = p('flingsalt');
      expect((salt.quantity, salt.unit, salt.name), (null, null, 'flingsalt'));
      expect(p('ca 300 g kallrökt lax i bit').quantity, 300);
      expect(p('1 förp krossade tomater').unit, Unit.forp);
      expect(p('2 klyftor vitlök').unit, Unit.klyfta);
      expect(p('3 krm salt').unit, Unit.krm);
    });
  });

  group('the catalogue', () {
    const catalogue = IngredientCatalogue.swedish;

    test('finds the ingredient behind the words a recipe uses', () {
      expect(catalogue.match('gula lökar')?.key, 'onion');
      expect(catalogue.match('gul lök')?.key, 'onion');
      expect(catalogue.match('neutral rapsolja')?.key, 'rapeseed_oil');
      expect(catalogue.match('vispgrädde')?.key, 'cream');
      expect(catalogue.match('äggulor')?.key, 'egg');
      expect(catalogue.match('hackad persilja')?.key, 'parsley');
      expect(catalogue.match('birthday candles'), isNull);
    });

    test('aisles group the list', () {
      expect(catalogue.byKey('onion')!.category, Aisle.produce);
      expect(catalogue.byKey('cream')!.category, Aisle.dairy);
    });
  });

  group('merging a list', () {
    const catalogue = IngredientCatalogue.swedish;
    ShoppingLine line(String text) =>
        ShoppingLine.fromIngredient(IngredientLine.parse(text), catalogue);

    test('the same thing in compatible units becomes one line', () {
      final merged = mergeShoppingLines([
        line('2 dl grädde'),
        line('3 msk vispgrädde'),
        line('1 gul lök'),
        line('2 gula lökar'),
      ]);
      expect(merged.map((m) => m.describe()), [
        '2,5 dl grädde',
        '3 st gul lök',
      ]);
    });

    test('pieces and grams of the same thing stay apart, next to each other',
        () {
      final merged = mergeShoppingLines([
        line('2 gula lökar'),
        line('150 g lök'),
      ]);
      expect(merged, hasLength(2));
      expect(merged.every((m) => m.key == 'onion'), isTrue);
    });

    test('packages are never normalised, free text never merges', () {
      final merged = mergeShoppingLines([
        line('1 förp krossade tomater'),
        line('1 burk krossade tomater'),
        line('1 förp krossade tomater'),
        line('tårtljus'),
        line('tårtljus'),
      ]);
      expect(merged.map((m) => m.describe()), [
        '2 förp krossade tomater',
        '1 burk krossade tomater',
        'tårtljus',
        'tårtljus',
      ]);
    });

    test('big amounts read naturally', () {
      final merged = mergeShoppingLines([
        line('900 g potatis'),
        line('600 g potatis'),
        line('7 dl mjölk'),
        line('5 dl mjölk'),
      ]);
      expect(
          merged.map((m) => m.describe()), ['1,5 kg potatis', '1,2 l mjölk']);
    });

    test('one big amount reads naturally too', () {
      expect(line('1350 g potatis').describe(), '1,4 kg potatis');
      expect(line('12 dl mjölk').describe(), '1,2 l mjölk');
      expect(line('900 g potatis').describe(), '900 g potatis');
    });

    test('scaling a recipe from 4 to 6 portions', () {
      final l = line('2 dl grädde').scaled(6 / 4);
      expect(l.describe(), '3 dl grädde');
    });
  });

  group('recipes from a web page (schema.org JSON-LD)', () {
    test('an ICA recipe', () {
      final r = RecipeImport.fromHtml(
        File('test/fixtures/ica-recipe.html').readAsStringSync(),
      )!;
      expect(r.title, startsWith('Potatissallad'));
      expect(r.servings, 4);
      expect(r.totalMinutes, 45);
      expect(r.ingredients, hasLength(14));
      expect(r.ingredients.first, startsWith('900 g blå potatis'));
      expect(r.imageUrl, startsWith('https://assets.icanet.se/'));
    });

    test('graphs, lists and "4 portioner"', () {
      const html = '''
<script type="application/ld+json">
{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},
 {"@type":["Recipe"],"name":"Pannkakor","recipeYield":["4","4 portioner"],
  "prepTime":"PT10M","cookTime":"PT1H5M",
  "recipeIngredient":["3 ägg","6 dl mjölk"],"image":[{"url":"https://x/p.jpg"}]}]}
</script>''';
      final r = RecipeImport.fromHtml(html)!;
      expect(r.title, 'Pannkakor');
      expect(r.servings, 4);
      expect(r.totalMinutes, 75);
      expect(r.imageUrl, 'https://x/p.jpg');
    });

    test('a page with no recipe is none', () {
      expect(RecipeImport.fromHtml('<html>Hej</html>'), isNull);
    });
  });
}
