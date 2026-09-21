import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_providers.dart';
import '../features/homework/week_letter.dart';

/// The school's week plan, kept up to date the way a calendar feed is.
///
/// Set up once against a child — the document's address and which class
/// row is theirs — and their homework arrives on its own. Fetched by a
/// phone, never by the server, which is the same rule every import here
/// follows: the school's address stays inside the family.
///
/// It only ever adds. Homework already there may be half done or have
/// sessions booked against it, and a school republishing its document with
/// a correction is not a reason to undo that. Ids come from the plan, the
/// class and the day, so a republished week lands on the same objects
/// rather than a second copy.
class WeekPlans {
  const WeekPlans();

  /// School plans change on Sunday evening and stay put all week; this is
  /// often enough to catch a correction and rare enough to be invisible.
  static const every = Duration(hours: 6);

  /// Fetches the plans that are due, and returns how much homework is new.
  ///
  /// A plan that fails is left for next time: a school's site being down,
  /// or a laptop on a train, is not a reason to tell anyone anything.
  Future<int> refresh(
    FamilyStore store,
    DevicePreferences prefs, {
    required String timeZone,
    bool force = false,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now().toUtc();
    var added = 0;

    for (final (id, link) in await store.watchWeekPlanLinks().first) {
      final group = link.group;
      if (group == null) continue; // Nobody has said which class yet.
      if (!force && !await _due(prefs, id, at)) continue;

      final bytes = await WeekLetter.fetch(link.url);
      if (bytes == null) {
        debugPrint('Week plan ${link.url} could not be fetched');
        continue;
      }
      final tables = WeekLetter.tablesIn(bytes);
      if (tables.isEmpty) continue;

      final entries = <WeekPlanEntry>[];
      for (final table in tables) {
        entries.addAll(
          readWeekPlan(
            table,
            timeZone: timeZone,
            now: at,
          ).where((e) => e.group == group),
        );
      }
      // A document holds the whole term; only the weeks anyone can still
      // act on are worth writing.
      final soon = [
        for (final e in entries)
          if (e.dueAt == null ||
              (e.dueAt!.isAfter(at.subtract(const Duration(days: 2))) &&
                  e.dueAt!.isBefore(at.add(const Duration(days: 21)))))
            e,
      ];

      added += await store.importWeekPlan(
        linkId: id,
        memberId: link.memberId,
        entries: soon,
      );
      await prefs.write(_key(id), at.toIso8601String());
    }
    return added;
  }

  static String _key(String linkId) => 'weekplan.fetched.$linkId';

  Future<bool> _due(DevicePreferences prefs, String id, DateTime at) async {
    final last = DateTime.tryParse(await prefs.read(_key(id)) ?? '');
    return last == null || at.difference(last) >= every;
  }
}

final weekPlansProvider = Provider<WeekPlans>((ref) => const WeekPlans());
