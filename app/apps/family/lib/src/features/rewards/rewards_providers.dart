import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/clock.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../actions/actions_providers.dart';
import '../events/occurrence_editing.dart' show instantOf, wallClock;
import '../homework/homework_screen.dart' show homeworkProvider;

/// Whether the family has turned rewards on (spec section 3,
/// "Contributions"). Everything in this folder hides behind it.
final rewardsOnProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).value?.rewardsOn ?? false,
);

/// Everything finished, as the rewards count it — counted afresh from the
/// chores and homework already on this phone, never stored.
final contributionsProvider = Provider<List<Contribution>>(
  (ref) => FamilyStore.contributionsFrom(
    actions: ref.watch(actionsProvider).value ?? const [],
    homework: ref.watch(homeworkProvider).value ?? const [],
  ),
);

/// This week's family jar, Monday to Monday in the family's own zone.
final jarProvider = Provider<JarProgress?>((ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.rewardsOn) return null;
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  final local = wallClock(now, familyTimeZone);
  final monday = DateTime.utc(local.year, local.month, local.day - (local.weekday - 1));
  return familyJar(
    ref.watch(contributionsProvider),
    from: instantOf(monday, familyTimeZone),
    until: instantOf(
      DateTime.utc(monday.year, monday.month, monday.day + 7),
      familyTimeZone,
    ),
    size: settings.jarSize,
  );
});

/// Every child's world as stored: theme and placements.
final worldsProvider = StreamProvider<Map<String, WorldPayload>>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchWorlds().map(
    (rows) => {for (final (_, w) in rows) w.memberId: w},
  );
});

/// How far [memberId]'s world has come, counted from what they did.
final worldProgressProvider = Provider.family<WorldProgress, String>(
  (ref, memberId) => worldOf(memberId, ref.watch(contributionsProvider)),
);

/// The family's wall-clock date for an instant, as `DateTime.utc` fields
/// (invariant 4).
DateTime familyDay(DateTime instant) {
  final l = wallClock(instant, familyTimeZone);
  return DateTime.utc(l.year, l.month, l.day);
}

/// Whether the family's jar has been full in any week so far: what puts
/// the fountain in every child's square. Counted against the jar's size
/// as it is now, since that is the goal the family has chosen.
final jarEverFullProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.rewardsOn) return false;
  final weeks = <DateTime, int>{};
  for (final c in ref.watch(contributionsProvider)) {
    final day = familyDay(c.at);
    final monday = DateTime.utc(day.year, day.month, day.day - (day.weekday - 1));
    weeks[monday] = (weeks[monday] ?? 0) + 1;
  }
  return weeks.values.any((n) => n >= settings.jarSize);
});

/// [memberId]'s city as it stands now: what they built, grown by what
/// they have done since.
final cityProvider = Provider.family<City, String>((ref, memberId) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  return cityOf(
    memberId,
    contributions: ref.watch(contributionsProvider),
    lots: ref.watch(worldsProvider).value?[memberId]?.city ?? const [],
    jarEverFull: ref.watch(jarEverFullProvider),
    today: familyDay(now),
    dayOf: familyDay,
  );
});

/// Evening and night by the family's clock: the city's windows light up.
final cityNightProvider = Provider<bool>((ref) {
  final now = ref.watch(nowProvider).value ?? DateTime.now().toUtc();
  final hour = wallClock(now, familyTimeZone).hour;
  return hour >= 20 || hour < 6;
});
