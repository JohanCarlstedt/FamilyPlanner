import 'package:domain/domain.dart';
import 'package:family/src/features/rewards/city_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a test: a child's city at the end of level 1, the first day of
/// level 2 and a full level 2, at a phone's size, to look at.
/// flutter test --update-goldens tool/level_preview_test.dart
void main() {
  const spots = [
    (8, 8, Zone.home),
    (8, 9, Zone.park),
    (9, 8, Zone.home),
    (5, 6, Zone.home),
    (6, 5, Zone.home),
    (9, 9, Zone.home),
    (8, 10, Zone.home),
    (5, 8, Zone.park),
    (9, 10, Zone.shop),
    (10, 8, Zone.home),
    (10, 9, Zone.home),
    (4, 6, Zone.home),
    (6, 4, Zone.home),
    (9, 5, Zone.park),
    (10, 5, Zone.home),
    (5, 9, Zone.home),
    (6, 10, Zone.home),
    (10, 10, Zone.market),
    (4, 5, Zone.home),
  ];
  final start = DateTime.utc(2026, 9, 1, 8);

  City at(int done) => cityOf(
    'tuva',
    contributions: [
      for (var i = 0; i < done; i++)
        Contribution(
          memberId: 'tuva',
          at: start.add(Duration(days: i)),
          growsWorld: true,
          isHomework: i % 3 == 1,
        ),
    ],
    lots: [
      for (final (i, (x, y, z)) in spots.take(done).indexed)
        CityLot(
          x: x,
          y: y,
          zone: z,
          at: start.add(Duration(days: i, hours: 1)),
          good: z == Zone.market ? Good.wool : null,
        ),
    ],
    jarEverFull: false,
    today: DateTime.utc(2026, 10, 30),
  );

  for (final (name, done) in [
    ('level1_end', 7),
    ('level2_start', 8),
    ('level2_full', 19),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1170, 930);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: CityView(city: at(done), night: false, festival: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await expectLater(find.byType(CityView), matchesGoldenFile('$name.png'));
    });
  }

  // What a phone shows now: zoomed to the open town, drawn at three
  // times, as a phone's screen is. Two moments, a few seconds apart.
  for (final (name, done, ms, night) in [
    ('level2_zoomed_a', 19, 3000, false),
    ('level2_zoomed_b', 19, 7000, false),
    ('level2_zoomed_night', 19, 5000, true),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1170, 930);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final city = at(done);
      const width = 390.0, height = 310.0;
      final scale = (City.size / (city.radius * 2 + 3)).clamp(1.0, 4.0);
      final (:centre, height: _) = cityCentre(width);
      final fit = Matrix4.identity()
        ..translateByDouble(
          width / 2 - centre.dx * scale,
          height / 2 - centre.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Align(
            alignment: Alignment.topLeft,
            child: Transform.scale(
              scale: 3,
              alignment: Alignment.topLeft,
              child: ClipRect(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: Transform(
                      transform: fit,
                      child: SizedBox(
                        width: width,
                        child: CityView(
                          city: city,
                          night: night,
                          festival: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(Duration(milliseconds: ms));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$name.png'),
      );
    });
  }
}
