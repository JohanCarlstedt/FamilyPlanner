import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// The electricity price area travels with the family's settings.
void main() {
  FamilySettings roundTrip(FamilySettings s) =>
      SettingsPayload.read(SettingsPayload.write(settings: s).payload)
          .toDomain();

  test('chosen, it is kept; not chosen, no price is shown', () {
    expect(roundTrip(FamilySettings.defaults).priceArea, isNull);
    final se3 = FamilySettings.defaults.copyWith(priceArea: () => PriceArea.se3);
    expect(roundTrip(se3).priceArea, PriceArea.se3);
  });

  test('an area a later version added reads as off, and is kept', () {
    final p = SettingsPayload.write(settings: FamilySettings.defaults).payload
      ..setText('priceArea', 'se5');
    expect(SettingsPayload.read(p).toDomain().priceArea, isNull);
  });
}
