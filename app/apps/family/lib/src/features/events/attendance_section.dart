import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../actions/actions_providers.dart';
import '../rewards/rewards_providers.dart';

/// Who went to one occurrence of an activity, once it has started: a
/// child ticks "I went", a parent ticks whoever went. Going counts like a
/// chore, as being active (spec section 3, "Contributions").
///
/// Only when the family has rewards on, and only for two weeks after: long
/// enough to remember to tick it, short enough not to be a list of
/// everything ever missed.
class AttendanceSection extends ConsumerWidget {
  const AttendanceSection({
    super.key,
    required this.eventId,
    required this.title,
    required this.occurrence,
    required this.participantIds,
  });

  final String eventId;
  final String title;
  final DateTime occurrence;

  /// Who it is for; empty for the whole family.
  final List<String> participantIds;

  static const window = Duration(days: 14);

  /// Everyone marked as having gone to [occurrence] of [eventId].
  static Set<String> wentTo(
    List<(String, ActionPayload)> actions,
    String eventId,
    DateTime occurrence,
  ) => {
    for (final (_, a) in actions)
      if (a.kind == ActionKind.activity &&
          a.eventId == eventId &&
          a.occurrenceStart == occurrence)
        ?a.completedBy,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rewardsOnProvider)) return const SizedBox.shrink();
    final now = DateTime.now().toUtc();
    if (occurrence.isAfter(now) ||
        occurrence.isBefore(now.subtract(window))) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value;
    if (me == null) return const SizedBox.shrink();
    final went = wentTo(
      ref.watch(actionsProvider).value ?? const [],
      eventId,
      occurrence,
    );
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final going = [
      for (final m in members)
        if (m.isActive &&
            m.role != MemberRole.helper &&
            (participantIds.isEmpty || participantIds.contains(m.id)))
          m,
    ];

    Future<void> mark(String member) async {
      final store = await ref.read(familyStoreProvider.future);
      await store.markAttended(
        eventId: eventId,
        occurrenceStart: occurrence,
        member: member,
        title: title,
      );
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text('⚽ ${l10n.activityWho}', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (me.isParent)
          Wrap(
            spacing: 8,
            children: [
              for (final m in going)
                FilterChip(
                  label: Text(m.displayName),
                  selected: went.contains(m.id),
                  // Ticked is ticked: going is never taken back.
                  onSelected: went.contains(m.id) ? null : (_) => mark(m.id),
                ),
            ],
          )
        else if (going.any((m) => m.id == me.memberId))
          went.contains(me.memberId)
              ? Text('✅ ${l10n.activityCounted}')
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => mark(me.memberId),
                    icon: const Icon(Icons.directions_run),
                    label: Text(l10n.activityWent),
                  ),
                ),
      ],
    );
  }
}
