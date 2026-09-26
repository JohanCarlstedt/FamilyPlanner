import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an edited lunch stays a lunch', () {
    final lunch = MealPayload.write(
      date: DateTime.utc(2026, 10, 5),
      slot: 'lunch',
      title: 'Soppa',
    );
    final edited = MealPayload.write(
      existing: lunch.payload,
      date: DateTime.utc(2026, 10, 5),
      title: 'Soppa',
      servings: 5,
    );
    expect(edited.slot, 'lunch');
    expect(
      MealPayload.write(date: DateTime.utc(2026, 10, 5), title: 'x').slot,
      'dinner',
      reason: 'a new meal with no slot is dinner, as before',
    );
  });

  test('the meals a family plans are kept, in the day\'s order', () {
    const settings = FamilySettings(mealSlots: ['dinner', 'breakfast']);
    final back = SettingsPayload.write(settings: settings).toDomain();
    expect(back.mealSlots, ['breakfast', 'dinner']);
    expect(
      SettingsPayload.write(settings: const FamilySettings())
          .toDomain()
          .mealSlots,
      ['dinner'],
    );
  });
}
