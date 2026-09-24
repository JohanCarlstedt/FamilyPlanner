import 'package:domain/domain.dart';
import 'package:family/src/features/rewards/city_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a test: a trading house and every special building, to look at.
/// flutter test --update-goldens tool/landmark_preview_test.dart
void main() {
  testWidgets('landmarks', (tester) async {
    final at = DateTime.utc(2026, 8, 1);
    final bare = cityOf(
      'maja',
      contributions: const [],
      lots: const [],
      jarEverFull: false,
      today: DateTime.utc(2026, 9, 30),
    );
    // The harbour on the shore of this city's own lake.
    final shore = [
      for (final (x, y) in bare.water)
        for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)])
          if (!bare.water.contains((x + dx, y + dy)) &&
              (x + dx - City.centre).abs() != 4 &&
              (y + dy - City.centre).abs() != 4 &&
              x + dx != City.centre &&
              y + dy != City.centre)
            (x + dx, y + dy),
    ].first;
    final city = cityOf(
      'maja',
      contributions: [
        for (var i = 0; i < 200; i++)
          Contribution(
            memberId: 'maja',
            at: at.add(Duration(hours: i * 6)),
            growsWorld: true,
          ),
      ],
      lots: [
        CityLot(x: 9, y: 9, zone: Zone.market, at: at, good: Good.fish),
        CityLot(x: 8, y: 9, zone: Zone.landmark, at: at, landmark: Landmark.castle),
        CityLot(x: 9, y: 10, zone: Zone.landmark, at: at, landmark: Landmark.zoo),
        CityLot(x: 10, y: 9, zone: Zone.landmark, at: at, landmark: Landmark.stadium),
        CityLot(x: 10, y: 10, zone: Zone.landmark, at: at, landmark: Landmark.bakery),
        CityLot(x: shore.$1, y: shore.$2, zone: Zone.landmark, at: at, landmark: Landmark.harbour),
      ],
      jarEverFull: false,
      today: DateTime.utc(2026, 9, 30),
    );
    tester.view.physicalSize = const Size(1170, 930);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: CityView(city: city, night: false, festival: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await expectLater(find.byType(CityView), matchesGoldenFile('landmarks.png'));
  });
}
