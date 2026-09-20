import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:family/src/data/store_providers.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../test/support/pump_app.dart';

/// The pictures Google Play's listing needs, taken of the real screens with
/// the invented household in lib/src/data/sample_family.dart.
///
///   flutter test --update-goldens tool/make_screenshots.dart
///
/// Not an emulator, on purpose: a store listing is public forever, and the
/// only family on a real phone here is a real one. Nobody's child's name,
/// school or position belongs in it.
void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
  });

  setUp(() async {
    // The share sheet's plugin has no implementation in a test, and the app
    // asks it two things on startup. Answering for it is quieter than
    // catching what it throws: nothing shared, no stream.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('receive_sharing_intent/messages'),
      (call) async => null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('receive_sharing_intent/events-media'),
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );

    // The test engine ships no fonts: without these, every word is a filled
    // rectangle and every icon an empty box. Both files come with the
    // Flutter SDK, which is what a real build would use anyway.
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final fonts = '$root/bin/cache/artifacts/material_fonts';
      await _load('$fonts/Roboto-Regular.ttf', ['Roboto', '.SF UI Text', '.SF UI Display']);
      await _load('$fonts/MaterialIcons-Regular.otf', ['MaterialIcons']);
    }
  });

  // A tall phone, which is the shape Play shows first.
  const phone = Size(390, 844);

  // Screens reached through a golden capture linger long enough for the
  // local databases to start opening, and the container is then torn down
  // mid-open — which the test framework reports as a failure after the test
  // has already passed. Nothing here needs real databases: the sample
  // family is the source of everything on screen.
  final overrides = [
    localDatabasesProvider.overrideWith((ref) => Completer<(CacheDatabase, QueueDatabase)>().future),
  ];

  testWidgets('today', (tester) async {
    await pumpApp(tester, size: phone, overrides: overrides);
    await _shoot(tester, '01-today');
  });

  testWidgets('the week', (tester) async {
    await pumpApp(tester, size: phone, overrides: overrides);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await _shoot(tester, '02-week');
  });

  testWidgets('shopping', (tester) async {
    await pumpApp(tester, size: phone, overrides: overrides);
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await _shoot(tester, '03-shopping');
  });

  testWidgets('an event, opened', (tester) async {
    await pumpApp(tester, size: phone, overrides: overrides);
    await tester.tap(find.text('Football training').first);
    await tester.pumpAndSettle();
    await _shoot(tester, '04-event');
  });
}

Future<void> _load(String path, List<String> families) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  for (final family in families) {
    await ui.loadFontFromList(bytes, fontFamily: family);
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {

  await expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('play/$name.png'),
  );
}
