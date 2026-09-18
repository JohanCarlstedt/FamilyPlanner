import 'package:domain/domain.dart';

import '../../common/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/member_style.dart';
import '../../membership/membership.dart';
import '../events/event_detail_screen.dart';
import 'week_providers.dart';

final _time = DateFormat('HH:mm');

/// Spec §5 "Views on a 380px screen": the agenda week, grouped by day, with a
/// week strip above it as a navigator, and the Mine / Family scope and member
/// chips above that.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  static const path = '/week';

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  final _dayKeys = List.generate(7, (_) => GlobalKey());

  void _jumpTo(int day) {
    final context = _dayKeys[day].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(weekProvider);
    final offset = ref.watch(weekOffsetProvider);
    final offsetController = ref.read(weekOffsetProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: switch (week) {
          AsyncValue(:final value?) => _Title(state: value),
          _ => Text(context.l10n.tabWeek),
        },
        actions: [
          IconButton(
            tooltip: context.l10n.weekPrevious,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => offsetController.set(offset - 1),
          ),
          if (offset != 0)
            IconButton(
              tooltip: context.l10n.weekThis,
              icon: const Icon(Icons.today),
              onPressed: () => offsetController.set(0),
            ),
          IconButton(
            tooltip: context.l10n.weekNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => offsetController.set(offset + 1),
          ),
        ],
      ),
      body: switch (week) {
        AsyncValue(:final value?) => _WeekBody(
          state: value,
          dayKeys: _dayKeys,
          onDay: _jumpTo,
        ),
        AsyncValue(:final error?) => Center(
          child: Text(context.l10n.weekLoadFailed('$error')),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.state});

  final WeekState state;

  @override
  Widget build(BuildContext context) {
    final start = state.agenda.start;
    final end = DateTime(start.year, start.month, start.day + 6);
    final range = start.month == end.month
        ? '${start.day}–${DateFormat('d MMM').format(end)}'
        : '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.weekNumber(state.agenda.number)),
        Text(
          range,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _WeekBody extends ConsumerWidget {
  const _WeekBody({
    required this.state,
    required this.dayKeys,
    required this.onDay,
  });

  final WeekState state;
  final List<GlobalKey> dayKeys;
  final ValueChanged<int> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    final controller = ref.read(calendarViewProvider.notifier);
    final hasMe = ref.watch(membershipProvider).value != null;
    final agenda = state.agenda;

    return Column(
      children: [
        if (hasMe)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(context.l10n.scopeMine)),
                ButtonSegment(
                  value: false,
                  label: Text(context.l10n.scopeFamily),
                ),
              ],
              selected: {view.mine},
              onSelectionChanged: (s) => controller.setMine(s.single),
            ),
          ),
        if (!view.mine && state.members.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final m in state.members)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onLongPress: () => controller.only(m.id),
                      child: FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: state.colors[m.id],
                        ),
                        label: Text(m.displayName),
                        // Empty selection means everyone is shown.
                        selected:
                            view.members.isEmpty || view.members.contains(m.id),
                        onSelected: (_) => controller.toggle(m.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        _WeekStrip(state: state, onDay: onDay),
        if (agenda.unassigned.isNotEmpty || agenda.conflicts.isNotEmpty)
          _Warnings(agenda: agenda),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final (i, day) in agenda.days.indexed)
                _DaySection(
                  key: dayKeys[i],
                  state: state,
                  date: DateTime(
                    agenda.start.year,
                    agenda.start.month,
                    agenda.start.day + i,
                  ),
                  day: day,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Seven compact days with a dot per member who has something that day.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.state, required this.onDay});

  final WeekState state;
  final ValueChanged<int> onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = state.agenda.start;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final date = DateTime(start.year, start.month, start.day + i);
                  final isToday = date == state.today;
                  final day = state.agenda.days[i];
                  final memberIds = <String>{
                    for (final e in day.entries)
                      if (!e.event.isCancelled) ...e.event.participantIds,
                  };
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onDay(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: isToday
                          ? BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            )
                          : null,
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E')
                                .format(date)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            '${date.day}',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final id in memberIds.take(4))
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          state.colors[id] ??
                                          theme.colorScheme.outline,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (memberIds.isEmpty && day.entries.isNotEmpty)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.agenda});

  final WeekAgenda agenda;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      if (agenda.unassigned.isNotEmpty)
        context.l10n.weekUnassigned(agenda.unassigned.length),
      if (agenda.conflicts.isNotEmpty)
        context.l10n.weekDoubleBooked(agenda.conflicts.length),
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.weekWarnings(parts.join(' · ')),
        style: TextStyle(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.state,
    required this.date,
    required this.day,
  });

  final WeekState state;
  final DateTime date;
  final DayAgenda day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = date == state.today;
    final isPast = date.isBefore(state.today);
    final items = [...day.entries, ...day.routines]
      ..sort((a, b) => a.start.compareTo(b.start));
    final conflicted = {
      for (final c in day.conflicts) ...[c.first.event.id, c.second.event.id],
    };

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    DateFormat('EEEE d MMMM').format(date),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isToday ? theme.colorScheme.primary : null,
                      fontWeight: isToday ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.today,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                context.l10n.nothingPlanned,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final e in items)
            _Row(
              state: state,
              entry: e,
              conflicted: conflicted.contains(e.event.id),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.state,
    required this.entry,
    required this.conflicted,
  });

  final WeekState state;
  final AgendaEntry entry;
  final bool conflicted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = entry.event;
    final byId = state.byId;
    final participants = [for (final id in event.participantIds) ?byId[id]];
    final responsible = byId[event.responsibleMemberId];
    final muted = theme.colorScheme.onSurfaceVariant;
    final needsAdult =
        responsible == null && participants.any((m) => m.isChild);

    return InkWell(
      onTap: () => context.push(EventDetailScreen.pathFor(event.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                _time.format(state.local(entry.start)),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: event.isRoutine ? muted : null,
                ),
              ),
            ),
            Container(
              width: 4,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: participants.isEmpty
                    ? theme.colorScheme.outlineVariant
                    : state.colors[participants.first.id],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style:
                        (event.isRoutine
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: muted,
                                  )
                                : theme.textTheme.bodyLarge)
                            ?.copyWith(
                              decoration: event.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                  ),
                  if (!event.isRoutine &&
                      (responsible != null || needsAdult || conflicted))
                    Text(
                      [
                        if (event.isCancelled)
                          context.l10n.cancelled
                        else if (responsible != null)
                          context.l10n.driving(responsible.displayName)
                        else if (needsAdult)
                          context.l10n.noOneResponsible,
                        if (conflicted) context.l10n.doubleBookedShort,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: needsAdult || conflicted
                            ? theme.colorScheme.error
                            : muted,
                      ),
                    ),
                ],
              ),
            ),
            MemberAvatars(
              members: participants,
              colors: state.colors,
              initials: state.initials,
              size: event.isRoutine ? 18 : 22,
            ),
          ],
        ),
      ),
    );
  }
}
