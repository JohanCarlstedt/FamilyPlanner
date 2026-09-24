/// How often the app may act on a position the phone delivers in the
/// background.
///
/// Each report wakes the radio twice (catch up, then send), and a phone
/// in a car or on a bus crosses the distance filter every few seconds.
/// Android can be told a slowest rate and keeps to it; iOS cannot, so
/// the app keeps to it itself. A wake inside the gap is let go: the next
/// one carries a newer position anyway.
class ReportPacer {
  ReportPacer({this.gap = const Duration(minutes: 1)});

  final Duration gap;
  DateTime? _last;

  /// Whether a report may go now; if so, it counts as sent.
  bool take(DateTime now) {
    final last = _last;
    if (last != null && now.difference(last) < gap) return false;
    _last = now;
    return true;
  }
}
