import 'package:domain/domain.dart';
import 'package:family/src/features/rewards/city_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a test: a picture of a busy city, day and night, to look at.
/// flutter test --update-goldens tool/city_preview_test.dart
void main() {
  City sample(int done, {String who = 'maja'}) {
    final lots = <CityLot>[];
    final spots = [
      (8, 9, Zone.home), (9, 9, Zone.park), (9, 10, Zone.shop), (10, 9, Zone.home),
      (8, 10, Zone.home), (10, 10, Zone.home), (5, 8, Zone.home), (5, 9, Zone.park),
      (4, 8, Zone.home), (9, 5, Zone.shop), (9, 6, Zone.home), (10, 6, Zone.home),
      (8, 5, Zone.park), (10, 5, Zone.home), (5, 6, Zone.home), (4, 6, Zone.home),
      (12, 9, Zone.home), (12, 8, Zone.shop), (9, 12, Zone.home), (8, 12, Zone.park),
      (6, 12, Zone.home), (12, 5, Zone.home), (2, 9, Zone.home), (9, 2, Zone.home),
    ];
    for (final (i, (x, y, z)) in spots.indexed) {
      lots.add(CityLot(x: x, y: y, zone: z, at: DateTime.utc(2026, 8, 1).add(Duration(days: i))));
    }
    lots.add(CityLot(x: 10, y: 12, zone: Zone.home, at: DateTime.utc(2026, 9, 30, 9)));
    return cityOf(
      who,
      contributions: [
        for (var i = 0; i < done; i++)
          Contribution(
            memberId: who,
            at: DateTime.utc(2026, 8, 1).add(Duration(hours: i * 14)),
            growsWorld: true,
            isHomework: i % 3 == 0,
          ),
      ],
      lots: lots,
      jarEverFull: true,
      today: DateTime.utc(2026, 9, 30),
    );
  }

  for (final (name, who, done, night) in [
    ('day', 'maja', 140, false),
    ('night', 'maja', 140, true),
    ('tuva', 'tuva', 140, false),
    ('oliver_young', 'oliver', 60, false),
  ]) {
    testWidgets('city $name', (tester) async {
      tester.view.physicalSize = const Size(1170, 930);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: CityView(
              city: sample(done, who: who),
              night: night,
              festival: night,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2600));
      await expectLater(find.byType(CityView), matchesGoldenFile('city_$name.png'));
    });
  }
}
