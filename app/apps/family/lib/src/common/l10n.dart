import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

export '../../l10n/generated/app_localizations.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Swedish for Swedish devices, British English for everything else (spec §5
/// "Swedish calendar realities"): Monday week starts and 24-hour time in the
/// platform's own pickers, whichever language is chosen.
const appLocales = [Locale('sv'), Locale('en', 'GB')];

Locale resolveAppLocale(Locale? device, Iterable<Locale> supported) =>
    device?.languageCode == 'sv'
    ? const Locale('sv')
    : const Locale('en', 'GB');
