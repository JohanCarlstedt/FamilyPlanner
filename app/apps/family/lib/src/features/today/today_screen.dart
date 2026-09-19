import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';

import '../../membership/permissions_provider.dart';
import '../../reminders/reminder_notifications.dart';
import '../more/more_screen.dart';
import '../devices/add_device_screen.dart';
import '../../membership/membership.dart';
import '../../common/event_title.dart';
import '../../common/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/member_style.dart';
import '../events/event_detail_screen.dart';
import '../events/new_event_screen.dart';
import '../../common/clock.dart';
import '../../data/family_repository.dart';
import '../events/occurrence_editing.dart';
import '../review/weekly_review_screen.dart';
import '../actions/actions_providers.dart';
import '../away/away_screen.dart';
import '../search/search_screen.dart';
import '../homework/homework_screen.dart';
import '../actions/actions_screen.dart';
import '../shopping/menu_screen.dart';
import '../shopping/shopping_providers.dart';
import '../shopping/shopping_screen.dart';
import 'today_providers.dart';

final _time = DateFormat('HH:mm');

/// Spec §10 screen 1: today's timeline in member colours, with the
/// unassigned-responsibility strip and conflicts surfaced above it (§5).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  static const path = '/today';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tabToday),
        actions: [
          IconButton(
            tooltip: context.l10n.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(SearchScreen.path),
          ),
        ],
        bottom: switch (today) {
          AsyncValue(:final value?) => _DateHeader(state: value),
          _ => null,
        },
      ),
      floatingActionButton: switch (ref.watch(permissionsProvider)) {
        final p when p.createEvents => FloatingActionButton.extended(
          onPressed: () =>
              context.go('${TodayScreen.path}/${NewEventScreen.segment}'),
          icon: const Icon(Icons.add),
          label: Text(
            p.createsRequests
                ? context.l10n.requestEvent
                : context.l10n.newEvent,
          ),
        ),
        _ => null,
      },
      body: Column(
        children: [
          const _OneDeviceBanner(),
          const _NotificationsBanner(),
          const _ReviewCard(),
          const _DinnerTonight(),
          const _TodosToday(),
          const _HomeworkStrip(),
          Expanded(
            child: switch (today) {
              AsyncValue(:final value?) => _TodayBody(state: value),
              AsyncValue(:final error?) => _Message(
                icon: Icons.error_outline,
                text: context.l10n.todayLoadFailed('$error'),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget implements PreferredSizeWidget {
  const _DateHeader({required this.state});

  final TodayState state;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    final local = state.local(state.now);
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          '${DateFormat('EEEE d MMMM').format(local)} · '
          '${context.l10n.weekNumber(isoWeekNumber(local))}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final agenda = state.agenda;
    if (agenda.entries.isEmpty &&
        agenda.routines.isEmpty &&
        agenda.away.isEmpty) {
      return _Message(
        icon: Icons.wb_sunny_outlined,
        text: context.l10n.nothingToday,
      );
    }

    final nextUp = agenda.nextUp;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final a in agenda.away) ...[
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.luggage_outlined),
                  title: Text(
                    describeAbsence(context.l10n, a, {
                      for (final m in state.members.values) m.id: m.displayName,
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (agenda.unassigned.isNotEmpty) ...[
              _UnassignedCard(state: state),
              const SizedBox(height: 12),
            ],
            if (agenda.conflicts.isNotEmpty) ...[
              _ConflictCard(state: state),
              const SizedBox(height: 12),
            ],
            if (nextUp != null) ...[
              _NextUpCard(state: state, entry: nextUp),
              const SizedBox(height: 20),
            ],
            ..._timeline(context),
          ],
        ),
      ),
    );
  }

  /// Events and routines in start order, with a marker at the current time.
  List<Widget> _timeline(BuildContext context) {
    final items = [...state.agenda.entries, ...state.agenda.routines]
      ..sort((a, b) => a.start.compareTo(b.start));

    final widgets = <Widget>[];
    var markerPlaced = false;
    for (final entry in items) {
      if (!markerPlaced && entry.start.isAfter(state.now)) {
        widgets.add(_NowMarker(label: _time.format(state.local(state.now))));
        markerPlaced = true;
      }
      widgets.add(
        entry.event.isRoutine
            ? _RoutineBand(state: state, entry: entry)
            : _EventTile(state: state, entry: entry),
      );
    }
    if (!markerPlaced) {
      widgets.add(_NowMarker(label: _time.format(state.local(state.now))));
    }
    return widgets;
  }
}

String _range(TodayState state, AgendaEntry entry) =>
    '${_time.format(state.local(entry.start))}–'
    '${_time.format(state.local(entry.end))}';

class _UnassignedCard extends StatelessWidget {
  const _UnassignedCard({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = state.agenda.unassigned;
    return _WarningCard(
      icon: Icons.directions_car_outlined,
      color: scheme.tertiaryContainer,
      onColor: scheme.onTertiaryContainer,
      title: context.l10n.unassignedCount(entries.length),
      lines: [
        for (final e in entries)
          '${_time.format(state.local(e.start))}  ${e.event.title} · '
              '${state.membersOf(e.event.participantIds).map((m) => m.displayName).join(', ')}',
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return _WarningCard(
      icon: Icons.warning_amber_rounded,
      color: scheme.errorContainer,
      onColor: scheme.onErrorContainer,
      title: l10n.doubleBooked,
      lines: [
        for (final c in state.agenda.conflicts)
          '${state.members[c.memberId]?.displayName ?? l10n.someone}: '
              '${l10n.overlaps(c.first.event.title, _range(state, c.first), c.second.event.title, _range(state, c.second))}',
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.icon,
    required this.color,
    required this.onColor,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final Color color;
  final Color onColor;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      color: color,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: onColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall?.copyWith(color: onColor)),
                  const SizedBox(height: 4),
                  for (final line in lines)
                    Text(
                      line,
                      style: text.bodyMedium?.copyWith(color: onColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.state, required this.entry});

  final TodayState state;
  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final event = entry.event;
    final participants = state.membersOf(event.participantIds);

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.nextUp(
                _until(context.l10n, entry.start.difference(state.now)),
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [_range(state, entry), ?event.location].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                MemberAvatars(
                  members: participants,
                  colors: state.colors,
                  initials: state.initials,
                  size: 28,
                ),
                const Spacer(),
                _Responsible(state: state, event: event),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _until(AppLocalizations l10n, Duration d) {
    if (d.inMinutes < 1) return l10n.startingNow;
    if (d.inMinutes < 60) return l10n.inMinutes(d.inMinutes);
    final minutes = d.inMinutes % 60;
    return minutes == 0
        ? l10n.inHours(d.inHours)
        : l10n.inHoursMinutes(d.inHours, minutes);
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.state, required this.entry});

  final TodayState state;
  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = entry.event;
    final participants = state.membersOf(event.participantIds);
    final isPast = !entry.end.isAfter(state.now);
    final cancelled = event.isCancelled;
    final stripe = participants.isEmpty
        ? [theme.colorScheme.outline]
        : [for (final m in participants) state.colors[m.id]!];

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _time.format(state.local(entry.start)),
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(
                      _time.format(state.local(entry.end)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // One colour segment per member, so shared events read as
                    // shared at a glance.
                    SizedBox(
                      width: 6,
                      child: Column(
                        children: [
                          for (final color in stripe)
                            Expanded(
                              // A childless ColoredBox collapses to zero
                              // width; SizedBox.expand gives it the stripe's.
                              child: ColoredBox(
                                color: color,
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shownTitle(context, event, entry.start),
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (cancelled ||
                                event.location != null ||
                                event.status == EventStatus.pendingApproval)
                              Text(
                                event.status == EventStatus.pendingApproval
                                    ? context.l10n.waitingForParent
                                    : cancelled
                                    ? context.l10n.cancelled
                                    : event.location!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cancelled
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                MemberAvatars(
                                  members: participants,
                                  colors: state.colors,
                                  initials: state.initials,
                                ),
                                const Spacer(),
                                if (!cancelled)
                                  _Responsible(state: state, event: event),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap: () => context.push(
        EventDetailScreen.pathFor(event.id, at: entry.occurrence.originalStart),
      ),
      child: Opacity(opacity: isPast || cancelled ? 0.55 : 1, child: tile),
    );
  }
}

/// Who's accountable, or a warning when a child's event has no one.
class _Responsible extends StatelessWidget {
  const _Responsible({required this.state, required this.event});

  final TodayState state;
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsible = state.members[event.responsibleMemberId];
    if (responsible == null) {
      final involvesChild = state
          .membersOf(event.participantIds)
          .any((m) => m.isChild);
      if (!involvesChild) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 4),
          Text(
            context.l10n.noOneResponsible,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.directions_car_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(responsible.displayName, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

/// Routine blocks are background, not events: a quiet band, no card (§5).
class _RoutineBand extends StatelessWidget {
  const _RoutineBand({required this.state, required this.entry});

  final TodayState state;
  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isPast = !entry.end.isAfter(state.now);
    return Opacity(
      opacity: isPast ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                _time.format(state.local(entry.start)),
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      entry.event.title,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    const Spacer(),
                    MemberAvatars(
                      members: state.membersOf(entry.event.participantIds),
                      colors: state.colors,
                      initials: state.initials,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowMarker extends StatelessWidget {
  const _NowMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Divider(color: color, thickness: 1.5, height: 1)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spec §9: a family whose only keys live on one phone is one dropped phone
/// from losing everything. Shown to parents until a second device holds them.
class _OneDeviceBanner extends ConsumerWidget {
  const _OneDeviceBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null ||
        !membership.isParent ||
        // Exactly one: this device, and nothing else holds the keys.
        membership.trusted.length != 1) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.key_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.oneDeviceWarning,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    context.go('${MoreScreen.path}/${AddDeviceScreen.segment}'),
                child: Text(context.l10n.addDevice),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether this device may show notifications; re-read after asking.
final notificationsAllowedProvider = FutureProvider<bool>(
  (ref) => ReminderNotifications.allowed(),
);

/// Spec §9: ask for notifications once there's a reason, with the reason.
/// Every family has one: the default reminders need no setting up.
class _NotificationsBanner extends ConsumerWidget {
  const _NotificationsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(notificationsAllowedProvider).value ?? true) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.notificationsOff,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () async {
                  await ReminderNotifications.requestPermission();
                  ref.invalidate(notificationsAllowedProvider);
                },
                child: Text(context.l10n.turnOn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// From Friday to Sunday, for parents: the week ahead wants a look (spec §10
/// "The weekly review").
class _ReviewCard extends ConsumerWidget {
  const _ReviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value;
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;
    final review = ref.watch(weeklyReviewProvider).value;
    if (now == null || review == null || !isParent) return const SizedBox();
    if (wallClock(now, familyTimeZone).weekday < DateTime.friday) {
      return const SizedBox();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: ListTile(
          leading: const Icon(Icons.checklist_rtl),
          title: Text(l10n.reviewPlanCard(review.weekNumber)),
          subtitle: Text(l10n.reviewPlanCardBody(review.needsAttention)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.go('${MoreScreen.path}/${WeeklyReviewScreen.segment}'),
        ),
      ),
    );
  }
}

/// Tonight's meal from the family's menu, and who's cooking (spec §4: the
/// join between the calendar and the menu).
class _DinnerTonight extends ConsumerWidget {
  const _DinnerTonight();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value;
    if (now == null) return const SizedBox();
    final local = wallClock(now, familyTimeZone);
    final today = DateTime.utc(local.year, local.month, local.day);
    final meal = (ref.watch(mealsProvider).value ?? const [])
        .where((m) => m.$2.date == today && m.$2.slot == 'dinner')
        .firstOrNull
        ?.$2;
    if (meal == null) return const SizedBox();
    final recipes = {
      for (final (id, r)
          in ref.watch(recipesProvider).value ??
              const <(String, RecipePayload)>[])
        id: r.title,
    };
    final what = [
      for (final r in meal.recipes) ?recipes[r.recipeId],
      if (meal.recipes.isEmpty) ?meal.title,
    ].join(' + ');
    final cook = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == meal.cookMemberId)
        .firstOrNull;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.restaurant_outlined),
          title: Text(what),
          subtitle: Text(
            [
              l10n.dinnerTonight,
              if (cook != null) l10n.mealCookedBy(cook.displayName),
            ].join(' · '),
          ),
          onTap: () =>
              context.go('${ShoppingScreen.path}/${MenuScreen.segment}'),
        ),
      ),
    );
  }
}

/// My to-dos due today or overdue (spec §3 "How actions surface").
class _TodosToday extends ConsumerWidget {
  const _TodosToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value;
    final me = ref.watch(membershipProvider).value?.memberId;
    if (now == null || me == null) return const SizedBox();
    final local = wallClock(now, familyTimeZone);
    final endOfToday = instantOf(
      DateTime.utc(local.year, local.month, local.day + 1),
      familyTimeZone,
    );
    final due = dueFor(
      ref.watch(actionsProvider).value ?? const [],
      me,
      endOfToday,
    );
    if (due.isEmpty) return const SizedBox();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.task_alt),
          title: Text(l10n.todayTodos(due.length)),
          subtitle: Text(due.map((a) => a.$2.title).join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.go('${MoreScreen.path}/${ActionsScreen.segment}'),
        ),
      ),
    );
  }
}

/// A child's homework due in the next few days, above their day (spec §10:
/// a child won't go looking for a homework section).
class _HomeworkStrip extends ConsumerWidget {
  const _HomeworkStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null || membership.isParent) return const SizedBox();
    final now = DateTime.now().toUtc();
    final soon = [
      for (final (_, h)
          in ref.watch(homeworkProvider).value ??
              const <(String, HomeworkPayload)>[])
        if (h.memberId == membership.memberId &&
            !h.finished &&
            (h.dueAt?.isBefore(now.add(const Duration(days: 3))) ?? false))
          h,
    ];
    if (soon.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text(context.l10n.hwStrip(soon.length)),
          subtitle: Text(soon.map((h) => h.title).join(' · ')),
          onTap: () =>
              context.go('${MoreScreen.path}/${HomeworkScreen.segment}'),
        ),
      ),
    );
  }
}
