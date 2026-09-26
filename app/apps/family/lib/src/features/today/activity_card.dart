import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../actions/actions_providers.dart';
import '../events/attendance_section.dart';
import '../rewards/rewards_providers.dart';
import 'today_providers.dart';

/// Being active, on Today: today's activities that have started, asking
/// "did you go?", and a way to log time spent moving. Both count in the
/// family jar and the member's own city (spec section 3,
/// "Contributions"). Nothing at all unless the family has rewards on.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rewardsOnProvider)) return const SizedBox.shrink();
    final me = ref.watch(membershipProvider).value;
    if (me == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
    final actions = ref.watch(actionsProvider).value ?? const [];
    final today = ref.watch(todayProvider).value;
    final asks = [
      for (final e in today?.agenda.entries ?? const <AgendaEntry>[])
        if (e.event.kind == EventKind.activity &&
            e.event.status != EventStatus.cancelled &&
            !e.start.isAfter(now) &&
            (e.event.participantIds.isEmpty ||
                e.event.participantIds.contains(me.memberId)) &&
            !AttendanceSection.wentTo(
              actions,
              e.event.id,
              e.start,
            ).contains(me.memberId))
          e,
    ];

    Future<void> went(AgendaEntry e) async {
      final store = await ref.read(familyStoreProvider.future);
      await store.markAttended(
        eventId: e.event.id,
        occurrenceStart: e.start,
        member: me.memberId,
        title: e.event.title,
      );
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in asks)
                Row(
                  children: [
                    const Text('⚽', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.activityDidYouGo(e.event.title),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    FilledButton(
                      onPressed: () => went(e),
                      child: Text(l10n.activityWent),
                    ),
                  ],
                ),
              Row(
                children: [
                  const Text('🏃', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.activityLog,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => showLogActivity(context, ref),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What was done, and for how long: a child's goes to a grown-up to
/// approve, a parent's own counts at once.
Future<void> showLogActivity(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final kinds = [
    ('🌳', l10n.activityOutside),
    ('🚲', l10n.activityCycling),
    ('🚶', l10n.activityWalk),
    ('⚽', l10n.activityFootball),
    ('🏊', l10n.activitySwim),
    ('💃', l10n.activityDance),
    ('✨', l10n.activityOther),
  ];
  final logged = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      var kind = 0;
      var minutes = 30;
      return StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '🏃 ${l10n.activityLogTitle}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (i, (emoji, name)) in kinds.indexed)
                      ChoiceChip(
                        label: Text('$emoji $name'),
                        selected: kind == i,
                        onSelected: (_) => setState(() => kind = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    for (final m in const [15, 30, 60])
                      ButtonSegment(
                        value: m,
                        label: Text(l10n.activityMinutes(m)),
                      ),
                  ],
                  selected: {minutes},
                  onSelectionChanged: (v) => setState(() => minutes = v.single),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    '${kinds[kind].$1} ${kinds[kind].$2} · '
                    '${l10n.activityMinutes(minutes)}',
                  ),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (logged == null) return;
  final parent = ref.read(membershipProvider).value?.isParent ?? false;
  final store = await ref.read(familyStoreProvider.future);
  await store.logActivity(title: logged, needsApproval: !parent);
  ref.read(syncControllerProvider.notifier).syncNow();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          parent ? l10n.activityCounted : l10n.activitySentForApproval,
        ),
      ),
    );
  }
}
