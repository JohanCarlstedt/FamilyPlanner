import 'package:domain/domain.dart';
import 'package:family/src/features/rewards/city_sprites.dart';
import 'package:family/src/features/rewards/city_view.dart';
import 'package:flutter/services.dart';
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

  // Level 4: 45 done, a third of it homework, 45 buildings laid out from
  // the middle outwards (the oldest, grown most, nearest the square).
  City level4({
    DateTime? from,
    bool services = false,
    List<FamilyProject> projects = const [],
  }) {
    final begin = from ?? start;
    const who = 'tuva';
    final base = cityOf(
      who,
      contributions: const [],
      lots: const [],
      jarEverFull: true,
      today: DateTime.utc(2026, 12, 30),
    );
    final plots =
        <(int, int)>[
          for (var y = 0; y < City.size; y++)
            for (var x = 0; x < City.size; x++)
              if ((x - City.centre).abs() <= 5 &&
                  (y - City.centre).abs() <= 5 &&
                  !base.isRoad(x, y) &&
                  !base.isWater(x, y) &&
                  !City.civicPlots.values.contains((x, y)))
                (x, y),
        ]..sort((a, b) {
          int d((int, int) p) =>
              (p.$1 - City.centre).abs() + (p.$2 - City.centre).abs();
          return d(a).compareTo(d(b));
        });
    final shore = plots.firstWhere(
      (p) => [
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ].any((d) => base.isWater(p.$1 + d.$1, p.$2 + d.$2)),
    );
    final lots = <CityLot>[];
    var day = 0;
    for (final (x, y) in plots) {
      if (lots.length >= 45) break;
      final i = lots.length;
      final at = begin.add(Duration(days: day++, hours: 1));
      final service = !services
          ? null
          : const {
              4: Service.power,
              16: Service.water,
              22: Service.bus,
              33: Service.clinic,
            }[i];
      if (service != null) {
        lots.add(
          CityLot(x: x, y: y, zone: Zone.service, at: at, service: service),
        );
      } else if ((x, y) == shore) {
        lots.add(
          CityLot(
            x: x,
            y: y,
            zone: Zone.landmark,
            at: at,
            landmark: Landmark.harbour,
          ),
        );
      } else if (i == 12) {
        lots.add(
          CityLot(x: x, y: y, zone: Zone.market, at: at, good: Good.wool),
        );
      } else if (i == 30) {
        lots.add(
          CityLot(
            x: x,
            y: y,
            zone: Zone.landmark,
            at: at,
            landmark: Landmark.castle,
          ),
        );
      } else {
        final zone = i % 6 == 3
            ? Zone.park
            : i % 7 == 5
            ? Zone.shop
            : Zone.home;
        lots.add(CityLot(x: x, y: y, zone: zone, at: at));
      }
    }
    return cityOf(
      who,
      contributions: [
        for (var i = 0; i < 45; i++)
          Contribution(
            memberId: who,
            at: begin.add(Duration(days: i)),
            growsWorld: true,
            isHomework: i % 3 == 1,
          ),
      ],
      lots: lots,
      jarEverFull: true,
      today: DateTime.utc(2027, 3, 30),
      projects: projects,
    );
  }

  for (final (name, night) in [('level4_day', false), ('level4_night', true)]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1170, 930);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final city = level4();
      // ignore: avoid_print
      print(
        '$name: level ${city.level}, radius ${city.radius}, '
        'civic ${city.civic.map((c) => c.name).join(',')}',
      );
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
      await tester.pump(const Duration(milliseconds: 4000));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$name.png'),
      );
    });
  }

  // The same towns drawn with the 3D kits' pictures (assets/city).
  CitySprites? sprites;
  Future<CitySprites> loadSprites(WidgetTester tester) async =>
      sprites ??= (await tester.runAsync(() => CitySprites.load(rootBundle)))!;

  for (final (name, which, night) in [
    ('city3d_level2', 2, false),
    ('city3d_level4', 4, false),
    ('city3d_level4_night', 4, true),
    ('city3d_services', 5, false),
    ('city3d_services_night', 5, true),
  ]) {
    testWidgets(name, (tester) async {
      final loaded = await loadSprites(tester);
      tester.view.physicalSize = const Size(1170, 930);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final city = switch (which) {
        2 => at(19),
        5 => level4(
          from: DateTime.utc(2026, 10, 1, 8),
          services: true,
          projects: const [FamilyProject.statue, FamilyProject.clockTower],
        ),
        _ => level4(),
      };
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
                          sprites: loaded,
                          happening: which == 5
                              ? (night
                                    ? Happening.meteorShower
                                    : Happening.balloonRace)
                              : null,
                          population: which == 5 ? populationOf(city) : 0,
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
      await tester.pump(const Duration(milliseconds: 4000));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$name.png'),
      );
    });
  }
}
