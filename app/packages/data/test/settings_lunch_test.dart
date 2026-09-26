import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each child\'s school lunch is kept, and the rest with it', () {
    const settings = FamilySettings(
      rewardsOn: true,
      lunchSchools: {
        'maja': 'engelbrektsskolan-stockholm',
        'olle': 'sjostadsskolan',
      },
    );
    final back = SettingsPayload.write(settings: settings).toDomain();
    expect(back.lunchSchools, settings.lunchSchools);
    expect(back.rewardsOn, isTrue);
    final changed = back.copyWith(jarSize: 12);
    expect(changed.lunchSchools, settings.lunchSchools,
        reason: 'changing something else keeps the schools');
  });
}
