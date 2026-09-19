import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../events/occurrence_editing.dart';

/// Events deleted in the last 30 days, restorable by anyone in the family
/// (spec §11: a deleted season should never be a support case).
class RecentlyDeletedScreen extends ConsumerWidget {
  const RecentlyDeletedScreen({super.key});

  static const segment = 'recently-deleted';

  Future<void> _restore(WidgetRef ref, String id) async {
    final store = await ref.read(familyStoreProvider.future);
    await store.restoreEvent(id);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deleted = ref.watch(deletedEventsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recentlyDeleted)),
      body: switch (deleted) {
        AsyncValue(value: final events?) when events.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.recentlyDeletedEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        AsyncValue(value: final events?) => ListView(
          children: [
            for (final (id, e) in events)
              ListTile(
                title: Text(e.title),
                subtitle: Text(
                  l10n.deletedOn(
                    DateFormat('d MMMM')
                        .format(wallClock(e.deletedAt!, e.timeZone)),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => _restore(ref, id),
                  child: Text(l10n.restore),
                ),
              ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
