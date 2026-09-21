import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adding a side used to delete the dinner.
///
/// "Köttbullar" typed by hand, then Lägg till tillbehör → "Potatis": the
/// side had nowhere to live, so it was written over the meal's own name,
/// and the week showed a dinner called Potatis with the meatballs gone.
void main() {
  final day = DateTime.utc(2026, 9, 24);

  MealPayload meal({String? title, List<MealRecipe> recipes = const []}) =>
      MealPayload.write(date: day, title: title, recipes: recipes);

  final catalogue = <String, RecipePayload>{
    'r1': RecipePayload.write(title: 'Köttbullar', ingredients: const []),
    'r2': RecipePayload.write(title: 'Gräddsås', ingredients: const []),
  };

  test('a hand-typed side survives a round trip', () {
    final written = meal(
      title: 'Köttbullar',
      recipes: const [MealRecipe(title: 'Potatis', role: 'side')],
    );
    final read = MealPayload.read(written.payload);
    expect(read.title, 'Köttbullar');
    expect(read.recipes.single.title, 'Potatis');
    expect(read.recipes.single.role, 'side');
    expect(read.recipes.single.isFreeText, isTrue);
  });

  test('the meal keeps its own name once it has a side', () {
    final m = meal(
      title: 'Köttbullar',
      recipes: const [MealRecipe(title: 'Potatis', role: 'side')],
    );
    expect(m.partsOf(catalogue), ['Köttbullar', 'Potatis']);
  });

  test('a recipe side next to a hand-typed main', () {
    final m = meal(
      title: 'Köttbullar',
      recipes: const [MealRecipe(recipeId: 'r2', role: 'side')],
    );
    expect(m.partsOf(catalogue), ['Köttbullar', 'Gräddsås']);
  });

  test('a meal made of recipes alone has no title to repeat', () {
    final m = meal(
      recipes: const [
        MealRecipe(recipeId: 'r1'),
        MealRecipe(recipeId: 'r2', role: 'side'),
      ],
    );
    expect(m.partsOf(catalogue), ['Köttbullar', 'Gräddsås']);
  });

  test('a recipe nobody has any more is left out, not shown blank', () {
    final m = meal(recipes: const [MealRecipe(recipeId: 'gone')]);
    expect(m.partsOf(catalogue), isEmpty);
  });

  test('a meal written before sides had names still reads', () {
    // Invariant 3: the field is additive, and last week's payload has
    // no 'title' on its recipes.
    final old = MealPayload.write(
      date: day,
      recipes: const [MealRecipe(recipeId: 'r1')],
    );
    final read = MealPayload.read(old.payload);
    expect(read.recipes.single.title, isNull);
    expect(read.partsOf(catalogue), ['Köttbullar']);
  });
}
