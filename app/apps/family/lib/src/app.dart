import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'common/l10n.dart';
import 'routing/router.dart';

class FamilyApp extends ConsumerWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // The product's name, the same in every language.
      title: 'Family Planner',
      // The debug ribbon never appears in a release build, but it does in
      // widget tests, and the store screenshots are taken from those
      // (tool/make_screenshots.dart).
      debugShowCheckedModeBanner: false,
      // Placeholder theme until ui_kit carries the design tokens.
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: appLocales,
      localeResolutionCallback: resolveAppLocale,
      builder: (context, child) {
        // Dates follow the app's language: DateFormat without a locale reads
        // this.
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return child!;
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
