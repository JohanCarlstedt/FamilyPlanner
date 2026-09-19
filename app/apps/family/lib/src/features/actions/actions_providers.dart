import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/store_providers.dart';

final actionsProvider = StreamProvider<List<(String, ActionPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchActions();
});

final actionTemplatesProvider =
    StreamProvider<List<(String, ActionTemplatePayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchActionTemplates();
    });

/// Open actions for [member] due by the end of [today] (a UTC instant), or
/// already overdue.
List<(String, ActionPayload)> dueFor(
  List<(String, ActionPayload)> actions,
  String? member,
  DateTime endOfToday,
) => [
  for (final a in actions)
    if (a.$2.isOpen &&
        a.$2.assignedTo == member &&
        a.$2.dueAt != null &&
        a.$2.dueAt!.isBefore(endOfToday))
      a,
];
