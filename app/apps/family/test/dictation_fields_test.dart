import 'package:family/src/common/dictation.dart';
import 'package:family/src/features/members/sizes_screen.dart';
import 'package:family/src/features/shopping/shopping_providers.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Wherever someone writes words, they can say them instead.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('a microphone goes beside what a field already has', () {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final bare = const InputDecoration().withDictation(controller);
    expect(bare.suffixIcon, isA<DictationButton>());
    final withClear = const InputDecoration(
      suffixIcon: Icon(Icons.close),
    ).withDictation(controller);
    final row = withClear.suffixIcon! as Row;
    expect(row.children.first, isA<DictationButton>());
    expect(row.children.last, isA<Icon>());
  });

  for (final kind in ShoppingListKind.values) {
    testWidgets('the ${kind.name} list can be spoken to', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          shoppingListsProvider.overrideWith(
            (ref) => Stream.value([
              ('list', ShoppingListPayload.write(name: 'Lista', kind: kind)),
            ]),
          ),
          shoppingItemsProvider.overrideWith((ref) => Stream.value(const [])),
          currentListProvider.overrideWith(_FixedList.new),
          sizeCardsProvider.overrideWith((ref) => Stream.value(const {})),
        ],
      );
      await tester.tap(find.text('Shopping').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TextField).first,
          matching: find.byType(DictationButton),
        ),
        findsOneWidget,
      );
    });
  }
}

class _FixedList extends CurrentListNotifier {
  @override
  Future<String?> build() async => 'list';
}
