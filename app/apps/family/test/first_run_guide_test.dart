import 'package:family/src/data/store_providers.dart';
import 'package:family/src/features/onboarding/first_run_guide.dart';
import 'package:family/src/membership/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// The guide exists because joining a family used to explain nothing. One
/// person creates the household and gets a setup flow; everyone else —
/// the other parent, three children, anyone a stranger invites — arrived
/// on Today with no idea what any of it was.
void main() {
  testWidgets('a device that has just joined is shown the guide', (
    tester,
  ) async {
    await pumpApp(tester, firstRun: true);

    expect(find.text("Everyone's week, in one place"), findsOneWidget);
    // Not the app itself, yet.
    expect(find.text('More'), findsNothing);
  });

  testWidgets('it can be clicked through to the end', (tester) async {
    await pumpApp(tester, firstRun: true);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Ask, decide, get it done'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Only your family can read it'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // A parent's last card is the recovery words, because a parent is who
    // holds the way back in when every phone is lost at once.
    expect(find.text('Twelve words, kept somewhere safe'), findsOneWidget);
    expect(find.text('Get my twelve words'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('skipping it leaves the app usable', (tester) async {
    await pumpApp(tester, firstRun: true);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text("Everyone's week, in one place"), findsNothing);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('a device that has seen it is not shown it again', (
    tester,
  ) async {
    // What "shown once" has to mean: not once per launch.
    final prefs = MemoryPreferences()..values['guide.seen.v1'] = 'yes';

    await pumpApp(tester, preferences: prefs, firstRun: true);

    expect(find.text("Everyone's week, in one place"), findsNothing);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('a fresh install with no family still starts at welcome', (
    tester,
  ) async {
    // The guide is for someone who has joined. Before that, onboarding is
    // the only thing that makes sense.
    await pumpApp(tester, membership: null, firstRun: true);

    expect(find.text('Start a new family'), findsOneWidget);
    expect(find.text("Everyone's week, in one place"), findsNothing);
  });
}
