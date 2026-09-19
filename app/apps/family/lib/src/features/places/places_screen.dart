import 'package:domain/domain.dart';

import '../../membership/permissions_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import 'place_editor.dart';

/// The family's places (spec §3 `place`): entered once, used by every event
/// held there.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  static const segment = 'places';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final places = ref.watch(placesProvider);
    final mayEdit = ref.watch(permissionsProvider).manageFamily;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.places)),
      floatingActionButton: mayEdit
          ? FloatingActionButton.extended(
              onPressed: () => editPlace(context, ref),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.newPlace),
            )
          : null,
      body: switch (places) {
        AsyncValue(value: final list?) when list.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.placesEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        AsyncValue(value: final list?) => ListView(
          children: [
            for (final Place p in list)
              ListTile(
                leading: Icon(
                  p.isHome ? Icons.home_outlined : Icons.place_outlined,
                ),
                title: Text(p.name),
                subtitle: p.address == null ? null : Text(p.address!),
                onTap: mayEdit ? () => editPlace(context, ref, place: p) : null,
              ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
