import 'dart:async';

import 'package:family/src/app.dart';
import 'package:family/src/common/clock.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:family/src/data/sample_family.dart';
import 'package:family/src/data/store_providers.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('the now marker follows the clock', (tester) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final clock = StreamController<DateTime>();
    addTearDown(clock.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWith((ref) => clock.stream),
          familyRepositoryProvider.overrideWith(
            (ref) async => SampleFamily(today: sampleDay),
          ),
          membershipProvider.overrideWith(() => _Fixed()),
          syncControllerProvider.overrideWith(_NoSync.new),
          absencesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const FamilyApp(),
      ),
    );

    clock.add(DateTime.utc(2026, 9, 17, 9)); // 11:00 in Stockholm
    await tester.pumpAndSettle();
    expect(find.text('11:00'), findsOneWidget);

    clock.add(DateTime.utc(2026, 9, 17, 9, 1)); // a minute later
    await tester.pumpAndSettle();
    expect(find.text('11:01'), findsOneWidget);
    expect(find.text('11:00'), findsNothing);
  });
}

class _Fixed extends MembershipController {
  @override
  Future<Membership?> build() async => sampleMembership;
}

class _NoSync extends SyncController {
  @override
  Future<SyncReport?> build() async => null;

  @override
  Future<void> syncNow() async {}
}
