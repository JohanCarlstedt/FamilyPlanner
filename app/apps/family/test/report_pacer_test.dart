import 'package:family/src/location/report_pacer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Background reports are held to one a minute, however often the phone
/// wakes the app for movement.
void main() {
  test('the first report goes, then one a minute', () {
    final pacer = ReportPacer();
    final t0 = DateTime.utc(2026, 9, 24, 8);
    expect(pacer.take(t0), isTrue);
    for (final s in [5, 20, 59]) {
      expect(pacer.take(t0.add(Duration(seconds: s))), isFalse);
    }
    expect(pacer.take(t0.add(const Duration(seconds: 60))), isTrue);
    expect(pacer.take(t0.add(const Duration(seconds: 70))), isFalse);
  });

  test('a phone standing still is not held back when it moves again', () {
    final pacer = ReportPacer();
    final t0 = DateTime.utc(2026, 9, 24, 8);
    pacer.take(t0);
    expect(pacer.take(t0.add(const Duration(hours: 2))), isTrue);
  });
}
