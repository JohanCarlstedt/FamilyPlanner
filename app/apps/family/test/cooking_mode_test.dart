import 'package:family/l10n/generated/app_localizations.dart';
import 'package:family/src/features/shopping/cooking_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cooking from a recipe: the screen kept on while it is open and given
/// back afterwards, and the ingredients ticked off as they go in.
void main() {
  testWidgets('the screen stays on while cooking, and not after', (
    tester,
  ) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('family/screen'),
      (call) async {
        calls.add('${call.method}:${call.arguments}');
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CookingModeScreen(
                  title: 'Pannkakor',
                  ingredients: const ['3 dl vetemjöl', '6 dl mjölk', '3 ägg'],
                  portions: 4,
                  notes: 'Vila smeten en stund.',
                  url: 'https://example.com/pannkakor',
                  fetchSteps: (_) async => [
                    'Vispa ihop mjöl och mjölk.',
                    'Vispa i äggen.',
                  ],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(calls, ['keepOn:true']);
    expect(find.text('For 4'), findsOneWidget);

    // Ticked off as it goes in.
    await tester.tap(find.text('6 dl mjölk'));
    await tester.pump();
    final milk = tester.widget<Text>(find.text('6 dl mjölk'));
    expect(milk.style?.decoration, TextDecoration.lineThrough);

    // Swiped over to the steps, read from the page; the notes below them.
    await tester.fling(find.byType(TabBarView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Vispa i äggen.'), findsOneWidget);
    expect(find.text('Vila smeten en stund.'), findsOneWidget);
    await tester.tap(find.text('Vispa i äggen.'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Vispa i äggen.')).style?.decoration,
      TextDecoration.lineThrough,
    );

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(calls, ['keepOn:true', 'keepOn:false']);
  });

  testWidgets('no link: says so, and shows the family\'s notes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CookingModeScreen(
          title: 'Mormors bullar',
          ingredients: ['25 g jäst'],
          portions: 20,
          notes: 'Kardemumma, mycket.',
        ),
      ),
    );
    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();
    expect(
      find.text('This recipe has no link to fetch steps from.'),
      findsOneWidget,
    );
    expect(find.text('Kardemumma, mycket.'), findsOneWidget);
  });

  test('ingredients follow the portions, and read as written otherwise', () {
    expect(ingredientFor('3 dl vetemjöl', 1), '3 dl vetemjöl');
    expect(ingredientFor('3 dl vetemjöl', 2), contains('6'));
  });
}
