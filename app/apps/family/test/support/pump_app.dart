import 'package:family/src/app.dart';
import 'package:family/src/common/clock.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:family/src/data/sample_family.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thursday 17 September 2026, the day the sample family is seeded on.
final sampleDay = DateTime(2026, 9, 17);

/// Pumps the whole app at [size], pinned to [now] (UTC) and the sample family
/// seeded on [sampleDay], so tests never depend on the wall clock.
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  DateTime? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fixedNow = now ?? DateTime.utc(2026, 9, 17, 9); // 11:00 in Stockholm
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowProvider.overrideWith((ref) => Stream.value(fixedNow)),
        familyRepositoryProvider.overrideWithValue(
          SampleFamily(today: sampleDay),
        ),
      ],
      child: const FamilyApp(),
    ),
  );
  await tester.pumpAndSettle();
}
