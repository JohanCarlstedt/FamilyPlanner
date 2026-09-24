import 'package:domain/domain.dart';
import 'package:family/src/features/rewards/city_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a test: four parks at the four stages, close up, to look at.
/// flutter test --update-goldens tool/park_preview_test.dart
void main() {
  for (final who in ['maja', 'tuva']) {
    testWidgets('parks $who', (tester) async {
      final start = DateTime.utc(2026, 8, 1);
      DateTime step(double i) =>
          start.add(Duration(minutes: (i * 14 * 60).round()));
      final city = cityOf(
        who,
        contributions: [
          for (var i = 0; i < 60; i++)
            Contribution(memberId: who, at: step(i.toDouble()), growsWorld: true),
        ],
        lots: [
          CityLot(x: 9, y: 6, zone: Zone.park, at: step(58.5)),
          CityLot(x: 10, y: 7, zone: Zone.park, at: step(53.5)),
          CityLot(x: 11, y: 8, zone: Zone.park, at: step(44.5)),
          CityLot(x: 12, y: 9, zone: Zone.park, at: start),
        ],
        jarEverFull: false,
        today: DateTime.utc(2026, 9, 30),
      );
      for (final (x, y) in [(9, 6), (10, 7), (11, 8), (12, 9)]) {
        debugPrint('$who park ($x,$y): size ${city.sizeOf(x, y)}');
      }
      tester.view.physicalSize = const Size(1170, 900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: CityView(city: city, night: false, festival: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await expectLater(find.byType(CityView), matchesGoldenFile('parks_$who.png'));
    });
  }
}
