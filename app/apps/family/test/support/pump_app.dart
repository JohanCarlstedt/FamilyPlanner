import 'package:family/src/app.dart';
import 'package:family/src/common/clock.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:family/src/data/sample_family.dart';
import 'package:family/src/data/store_providers.dart';
import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:family/src/membership/membership.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thursday 17 September 2026, the day the sample family is seeded on.
final sampleDay = DateTime(2026, 9, 17);

/// A parent device already in a family, so the app opens past onboarding.
const sampleMembership = Membership(
  familyId: 'fam-test',
  memberId: 'member-test',
  deviceId: 'device-test',
  isParent: true,
  trusted: [],
);

/// Pumps the whole app at [size], pinned to [now] (UTC) and the sample family
/// seeded on [sampleDay], so tests never depend on the wall clock. Pass a null
/// [membership] to start where a fresh install does.
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  DateTime? now,
  Membership? membership = sampleMembership,
  DevicePreferences? preferences,
  /// Trips and holidays covering the sample week.
  List<Absence> absences = const [],
  /// Applied after the defaults, so a caller can replace any of them.
  ///
  /// Typed dynamic because Riverpod 3.4 does not export `Override`: a
  /// caller can write `someProvider.overrideWith(...)` but cannot name what
  /// it returns. The list is spread into ProviderScope, which checks it.
  List<dynamic> overrides = const [],
}) async {
  final prefs = preferences ?? MemoryPreferences();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fixedNow = now ?? DateTime.utc(2026, 9, 17, 9); // 11:00 in Stockholm
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowProvider.overrideWith((ref) => Stream.value(fixedNow)),
        familyRepositoryProvider.overrideWith(
          (ref) async => SampleFamily(today: sampleDay),
        ),
        syncControllerProvider.overrideWith(_NoSync.new),
        absencesProvider.overrideWith((ref) => Stream.value(absences)),
        devicePreferencesProvider.overrideWith((ref) async => prefs),
        membershipProvider.overrideWith(() => _FixedMembership(membership)),
        ...overrides,
      ],
      child: const FamilyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedMembership extends MembershipController {
  _FixedMembership(this._membership);

  final Membership? _membership;

  @override
  Future<Membership?> build() async => _membership;
}

/// Widget tests have no server and no databases.
class _NoSync extends SyncController {
  @override
  Future<SyncReport?> build() async => null;

  @override
  Future<void> syncNow() async {}
}
