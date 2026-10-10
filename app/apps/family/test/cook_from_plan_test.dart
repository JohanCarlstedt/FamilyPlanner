import 'package:family/src/features/shopping/cooking_mode.dart';
import 'package:family/src/features/shopping/menu_screen.dart';
import 'package:family/src/features/shopping/shopping_providers.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Cooking mode straight from the meal plan, for the meal's portions.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('a planned meal with a recipe opens in cooking mode', (
    tester,
  ) async {
    // Thursday 17 September 2026 in the sample family: its week's plan.
    final thursday = DateTime.utc(2026, 9, 17);
    await pumpApp(
      tester,
      size: const Size(390, 2400),
      overrides: [
        recipesProvider.overrideWith(
          (ref) => Stream.value([
            (
              'r1',
              RecipePayload.write(
                title: 'Pannkakor',
                ingredients: ['3 dl vetemjöl', '6 dl mjölk'],
                servings: 4,
              ),
            ),
          ]),
        ),
        mealsProvider.overrideWith(
          (ref) => Stream.value([
            (
              'm1',
              MealPayload.write(
                date: thursday,
                servings: 8,
                recipes: const [MealRecipe(recipeId: 'r1', role: 'main')],
              ),
            ),
          ]),
        ),
      ],
    );
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go(MenuScreen.pathShowing(thursday));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cooking mode'));
    await tester.pumpAndSettle();
    expect(find.byType(CookingModeScreen), findsOneWidget);
    // The meal's own portions, twice the recipe's.
    expect(find.text('For 8'), findsOneWidget);
    expect(find.textContaining('mjölk'), findsOneWidget);
    expect(find.text('6 dl mjölk'), findsNothing,
        reason: 'scaled from the recipe\'s four');
  });
}
