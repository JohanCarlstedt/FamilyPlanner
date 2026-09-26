import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import 'rewards_providers.dart';
import 'world_screen.dart';

/// Tapped the station: take the train to a brother's or sister's town.
/// One town at a time, never side by side.
Future<void> showStationSheet(BuildContext context, {required String me}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _StationSheet(me: me),
    );

class _StationSheet extends ConsumerWidget {
  const _StationSheet({required this.me});

  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final worlds = ref.watch(worldsProvider).value ?? const {};
    final others = [
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        if (m.isChild && m.id != me && worlds.containsKey(m.id)) m,
    ];
    final stations = ref.watch(stationsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('🚉 ${l10n.stationVisit}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.stationVisitBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (others.isEmpty)
              Text(l10n.stationNoOne, style: theme.textTheme.bodyMedium),
            for (final m in others)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  leading: Text(
                    stations.contains(m.id) ? '🚆' : '🚌',
                    style: const TextStyle(fontSize: 26),
                  ),
                  title: Text(l10n.stationTo(m.displayName)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorldScreen(memberId: m.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
