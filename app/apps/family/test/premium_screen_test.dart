import 'package:domain/domain.dart';
import 'package:family/src/billing/entitlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// The paywall, in the states a person actually meets it in.
///
/// Two of these are the reason it exists at all: a family that has been
/// given premium must never be asked to buy it, and a build with no store
/// key must say so plainly rather than showing an empty page with a dead
/// button.
void main() {
  Future<void> openPremium(WidgetTester tester, Entitlement entitlement) async {
    await pumpApp(
      tester,
      overrides: [
        entitlementProvider.overrideWith(() => _Fixed(entitlement)),
      ],
    );
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Premium'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();
  }

  /// A ListView builds only what is on screen, and the terms the stores
  /// insist on sit below the fold on a phone. Scrolling to the end is what
  /// a person does too.
  Future<void> toTheBottom(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a family without premium is told what it would get', (
    tester,
  ) async {
    await openPremium(tester, Entitlement(until: null, checkedAt: DateTime.now().toUtc()));

    expect(find.text('Let the app do the running around'), findsOneWidget);
    // The free tier is stated on the same screen as the price. Someone
    // deciding whether to pay should not have to find out elsewhere what
    // they already have.
    expect(find.textContaining('stay free'), findsOneWidget);

    await toTheBottom(tester);
    // Both stores require the renewal terms and a way to restore.
    expect(find.textContaining('renews by itself'), findsOneWidget);
    expect(find.text('Restore a purchase'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
  });

  testWidgets('a build with no store key says so instead of offering nothing', (
    tester,
  ) async {
    // Which is every build until the store products exist — including the
    // one this family is running right now.
    await openPremium(tester, Entitlement(until: null, checkedAt: DateTime.now().toUtc()));
    await toTheBottom(tester);

    expect(find.textContaining("isn't available in this version"), findsOneWidget);
  });

  testWidgets('a family that already has premium is not sold it again', (
    tester,
  ) async {
    await openPremium(
      tester,
      Entitlement(
        until: DateTime.now().toUtc().add(const Duration(days: 20)),
        checkedAt: DateTime.now().toUtc(),
        source: EntitlementSource.appStore,
      ),
    );

    expect(find.text('Premium is on'), findsOneWidget);
    expect(find.text('Let the app do the running around'), findsNothing);
    await toTheBottom(tester);
    expect(find.text('Manage subscription'), findsOneWidget);
    // No price, no renewal terms: there is nothing on sale here.
    expect(find.textContaining('renews by itself'), findsNothing);
  });

  testWidgets('a family that was given premium is told nobody is paying', (
    tester,
  ) async {
    // The households who were here before there was a price. Showing them a
    // renewal date, or an invitation to buy, would both be lies.
    await openPremium(
      tester,
      Entitlement(
        until: DateTime.utc(9999, 12, 31),
        checkedAt: DateTime.now().toUtc(),
        source: EntitlementSource.granted,
      ),
    );

    expect(find.text('Premium is on'), findsOneWidget);
    expect(find.textContaining('Given rather than bought'), findsOneWidget);
    expect(find.textContaining('9999'), findsNothing);
  });
}

class _Fixed extends EntitlementController {
  _Fixed(this._entitlement);

  final Entitlement _entitlement;

  @override
  Future<Entitlement> build() async => _entitlement;

  @override
  Future<void> refresh() async {}
}
