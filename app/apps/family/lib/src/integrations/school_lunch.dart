import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/family_repository.dart';
import '../data/store_providers.dart';

/// A school's lunches this week, by day, from Skolmaten: fetched by the
/// phone like the weather, so Skolmaten learns only which school, and our
/// server nothing. Kept for six hours; a menu changes seldom, and a
/// school with nothing on it is asked about again later, not on every
/// repaint of Today.
final schoolLunchProvider =
    FutureProvider.family<Map<DateTime, List<String>>, String>((
      ref,
      school,
    ) async {
      final prefs = await ref.watch(devicePreferencesProvider.future);
      final key = 'lunch.$school';
      final now = DateTime.now().toUtc();
      final cached = await prefs.read(key);
      if (cached != null) {
        try {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          final at = DateTime.parse(data['at'] as String);
          if (now.difference(at) < const Duration(hours: 6)) {
            return _days(data['days'] as Map<String, dynamic>);
          }
        } on Object {
          // Unreadable: fetched again below.
        }
      }
      try {
        final response = await http
            .get(
              schoolLunchFeed(school),
              headers: {'User-Agent': 'FamilyPlanner/1.0'},
            )
            .timeout(const Duration(seconds: 15));
        final week = response.statusCode == 200
            ? parseSchoolLunch(utf8.decode(response.bodyBytes))
            : <DateTime, List<String>>{};
        await prefs.write(
          key,
          jsonEncode({
            'at': now.toIso8601String(),
            'days': {
              for (final MapEntry(key: day, value: dishes) in week.entries)
                day.toIso8601String(): dishes,
            },
          }),
        );
        return week;
      } on Object catch (e) {
        debugPrint('School lunch for $school not fetched: $e');
        return const {};
      }
    });

Map<DateTime, List<String>> _days(Map<String, dynamic> raw) => {
  for (final MapEntry(key: day, value: dishes) in raw.entries)
    DateTime.parse(day): (dishes as List<dynamic>).cast<String>(),
};

/// Each child's lunch on [day] (date fields), by member: only children
/// whose school is set and that has a menu that day.
final lunchOnProvider =
    FutureProvider.family<Map<String, List<String>>, DateTime>((
      ref,
      day,
    ) async {
      final schools =
          ref.watch(settingsProvider).value?.lunchSchools ?? const {};
      final out = <String, List<String>>{};
      for (final MapEntry(key: who, value: school) in schools.entries) {
        final week = await ref.watch(schoolLunchProvider(school).future);
        if (week[day] case final dishes? when dishes.isNotEmpty) {
          out[who] = dishes;
        }
      }
      return out;
    });
