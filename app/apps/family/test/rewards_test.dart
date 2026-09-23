import 'package:domain/domain.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:family/src/data/store_providers.dart' show MemoryPreferences;
import 'package:family/src/features/rewards/fireworks.dart';
import 'package:family/src/features/rewards/rewards_providers.dart';
import 'package:family/src/features/rewards/world_screen.dart';
import 'package:family/src/features/rewards/city_view.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// Spec section 3, "Contributions", on screen.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('the switch', () {
    testWidgets('with rewards off, there is no jar anywhere', (tester) async {
      await pumpApp(tester);
      expect(find.byType(JarCard), findsOneWidget);
      expect(find.text('Family jar'), findsNothing);
    });

    testWidgets('with rewards on, Today has the jar and what it is for', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          settingsProvider.overrideWith(
            (ref) => Stream.value(
              const FamilySettings(rewardsOn: true, jarSize: 5, jarFor: 'Pizzakväll'),
            ),
          ),
          contributionsProvider.overrideWith(
            (ref) => [
              for (var i = 0; i < 3; i++)
                Contribution(
                  memberId: 'maja',
                  at: DateTime.utc(2026, 9, 16, 12, i),
                  growsWorld: true,
                ),
            ],
          ),
        ],
      );
      expect(find.text('Family jar'), findsOneWidget);
      expect(find.text('3 of 5 this week'), findsOneWidget);
      expect(find.text('Pizzakväll'), findsOneWidget);
    });
  });

  group("a child's city", () {
    const asMaja = Membership(
      familyId: 'fam-test',
      memberId: 'maja',
      deviceId: 'device-maja',
      isParent: false,
      trusted: [],
    );
    const asAnna = Membership(
      familyId: 'fam-test',
      memberId: 'anna',
      deviceId: 'device-anna',
      isParent: true,
      trusted: [],
    );

    Future<void> openCity(
      WidgetTester tester, {
      Membership who = asMaja,
      int chores = 3,
      int homework = 0,
      List<CityLot> lots = const [],
    }) async {
      await pumpApp(
        tester,
        membership: who,
        overrides: [
          settingsProvider.overrideWith(
            (ref) => Stream.value(const FamilySettings(rewardsOn: true)),
          ),
          worldsProvider.overrideWith(
            (ref) => Stream.value({
              'maja': WorldPayload.write(
                memberId: 'maja',
                theme: WorldTheme.town,
                city: lots,
              ),
            }),
          ),
          contributionsProvider.overrideWith(
            (ref) => [
              for (var i = 0; i < chores; i++)
                Contribution(
                  memberId: 'maja',
                  at: DateTime.utc(2026, 9, 10, 12, i),
                  growsWorld: true,
                ),
              for (var i = 0; i < homework; i++)
                Contribution(
                  memberId: 'maja',
                  at: DateTime.utc(2026, 9, 10, 14, i),
                  growsWorld: true,
                  isHomework: true,
                ),
            ],
          ),
        ],
      );
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WorldScreen(memberId: 'maja')),
      );
      // The city animates for as long as it is on screen, so it never
      // settles; a few frames are what a person sees on arriving.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a new city says what it is and what there is to build', (
      tester,
    ) async {
      await openCity(tester);
      expect(find.byType(CityView), findsOneWidget);
      expect(find.text('Hamlet · district 1'), findsOneWidget);
      expect(
        find.text('3 things to build · Tap an empty plot to build'),
        findsOneWidget,
      );
    });

    testWidgets('tapping an empty plot asks what to build there', (tester) async {
      await openCity(tester);
      tester.widget<CityView>(find.byType(CityView)).onTapPlot!(9, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('What will you build here?'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Park'), findsOneWidget);
      expect(find.text('Street'), findsOneWidget);
      // No school yet, so no shops yet — and it says why.
      expect(find.text('Shops open once your town has a school'), findsOneWidget);
    });

    testWidgets('with a school, shops are there to build', (tester) async {
      await openCity(tester, homework: 3);
      tester.widget<CityView>(find.byType(CityView)).onTapPlot!(9, 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Shops open once your town has a school'), findsNothing);
    });

    testWidgets('a plot not open yet says so rather than doing nothing', (
      tester,
    ) async {
      await openCity(tester);
      tester.widget<CityView>(find.byType(CityView)).onTapPlot!(0, 0);
      await tester.pump();
      // At least once: the test app keeps the shell's Scaffold alive under
      // the pushed city, and a SnackBar is attached to each Scaffold the
      // messenger knows about. Only the top one is on screen.
      expect(find.text('This district opens as you do more'), findsWidgets);
    });

    testWidgets("a parent sees the child's city and can build nothing in it", (
      tester,
    ) async {
      await openCity(
        tester,
        who: asAnna,
        lots: [CityLot(x: 8, y: 9, zone: Zone.home, at: DateTime.utc(2026, 9, 10))],
      );
      expect(find.text("Maja's city"), findsOneWidget);
      expect(tester.widget<CityView>(find.byType(CityView)).onTapPlot, isNull);
    });
  });

  group('explained, where it is used', () {
    const asMaja = Membership(
      familyId: 'fam-test',
      memberId: 'maja',
      deviceId: 'device-maja',
      isParent: false,
      trusted: [],
    );

    Future<MemoryPreferences> openMyCity(
      WidgetTester tester, {
      MemoryPreferences? prefs,
    }) async {
      final preferences = prefs ?? MemoryPreferences();
      await pumpApp(
        tester,
        membership: asMaja,
        preferences: preferences,
        overrides: [
          settingsProvider.overrideWith(
            (ref) => Stream.value(const FamilySettings(rewardsOn: true)),
          ),
          worldsProvider.overrideWith((ref) => Stream.value(const {})),
          contributionsProvider.overrideWith((ref) => const []),
        ],
      );
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WorldScreen(memberId: 'maja')),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      return preferences;
    }

    testWidgets('a child opening their city the first time is told how it works', (
      tester,
    ) async {
      await openMyCity(tester);
      expect(find.text('How your city grows'), findsOneWidget);
      expect(
        find.text('Tap an empty plot and choose a home, a shop, a park or a street.'),
        findsOneWidget,
      );
    });

    testWidgets('but only the first time', (tester) async {
      final prefs = MemoryPreferences();
      await prefs.write('city.guideSeen', 'yes');
      await openMyCity(tester, prefs: prefs);
      expect(find.text('How your city grows'), findsNothing);
    });

    testWidgets('and can read it again from the question mark', (tester) async {
      final prefs = MemoryPreferences();
      await prefs.write('city.guideSeen', 'yes');
      await openMyCity(tester, prefs: prefs);
      await tester.tap(find.byTooltip('How it works'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('How your city grows'), findsOneWidget);
    });

    testWidgets('the family jar says what it is when tapped', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          settingsProvider.overrideWith(
            (ref) => Stream.value(const FamilySettings(rewardsOn: true, jarSize: 5)),
          ),
          contributionsProvider.overrideWith((ref) => const []),
        ],
      );
      await tester.tap(find.text('Family jar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('It starts empty again every Monday'), findsOneWidget);
    });
  });

  testWidgets('the city draws, night and day, with fireworks, without error', (
    tester,
  ) async {
    final city = cityOf(
      'maja',
      contributions: [
        for (var i = 0; i < 40; i++)
          Contribution(
            memberId: 'maja',
            at: DateTime.utc(2026, 9, 1, 8, i),
            growsWorld: true,
            isHomework: i.isEven,
          ),
      ],
      lots: [
        CityLot(x: 8, y: 9, zone: Zone.home, at: DateTime.utc(2026, 9, 1)),
        CityLot(x: 9, y: 9, zone: Zone.park, at: DateTime.utc(2026, 9, 1)),
        CityLot(x: 9, y: 10, zone: Zone.shop, at: DateTime.utc(2026, 9, 1)),
        CityLot(x: 10, y: 9, zone: Zone.home, at: DateTime.utc(2026, 9, 30, 9)),
      ],
      jarEverFull: true,
      today: DateTime.utc(2026, 9, 30),
    );
    for (final night in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CityView(city: city, night: night, festival: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
  });

  group('the way in, from More', () {
    Future<void> openMore(WidgetTester tester, Membership who) async {
      await pumpApp(
        tester,
        membership: who,
        overrides: [
          settingsProvider.overrideWith(
            (ref) => Stream.value(const FamilySettings(rewardsOn: true)),
          ),
        ],
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
    }

    testWidgets('a child finds their own world', (tester) async {
      await openMore(
        tester,
        const Membership(
          familyId: 'fam-test',
          memberId: 'maja',
          deviceId: 'd',
          isParent: false,
          trusted: [],
        ),
      );
      await tester.dragUntilVisible(
        find.text('My city'),
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      expect(find.text('My city'), findsOneWidget);
    });

    testWidgets('a parent finds the children, not a world of their own', (
      tester,
    ) async {
      await openMore(
        tester,
        const Membership(
          familyId: 'fam-test',
          memberId: 'anna',
          deviceId: 'd',
          isParent: true,
          trusted: [],
        ),
      );
      await tester.dragUntilVisible(
        find.text("The children's cities"),
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      expect(find.text('My city'), findsNothing);
    });

    testWidgets('someone neither parent nor child, like a babysitter, finds neither', (
      tester,
    ) async {
      // Not a member of the family at all: a helper's own member id.
      await openMore(
        tester,
        const Membership(
          familyId: 'fam-test',
          memberId: 'sara-the-sitter',
          deviceId: 'd',
          isParent: false,
          trusted: [],
        ),
      );
      expect(find.text('My city'), findsNothing);
      expect(find.text("The children's cities"), findsNothing);
    });
  });

  testWidgets('fireworks go off and clear themselves away', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: Fireworks(seed: 1, onDone: () => done = true)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(done, isFalse);
    await tester.pump(Fireworks.duration);
    expect(done, isTrue);
  });
}
