import 'package:domain/domain.dart';
import 'package:family/l10n/generated/app_localizations.dart';
import 'package:family/src/data/store_providers.dart';
import 'package:family/src/features/passwords/passwords_screen.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The password list as a vault: search, favourites, kinds, and the
/// security check's warning.
void main() {
  (String, CredentialPayload) item(
    String id,
    String title,
    String secret, {
    VaultItemType type = VaultItemType.login,
    String? username,
    String? folder,
    bool favourite = false,
    Map<String, String?> fields = const {},
  }) => (
    id,
    CredentialPayload.write(
      title: title,
      secret: secret,
      username: username,
      scope: const PasswordFor.family(),
      type: type,
      folder: folder,
      favourite: favourite,
      fields: fields,
    ),
  );

  Future<void> show(WidgetTester tester, {bool parent = true}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          credentialsProvider.overrideWith(
            (ref) => Stream.value([
              item('n', 'Netflix', 'kT7#mq9!Lp2x',
                  username: 'anna@example.com',
                  favourite: true,
                  folder: 'Streaming'),
              item('s', 'Spotify', 'kT7#mq9!Lp2x', folder: 'Streaming'),
              item('w', 'Home Wi-Fi', 'password',
                  type: VaultItemType.wifi, fields: {'ssid': 'Svensson'}),
              item('c', 'Visa', '4111 1111 1111 1234',
                  type: VaultItemType.card),
            ]),
          ),
          devicePreferencesProvider.overrideWith(
            (ref) async => MemoryPreferences(),
          ),
          membershipProvider.overrideWith(() => _Fixed(parent: parent)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PasswordsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('favourites first, every kind told apart, nothing secret shown',
      (tester) async {
    await show(tester);
    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Card ending 1234'), findsOneWidget);
    expect(find.textContaining('Svensson'), findsOneWidget);
    expect(find.textContaining('kT7#'), findsNothing);
    expect(find.textContaining('4111'), findsNothing);
  });

  testWidgets('search finds by name, folder and username, not by secret',
      (tester) async {
    await show(tester);
    await tester.enterText(find.byType(SearchBar), 'stream');
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsWidgets);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Visa'), findsNothing);
    await tester.enterText(find.byType(SearchBar), 'kT7');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches.'), findsOneWidget);
  });

  testWidgets('a kind on its own', (tester) async {
    await show(tester);
    final chip = find.widgetWithText(ChoiceChip, 'Payment card');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Visa'), findsOneWidget);
    expect(find.text('Spotify'), findsNothing);
  });

  testWidgets('the security check counts what it found', (tester) async {
    await show(tester);
    // Netflix and Spotify share one password; the Wi-Fi's is weak.
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a parent saves for the family, the parents, the children or '
      'themselves', (tester) async {
    await show(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    for (final label in ["The family's", "The parents'", "The children's", 'Mine']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget,
          reason: label);
    }
  });

  testWidgets('a child is not offered the parents\' own', (tester) async {
    await show(tester, parent: false);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, "The parents'"), findsNothing);
    expect(find.widgetWithText(ChoiceChip, "The children's"), findsOneWidget);
  });
}

class _Fixed extends MembershipController {
  _Fixed({this.parent = true});
  final bool parent;

  @override
  Future<Membership?> build() async => Membership(
    familyId: 'f',
    memberId: 'anna',
    deviceId: 'd',
    isParent: parent,
    trusted: const [],
  );
}
