import 'package:family/src/features/shopping/menu_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which week the menu opens on.
void main() {
  final friday = DateTime.utc(2026, 9, 25);
  final wednesday = DateTime.utc(2026, 9, 23);
  final thisMonday = DateTime.utc(2026, 9, 21);
  final nextMonday = DateTime.utc(2026, 9, 28);

  test('for planning, from Friday it is the week ahead', () {
    expect(MenuScreen.weekToOpen(today: wednesday), thisMonday);
    expect(MenuScreen.weekToOpen(today: friday), nextMonday);
    expect(MenuScreen.weekToOpen(today: DateTime.utc(2026, 9, 27)), nextMonday);
  });

  test(
    'opened from tonight\'s dinner, it is tonight\'s week, Friday or not',
    () {
      expect(MenuScreen.weekToOpen(today: friday, showing: friday), thisMonday);
      expect(
        MenuScreen.weekToOpen(
          today: friday,
          showing: DateTime.utc(2026, 9, 27),
        ),
        thisMonday,
        reason: 'Sunday is still the week that started on Monday',
      );
    },
  );

  test('the link carries the day it was opened for', () {
    expect(MenuScreen.pathShowing(friday), '/shopping/menu?day=2026-09-25');
    expect(MenuScreen.dayFrom('2026-09-25'), friday);
    expect(MenuScreen.dayFrom('nonsense'), isNull);
    expect(MenuScreen.dayFrom(null), isNull);
  });
}
