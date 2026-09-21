import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'src/api/server_address.dart';
import 'src/app.dart';
import 'src/common/startup.dart';
import 'src/reminders/push.dart';

Future<void> main() async {
  startupClock.start();
  WidgetsFlutterBinding.ensureInitialized();
  // Times are computed in the family's IANA zone, not the device's.
  tzdata.initializeTimeZones();
  // Loads the Rust crypto core; everything cryptographic goes through it.
  await RustLib.init();
  await initPush();
  // Which server this install belongs to, read before anything can ask:
  // the API client is synchronous, and a request to the wrong host would
  // be refused by one that has never heard of this device.
  final pinned = await ServerAddressStore(PlatformSecretStore()).load();
  startupMilestone('server');
  runApp(
    ProviderScope(
      overrides: [pinnedServerProvider.overrideWithValue(pinned)],
      child: const FamilyApp(),
    ),
  );
}
