import 'package:family/src/common/l10n.dart';
import 'package:family/src/features/events/new_event_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long something runs, said the way a person would.
///
/// The length picker was a dropdown that stopped at two hours, so a
/// weekend away could not be entered at all. It now asks when something
/// ends, which means a length can be any number of minutes — and a number
/// of minutes has to be readable when it is a number of days.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('minutes, then hours, then days', () {
    expect(describeLength(l10n, 30), '30 min');
    expect(describeLength(l10n, 60), '1 h');
    expect(describeLength(l10n, 90), '1 h 30 min');
    expect(describeLength(l10n, 5 * 60), '5 h');
  });

  test('a day and more reads as days, not hundreds of minutes', () {
    expect(describeLength(l10n, 24 * 60), '1 day');
    expect(describeLength(l10n, 48 * 60), '2 days');
    // A long weekend: Friday evening to Sunday afternoon.
    expect(describeLength(l10n, 2 * 24 * 60 + 5 * 60), '2 days 5 h');
  });

  test('the shortest thing worth entering still reads', () {
    expect(describeLength(l10n, 5), '5 min');
  });
}
