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
                builder: (_) => const CookingModeScreen(
                  title: 'Pannkakor',
                  ingredients: ['3 dl vetemjöl', '6 dl mjölk', '3 ägg'],
                  portions: 4,
                  notes: 'Vila smeten en stund.',
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
    expect(find.text('Ingredients · For 4'), findsOneWidget);
    expect(find.text('Vila smeten en stund.'), findsOneWidget);

    // Ticked off as it goes in.
    await tester.tap(find.text('6 dl mjölk'));
    await tester.pump();
    final milk = tester.widget<Text>(find.text('6 dl mjölk'));
    expect(milk.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(calls, ['keepOn:true', 'keepOn:false']);
  });

  test('ingredients follow the portions, and read as written otherwise', () {
    expect(ingredientFor('3 dl vetemjöl', 1), '3 dl vetemjöl');
    expect(ingredientFor('3 dl vetemjöl', 2), contains('6'));
  });
}
