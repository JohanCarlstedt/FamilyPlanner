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
