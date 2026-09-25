import 'package:family/src/common/l10n.dart';
import 'package:family/src/features/search/app_places.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Search finds the app's settings and screens, not only its content.
void main() {
  final sv = lookupAppLocalizations(const Locale('sv'));
  final en = lookupAppLocalizations(const Locale('en'));

  List<String> titles(AppLocalizations l10n, String q, {bool parent = true}) =>
      [for (final p in findPlaces(l10n, q, parent: parent)) p.title];

  test('a setting is found by its own name, inside Family settings', () {
    expect(titles(sv, 'tysta'), contains(sv.familySettings));
    expect(titles(sv, 'morgon'), contains(sv.familySettings));
    expect(titles(en, 'quiet'), contains(en.familySettings));
  });

  test('and by the everyday word for it', () {
    expect(titles(sv, 'elpris'), contains(sv.familySettings));
    expect(titles(sv, 'ström'), contains(sv.familySettings));
    expect(titles(en, 'electricity'), contains(en.familySettings));
    expect(
      titles(sv, 'google'),
      containsAll([sv.phoneCalendars, sv.linkedCalendars]),
    );
    expect(titles(sv, 'lösenord'), contains(sv.passwords));
  });

  test('screens by their names', () {
    expect(titles(sv, 'karta'), contains(sv.familyMap));
    expect(titles(en, 'recently'), contains(en.recentlyDeleted));
  });

  test('a child is not offered what only a parent can open', () {
    expect(titles(sv, 'elpris', parent: false), isEmpty);
    expect(titles(sv, 'google', parent: false), [sv.phoneCalendars]);
  });

  test('one letter finds nothing, so typing does not flood the list', () {
    expect(titles(sv, 'e'), isEmpty);
  });
}
