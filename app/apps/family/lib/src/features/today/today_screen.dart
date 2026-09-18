import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/member_style.dart';
import '../events/event_detail_screen.dart';
import '../events/new_event_screen.dart';
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
        title: const Text('Today'),
        bottom: switch (today) {
          AsyncValue(:final value?) => _DateHeader(state: value),
          _ => null,
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.go('${TodayScreen.path}/${NewEventScreen.segment}'),
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
      body: switch (today) {
        AsyncValue(:final value?) => _TodayBody(state: value),
        AsyncValue(:final error?) => _Message(
          icon: Icons.error_outline,
          text: "Couldn't load today.\n$error",
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
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
          'Week ${isoWeekNumber(local)}',
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
    if (agenda.entries.isEmpty && agenda.routines.isEmpty) {
      return const _Message(
        icon: Icons.wb_sunny_outlined,
        text: 'Nothing planned today.',
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
      title: entries.length == 1
          ? 'No one is responsible for 1 event'
          : 'No one is responsible for ${entries.length} events',
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
    return _WarningCard(
      icon: Icons.warning_amber_rounded,
      color: scheme.errorContainer,
      onColor: scheme.onErrorContainer,
      title: 'Double-booked',
      lines: [
        for (final c in state.agenda.conflicts)
          '${state.members[c.memberId]?.displayName ?? 'Someone'}: '
              '${c.first.event.title} ${_range(state, c.first)} overlaps '
              '${c.second.event.title} ${_range(state, c.second)}',
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
              'Next up · ${_until(entry.start.difference(state.now))}',
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

  static String _until(Duration d) {
    if (d.inMinutes < 1) return 'starting now';
    if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
    final minutes = d.inMinutes % 60;
    return minutes == 0
        ? 'in ${d.inHours} h'
        : 'in ${d.inHours} h $minutes min';
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
                              event.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (cancelled || event.location != null)
                              Text(
                                cancelled ? 'Cancelled' : event.location!,
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
      onTap: () => context.push(EventDetailScreen.pathFor(event.id)),
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
            'No one responsible',
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
