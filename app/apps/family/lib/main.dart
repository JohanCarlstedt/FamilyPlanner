import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'src/app.dart';

void main() {
  // Times are computed in the family's IANA zone, not the device's.
  tzdata.initializeTimeZones();
  runApp(const ProviderScope(child: FamilyApp()));
}
