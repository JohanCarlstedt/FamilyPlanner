import 'package:family/src/features/people/celebrations_screen.dart';
import 'package:family/src/features/people/wishlists_screen.dart';
import 'package:family_data/family_data.dart';
import 'package:family/src/membership/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/pump_app.dart';

/// A gift list belongs to a person, not to a member.
///
/// The first version of this screen handed the member's id straight to
/// the list, which found no such person — so the app could not tell whose
/// list it was, and a list with no known owner is treated as someone
/// else's. It showed the owner what the family had quietly claimed for
/// them, which is the one thing the feature exists to hide.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  const asAnna = Membership(
    familyId: 'fam-test',
    memberId: 'anna',
    deviceId: 'device-test',
    isParent: true,
    trusted: [],
  );

  testWidgets('opening your own list opens it as yours', (tester) async {
    await pumpApp(
      tester,
      membership: asAnna,
      // Widget tests have no store to write to, so Anna's person record
      // is already there. What is under test is that the screen finds it
      // and hands the list a person id, not a member id.
      overrides: [
        peopleProvider.overrideWith(
          (ref) => Stream.value([
            (
              'person-anna',
              PersonPayload.write(name: 'Anna', memberId: 'anna'),
            ),
          ]),
        ),
      ],
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Gift lists'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.tap(find.text('Gift lists'));
    await tester.pumpAndSettle();

    expect(find.byType(WishlistsScreen), findsOneWidget);
    // Anna's own row says so; everyone else's does not.
    expect(find.text('Anna · yours'), findsOneWidget);
    expect(find.text('Erik'), findsOneWidget);

    await tester.tap(find.text('Anna · yours'));
    await tester.pumpAndSettle();

    // The list knows whose it is. Before the fix the person was never
    // found, so this read "'s wishes" — and the claims of everyone in
    // the family were on the screen underneath it.
    expect(find.text("Anna's wishes"), findsOneWidget);
  });
}
