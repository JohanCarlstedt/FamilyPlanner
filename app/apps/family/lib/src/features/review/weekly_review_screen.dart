import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/clock.dart';
import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../events/event_detail_screen.dart';
import '../actions/actions_providers.dart';
import '../actions/actions_screen.dart';
import '../events/occurrence_editing.dart';
import '../more/more_screen.dart';
import '../shopping/menu_screen.dart';
import '../shopping/shopping_screen.dart';

/// The week to review now, from the family's events.
final weeklyReviewProvider = FutureProvider<WeeklyReview>((ref) async {
  final now = await ref.watch(nowProvider.future);
  final members = await ref.watch(membersProvider.future);
  final events = await ref.watch(eventsProvider.future);
  final local = tz.TZDateTime.from(now, tz.getLocation(familyTimeZone));
  return const WeeklyReviewBuilder().build(
    events: events,
    members: members,
    today: DateTime.utc(local.year, local.month, local.day),
    timeZone: familyTimeZone,
    now: now,
  );
});

/// Spec §10 "The weekly review": the screen the family opens together on
/// Sunday evening. What needs deciding first, then who's taking what, then
/// the week.
class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  static const segment = 'review';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final review = ref.watch(weeklyReviewProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (review) {
          AsyncValue(:final value?) => l10n.weekNumber(value.weekNumber),
          _ => l10n.weeklyReview,
        }),
      ),
      body: switch (review) {
        AsyncValue(:final value?) => _Review(review: value),
        AsyncValue(:final error?) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({required this.review});

  final WeeklyReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final parents = [
      for (final m in members)
        if (m.role == MemberRole.parent) m,
    ];
    final time = DateFormat('HH:mm');
    final day = DateFormat('EEEE');
    String when(AgendaEntry e) {
      final local = wallClock(e.start, familyTimeZone);
      return '${day.format(local)} ${time.format(local)}';
    }

    final end = review.weekStart.add(const Duration(days: 6));
    final dates = DateFormat('d MMMM');

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              '${dates.format(review.weekStart)} – ${dates.format(end)} · '
              '${l10n.reviewEvents(review.eventCount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.reviewToDecide, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (review.needsAttention == 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.reviewAllCovered),
              ),
            for (final e in review.unassigned)
              _Decision(
                icon: Icons.person_search_outlined,
                title: e.event.title,
                subtitle: l10n.reviewNoOne(when(e)),
                onTap: () => _open(context, e),
                // One-off events can be settled right here; a repeating one
                // asks which occurrences, on its own page.
                assignTo: e.event.series.rule == null ? parents : const [],
                onAssign: (m) => _assign(ref, e.event.id, m.id),
              ),
            for (final c in review.conflicts)
              _Decision(
                icon: Icons.call_split,
                title: l10n.reviewClash(
                  byId[c.memberId]?.displayName ?? '',
                  c.first.event.title,
                  c.second.event.title,
                ),
                subtitle: when(c.first),
                onTap: () => _open(context, c.second),
              ),
            ..._household(context, ref),
            if (review.drives.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.reviewResponsible, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, m) in members.indexed)
                    if (review.drives[m.id] case final n?)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: MemberStyle.colorOf(m, i),
                        ),
                        label: Text('${m.displayName} · $n'),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.reviewTheWeek, style: theme.textTheme.titleMedium),
            for (final (i, d) in review.days.indexed) ...[
              const SizedBox(height: 12),
              Text(
                DateFormat('EEEE d MMMM')
                    .format(review.weekStart.add(Duration(days: i))),
                style: theme.textTheme.labelLarge,
              ),
              if (d.entries.isEmpty)
                Text(
                  l10n.nothingPlanned,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              for (final e in d.entries)
                InkWell(
                  onTap: () => _open(context, e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            time.format(wallClock(e.start, familyTimeZone)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.event.title,
                            style: e.event.isCancelled
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                        if (byId[e.event.responsibleMemberId] case final m?)
                          Text(m.displayName, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// The rest of the household's week (spec §10): dinners with nothing
  /// planned and to-dos nobody has taken.
  List<Widget> _household(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final end = review.weekStart.add(const Duration(days: 7));
    final planned = {
      for (final (_, m)
          in ref.watch(mealsProvider).value ?? const <(String, MealPayload)>[])
        if (m.slot == 'dinner') m.date,
    };
    final openDinners = [
      for (var i = 0; i < 7; i++)
        if (!planned.contains(review.weekStart.add(Duration(days: i)))) i,
    ].length;
    final endInstant = instantOf(end, familyTimeZone);
    final unclaimed = [
      for (final (_, a)
          in ref.watch(actionsProvider).value ??
              const <(String, ActionPayload)>[])
        if (a.isOpen &&
            a.assignedTo == null &&
            (a.dueAt == null || a.dueAt!.isBefore(endInstant)))
          a,
    ];
    return [
      if (openDinners > 0)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restaurant_outlined),
          title: Text(l10n.reviewDinnersOpen(openDinners)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.go('${ShoppingScreen.path}/${MenuScreen.segment}'),
        ),
      if (unclaimed.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.task_alt),
          title: Text(l10n.reviewUnclaimed(unclaimed.length)),
          subtitle: Text(unclaimed.map((a) => a.title).join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.go('${MoreScreen.path}/${ActionsScreen.segment}'),
        ),
    ];
  }

  void _open(BuildContext context, AgendaEntry e) => context.push(
    EventDetailScreen.pathFor(e.event.id, at: e.occurrence.originalStart),
  );

  Future<void> _assign(WidgetRef ref, String eventId, String memberId) async {
    final store = await ref.read(familyStoreProvider.future);
    final existing = await store.payloadOf(eventId);
    if (existing == null) return;
    final copy = Payload.decode(existing.encode())
      ..setText('responsible', memberId);
    await store.saveEvent(EventPayload.read(copy), id: eventId);
    ref.read(syncControllerProvider.notifier).syncNow();
  }
}

class _Decision extends StatelessWidget {
  const _Decision({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.assignTo = const [],
    this.onAssign,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<Member> assignTo;
  final void Function(Member)? onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        Text(subtitle, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (assignTo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in assignTo)
                      ActionChip(
                        label: Text(m.displayName),
                        onPressed: () => onAssign?.call(m),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
