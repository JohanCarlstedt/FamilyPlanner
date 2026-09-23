import 'package:domain/domain.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:family/src/features/rewards/fireworks.dart';
import 'package:family/src/features/rewards/rewards_providers.dart';
import 'package:family/src/features/rewards/world_screen.dart';
import 'package:family/src/features/rewards/world_themes.dart';
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

  group('themes', () {
    final garden = WorldLook.all[WorldTheme.garden]!;

    test('the first seed always has something to become', () {
      expect(garden.unlocked(0), isNotEmpty);
    });

    test('more is offered as more is done', () {
      expect(garden.unlocked(20).length, greaterThan(garden.unlocked(0).length));
      final (next, count) = garden.next(0)!;
      expect(next.unlocksAt, greaterThan(0));
      expect(count, next.unlocksAt);
    });

    test('every theme has the same number of things, unlocked at the same points', () {
      // No theme is a better deal than another: a child picks what they
      // like the look of, not what gets them further.
      final shape = [for (final t in garden.things) t.unlocksAt];
      for (final look in WorldLook.all.values) {
        expect([for (final t in look.things) t.unlocksAt], shape, reason: '${look.theme}');
      }
    });

    test('a thing from another theme, or a newer version, is still drawn', () {
      expect(garden.symbolFor('rocket'), '🚀');
      expect(garden.symbolFor('never-heard-of-it'), isNotEmpty);
    });

    test('no key is used twice within a theme', () {
      for (final look in WorldLook.all.values) {
        final keys = [for (final t in look.things) t.key];
        expect(keys.toSet().length, keys.length, reason: '${look.theme}');
      }
    });
  });

  group("a child's world", () {
    const asMaja = Membership(
      familyId: 'fam-test',
      memberId: 'maja',
      deviceId: 'device-maja',
      isParent: false,
      trusted: [],
    );

    Future<void> openWorld(
      WidgetTester tester, {
      WorldPayload? world,
      int seeds = 3,
    }) async {
      await pumpApp(
        tester,
        membership: asMaja,
        overrides: [
          settingsProvider.overrideWith(
            (ref) => Stream.value(const FamilySettings(rewardsOn: true)),
          ),
          worldsProvider.overrideWith(
            (ref) => Stream.value({'maja': ?world}),
          ),
          contributionsProvider.overrideWith(
            (ref) => [
              for (var i = 0; i < seeds; i++)
                Contribution(
                  memberId: 'maja',
                  at: DateTime.utc(2026, 9, 10, 12, i),
                  growsWorld: true,
                ),
            ],
          ),
        ],
      );
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WorldScreen(memberId: 'maja')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the first time, the child chooses what their world is', (
      tester,
    ) async {
      await openWorld(tester);
      expect(find.text('Choose your world'), findsOneWidget);
      expect(find.text('Garden'), findsOneWidget);
      expect(find.text('Aquarium'), findsOneWidget);
      expect(find.text('Space'), findsOneWidget);
      expect(find.text('Town'), findsOneWidget);
    });

    testWidgets('seeds earned and not yet placed are waiting', (tester) async {
      await openWorld(
        tester,
        world: WorldPayload.write(
          memberId: 'maja',
          theme: WorldTheme.space,
          placements: [
            WorldPlacement(
              level: 1,
              spot: 0,
              thing: 'rocket',
              at: DateTime.utc(2026, 9, 10),
            ),
          ],
        ),
      );
      expect(find.text('Space · World 1'), findsOneWidget);
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('2 seeds to place'), findsOneWidget);
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
