import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// A recipe site's method, a step at a time, for cooking mode.
void main() {
  String page(String instructions) =>
      '<html><script type="application/ld+json">'
      '{"@type":"Recipe","name":"Pannkakor","recipeIngredient":["3 ägg"],'
      '"recipeInstructions":$instructions}'
      '</script></html>';

  test('HowToSteps, as ICA and most sites write them', () {
    final r = RecipeImport.fromHtml(page(
      '[{"@type":"HowToStep","text":"Vispa ihop mjöl och mjölk."},'
      '{"@type":"HowToStep","text":"Vispa i äggen."}]',
    ))!;
    expect(r.steps, ['Vispa ihop mjöl och mjölk.', 'Vispa i äggen.']);
  });

  test('sections of steps, in order', () {
    final r = RecipeImport.fromHtml(page(
      '[{"@type":"HowToSection","name":"Smet","itemListElement":['
      '{"@type":"HowToStep","text":"Blanda."}]},'
      '{"@type":"HowToSection","name":"Stek","itemListElement":['
      '{"@type":"HowToStep","text":"Stek tunt."}]}]',
    ))!;
    expect(r.steps, ['Blanda.', 'Stek tunt.']);
  });

  test('one text, a step a line, markup and entities taken out', () {
    final r = RecipeImport.fromHtml(page(
      r'"<p>Vispa &amp; blanda.</p><p>Stek i <b>smör</b>.</p>"',
    ))!;
    expect(r.steps, ['Vispa & blanda.', 'Stek i smör.']);
  });

  test('a list of plain texts', () {
    final r = RecipeImport.fromHtml(page('["Blanda.", "  ", "Stek."]'))!;
    expect(r.steps, ['Blanda.', 'Stek.']);
  });

  test('none published, none read', () {
    final r = RecipeImport.fromHtml(
      '<script type="application/ld+json">'
      '{"@type":"Recipe","name":"X","recipeIngredient":[]}</script>',
    )!;
    expect(r.steps, isEmpty);
  });
}
