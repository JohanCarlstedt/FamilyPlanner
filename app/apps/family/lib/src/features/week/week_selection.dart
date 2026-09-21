import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which occurrences are picked out for removing together.
///
/// A set of keys rather than of entries: the week rebuilds constantly —
/// a sync, a new minute — and a held entry would go stale while the
/// person is still choosing. The key survives a rebuild, and what it
/// points at is looked up again when it is finally acted on.
///
/// One *occurrence*, not one event: picking next Tuesday's training out
/// of a weekly series must not mean picking the series.
final weekSelectionProvider =
    NotifierProvider<WeekSelection, Set<String>>(WeekSelection.new);

class WeekSelection extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  static String keyFor(AgendaEntry entry) =>
      '${entry.event.id}@'
      '${entry.occurrence.originalStart.toUtc().toIso8601String()}';

  bool has(AgendaEntry entry) => state.contains(keyFor(entry));

  bool get active => state.isNotEmpty;

  void toggle(AgendaEntry entry) {
    final key = keyFor(entry);
    state = state.contains(key)
        ? {...state}.where((k) => k != key).toSet()
        : {...state, key};
  }

  void clear() => state = const {};
}
