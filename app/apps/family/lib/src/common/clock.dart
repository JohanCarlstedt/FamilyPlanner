import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current UTC instant, refreshed at each minute boundary so "now"
/// markers and "next up" change when the clock does, not up to a minute
/// later. Tests override it with a fixed instant.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  while (true) {
    final now = DateTime.now().toUtc();
    yield now;
    // Sleep to the next minute boundary rather than a fixed 60 s, which
    // would drift by however far into the minute the app started.
    await Future<void>.delayed(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
    );
  }
});
