import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/router.dart';

class FamilyApp extends ConsumerWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Family',
      // Placeholder theme until ui_kit carries the design tokens.
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
