import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Times are computed in the family's IANA zone, not the device's.
  tzdata.initializeTimeZones();
  // Loads the Rust crypto core; everything cryptographic goes through it.
  await RustLib.init();
  runApp(const ProviderScope(child: FamilyApp()));
}
