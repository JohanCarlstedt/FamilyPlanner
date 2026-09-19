import 'package:flutter/foundation.dart';

/// Time since the app started, for measuring start-up where it matters: on
/// a profile or release build (CLAUDE.md).
final startupClock = Stopwatch();

final _reported = <String>{};

/// Logs, once per [milestone], how long after start it was reached.
void startupMilestone(String milestone) {
  if (!_reported.add(milestone)) return;
  debugPrint(
    'startup: $milestone after ${startupClock.elapsedMilliseconds} ms',
  );
}
