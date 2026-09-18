import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'sample_family.dart';

/// Read access to the family's decrypted content.
///
/// Stands in for the repositories of packages/data (architecture doc §4).
/// Async already, so screens handle loading the way they will once reads come
/// from Drift.
abstract interface class FamilyRepository {
  /// IANA zone the family lives in. Recurrence and day boundaries use it.
  String get timeZone;

  Future<List<Member>> members();

  Future<List<CalendarEvent>> events();
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  // Seeded around today's date so the sample always has something to show.
  final zone = tz.getLocation(SampleFamily.zone);
  final today = tz.TZDateTime.now(zone);
  return SampleFamily(today: DateTime(today.year, today.month, today.day));
});
