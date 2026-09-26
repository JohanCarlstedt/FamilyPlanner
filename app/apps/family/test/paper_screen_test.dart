import 'package:domain/domain.dart';
import 'package:family/l10n/generated/app_localizations.dart';
import 'package:family/src/features/rewards/paper_screen.dart';
import 'package:family/src/features/rewards/rewards_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The town paper: last week's news, laid out, with the biggest as the
/// headline.
void main() {
  final week = DateTime.utc(2026, 10, 5);

  Future<void> show(WidgetTester tester, TownPaper paper) => tester.pumpWidget(
    ProviderScope(
      overrides: [townPaperProvider('maja').overrideWithValue(paper)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaperScreen(memberId: 'maja'),
      ),
    ),
  );

  testWidgets('a busy week: the new level first, and everything in it', (
    tester,
  ) async {
    await show(
      tester,
      TownPaper(
        week: week,
        thingsDone: 9,
        homework: 3,
        built: const {Zone.home: 2, Zone.park: 1},
        grown: const {UpgradePath.farm: 1},
        opened: const {Civic.school},
        levelBefore: 2,
        level: 3,
        residentsBefore: 20,
        residents: 31,
        happenings: const [Happening.gameDay],
        troubles: [
          Trouble(
            kind: TroubleKind.fire,
            day: week,
            x: 7,
            y: 8,
            endedAt: week.add(const Duration(hours: 16)),
            handled: true,
          ),
        ],
        requestsGranted: 1,
      ),
    );
    expect(find.text('The town has grown into a small town!'), findsOneWidget);
    expect(find.text('Week 41'), findsOneWidget);
    expect(find.text('9 things done'), findsOneWidget);
    expect(find.text('31 people live in town (11 new)'), findsOneWidget);
    expect(find.text('🏠 × 2'), findsOneWidget);
    expect(find.textContaining('you did it yourself!'), findsOneWidget);
    expect(find.text('Game day!'), findsOneWidget);
  });

  testWidgets('a quiet week says so, kindly', (tester) async {
    await show(
      tester,
      TownPaper(
        week: week,
        thingsDone: 0,
        homework: 0,
        built: const {},
        grown: const {},
        opened: const {},
        levelBefore: 2,
        level: 2,
        residentsBefore: 20,
        residents: 20,
        happenings: const [],
        troubles: const [],
        requestsGranted: 0,
      ),
    );
    expect(find.text('A quiet week in town'), findsOneWidget);
    expect(
      find.text('Nothing was built this week. The town is waiting for you!'),
      findsOneWidget,
    );
  });
}
