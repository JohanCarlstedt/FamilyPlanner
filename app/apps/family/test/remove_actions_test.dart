import 'package:domain/domain.dart';
import 'package:family/l10n/generated/app_localizations.dart';
import 'package:family/src/data/family_repository.dart';
import 'package:family/src/features/actions/actions_providers.dart';
import 'package:family/src/features/actions/actions_screen.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family/src/membership/permissions_provider.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Removing tasks: hold one to pick several, remove them together, after
/// saying what that means. Only what this member may remove can be picked.
void main() {
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const maja = Member(
    id: 'maja',
    displayName: 'Maja',
    role: MemberRole.child,
    tier: MaturityTier.kid,
  );

  // Everyone's, so each shows on whoever's list is open.
  (String, ActionPayload) task(
    String id,
    String title, {
    String? by,
    required String to,
  }) {
    final written = ActionPayload.write(
      title: title,
      kind: ActionKind.chore,
      assignedTo: to,
    );
    written.payload.setText('createdBy', by ?? 'anna');
    return (id, ActionPayload.read(written.payload));
  }

  Future<void> show(WidgetTester tester, Member me) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        actionsProvider.overrideWith(
          (ref) => Stream.value([
            task('a1', 'Buy milk', to: me.id),
            task('a2', 'Hoover', to: me.id),
            task('a3', 'Feed the cat', by: 'maja', to: me.id),
          ]),
        ),
        membersProvider.overrideWith((ref) => Stream.value([anna, maja])),
        membershipProvider.overrideWith(
          () => _Fixed(
            Membership(
              familyId: 'f',
              memberId: me.id,
              deviceId: 'd',
              isParent: me.role == MemberRole.parent,
              trusted: const [],
            ),
          ),
        ),
        permissionsProvider.overrideWithValue(Permissions(me)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActionsScreen(),
      ),
    ),
  );

  testWidgets('hold one, pick another, and remove both after asking', (
    tester,
  ) async {
    await show(tester, anna);
    await tester.pumpAndSettle();
    expect(find.text('Hold a task to pick several'), findsOneWidget);

    await tester.longPress(find.text('Buy milk'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));

    await tester.tap(find.text('Hoover'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove 2 tasks?'), findsOneWidget);
    expect(find.text('They disappear for the whole family.'), findsOneWidget);

    // Changing their mind leaves both picked.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // And the cross stops picking.
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('a child can pick only a task they made', (tester) async {
    await show(tester, maja);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Feed the cat'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    // A chore a parent gave: it cannot be picked, its box stays empty.
    await tester.tap(find.text('Buy milk'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes.where((b) => b.onChanged == null), hasLength(2));
  });
}

class _Fixed extends MembershipController {
  _Fixed(this._membership);
  final Membership _membership;

  @override
  Future<Membership?> build() async => _membership;
}
