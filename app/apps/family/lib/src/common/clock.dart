import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current UTC instant, refreshed every minute so "now" markers and
/// "next up" move on their own. Tests override it with a fixed instant.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now().toUtc(),
  );
});
