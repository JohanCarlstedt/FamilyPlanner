import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';

import '../../data/store_providers.dart';

import '../../membership/permissions_provider.dart';
import '../../common/event_title.dart';
import '../../common/l10n.dart';
import '../away/away_screen.dart' show describeAbsence;
import '../homework/homework_due.dart';
import '../../integrations/weather.dart';
import '../electricity/electricity_price.dart';
import 'day_weather_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/member_style.dart';
import '../../membership/membership.dart';
import '../events/event_detail_screen.dart';
import '../events/new_event_screen.dart';
import 'week_providers.dart';
import 'week_selection.dart';
import 'remove_many.dart';

final _time = DateFormat('HH:mm');

/// The day a new event made from the week should start on: today when today
/// is in view, and otherwise the Monday of the week being looked at. Nine in
/// the morning, which is a working guess the form lets you change.
DateTime _newEventDay(WeekState state) {
  final start = state.agenda.start;
  final today = state.today;
  final inThisWeek =
      !today.isBefore(start) &&
      today.isBefore(start.add(const Duration(days: 7)));
  final day = inThisWeek ? today : start;
  return DateTime.utc(day.year, day.month, day.day, 9);
}

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

  /// Removes everything picked out, with one undo for the lot.
  Future<void> _removeSelected(WeekState state) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final selection = ref.read(weekSelectionProvider.notifier);
    final entries = RemoveMany.picked(state, ref.read(weekSelectionProvider));
    if (entries.isEmpty) return;

    final store = await ref.read(familyStoreProvider.future);
    final payloads = <String, Payload>{};
    for (final e in entries) {
      if (await store.payloadOf(e.event.id) case final p?) {
        payloads[e.event.id] = p;
      }
    }
    final mine = RemoveMany.allowed(
      entries,
      ref.read(permissionsProvider),
      payloads,
    );
    final refused = entries.length - mine.length;
    if (!mounted) return;
    if (mine.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.removeManyNotYours(refused))),
      );
      selection.clear();
      return;
    }
    if (!await RemoveMany.confirm(context, mine)) return;

    final undo = await RemoveMany.remove(store, mine);
    final sync = ref.read(syncControllerProvider.notifier);
    sync.syncNow();
    selection.clear();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Text(
          [
            l10n.removedMany(mine.length),
            if (refused > 0) l10n.removeManyNotYours(refused),
          ].join(' · '),
        ),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await undo();
            sync.syncNow();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(weekProvider);
    final offset = ref.watch(weekOffsetProvider);
    final offsetController = ref.read(weekOffsetProvider.notifier);
    final selected = ref.watch(weekSelectionProvider);

    return Scaffold(
      floatingActionButton: switch (ref.watch(permissionsProvider)) {
        final p when p.createEvents => FloatingActionButton(
          // Starts on the week being looked at, not today: someone on next
          // week's view is planning next week.
          onPressed: () => context.go(
            Uri(
              path: '${WeekScreen.path}/${NewEventScreen.segment}',
              queryParameters: switch (week) {
                AsyncValue(:final value?) => {
                  'at': _newEventDay(value).toIso8601String(),
                },
                _ => null,
              },
            ).toString(),
          ),
          tooltip: p.createsRequests
              ? context.l10n.requestEvent
              : context.l10n.newEvent,
          child: const Icon(Icons.add),
        ),
        _ => null,
      },
      appBar: selected.isNotEmpty && week.value != null
          // While things are picked out, the bar is about them: the week
          // arrows would take the selection somewhere it does not exist.
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                onPressed: ref.read(weekSelectionProvider.notifier).clear,
              ),
              title: Text(context.l10n.selectedCount(selected.length)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.removeItem,
                  onPressed: () => _removeSelected(week.value!),
                ),
              ],
            )
          : AppBar(
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
  /// A little one sees today and tomorrow only (spec §2).
  bool _visible(WidgetRef ref, int index) {
    final days = ref.watch(permissionsProvider).daysVisible;
    if (days == null) return true;
    final start = state.agenda.start;
    final date = DateTime(start.year, start.month, start.day + index);
    final today = state.today;
    return !date.isBefore(today) &&
        date.isBefore(DateTime(today.year, today.month, today.day + days));
  }

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
                if (_visible(ref, i))
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

/// The day's weather where this phone is, when there is any (spec §5: the
/// week answers "what are we doing", and what to wear is part of it).
class _Weather extends ConsumerWidget {
  const _Weather({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The week counts its days locally; a forecast's days are wall-clock
    // dates, as dates travel everywhere else here.
    final day = ref
        .watch(weekWeatherProvider)
        .value?[DateTime.utc(date.year, date.month, date.day)];
    if (day == null) return const SizedBox.shrink();
    return Tooltip(
      message: context.l10n.weatherNearby,
      // The day hour by hour, the way the electricity price opens.
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: day.hours.isEmpty ? null : () => showDayWeather(context, day),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                weatherIcon(day.symbol),
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.weatherDegrees(day.high.round(), day.low.round()),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (day.millimetres >= 0.5) ...[
                const SizedBox(width: 6),
                Text(
                  context.l10n.weatherMillimetres(day.millimetres.round()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// MET's symbol names, as icons. Unknown ones (they add some) fall back to
/// a cloud rather than nothing.
IconData weatherIcon(String symbol) {
  final name = symbol.split('_').first;
  // The day's symbol is never a night one; an hour's can be, and a sun
  // at two in the morning reads as a mistake.
  final night = symbol.endsWith('_night');
  return switch (name) {
    'clearsky' || 'fair' when night => Icons.nightlight_outlined,
    'clearsky' || 'fair' => Icons.wb_sunny_outlined,
    'partlycloudy' when night => Icons.nights_stay_outlined,
    'partlycloudy' => Icons.wb_cloudy_outlined,
    'fog' => Icons.foggy,
    'lightrain' ||
    'rain' ||
    'heavyrain' ||
    'lightrainshowers' ||
    'rainshowers' ||
    'heavyrainshowers' => Icons.water_drop_outlined,
    'lightsleet' ||
    'sleet' ||
    'heavysleet' ||
    'lightsleetshowers' ||
    'sleetshowers' ||
    'heavysleetshowers' => Icons.grain,
    'lightsnow' ||
    'snow' ||
    'heavysnow' ||
    'lightsnowshowers' ||
    'snowshowers' ||
    'heavysnowshowers' => Icons.ac_unit,
    _ when name.contains('thunder') => Icons.thunderstorm_outlined,
    _ => Icons.cloud_outlined,
  };
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
                const Spacer(),
                DayPriceBadge(
                  date: DateTime.utc(date.year, date.month, date.day),
                ),
                const SizedBox(width: 8),
                _Weather(date: date),
              ],
            ),
          ),
          // What is due that day. The week is the screen anybody plans a
          // week on, and it was the one screen that did not know homework
          // existed.
          HomeworkDueLine(date: date),
          // A trip or a holiday, on every day it covers. Without this the
          // week simply went quiet on the days somebody was away — an
          // absence suspends what it covers, so the explanation for a thin
          // Thursday was missing from the one screen that shows Thursday.
          for (final a in day.away)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    size: 16,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      describeAbsence(context.l10n, a, {
                        for (final m in state.members) m.id: m.displayName,
                      }),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
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

class _Row extends ConsumerWidget {
  const _Row({
    required this.state,
    required this.entry,
    required this.conflicted,
  });

  final WeekState state;
  final AgendaEntry entry;
  final bool conflicted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final event = entry.event;
    final selection = ref.watch(weekSelectionProvider.notifier);
    ref.watch(weekSelectionProvider);
    final picked = selection.has(entry);
    final byId = state.byId;
    final participants = [for (final id in event.participantIds) ?byId[id]];
    final responsible = byId[event.responsibleMemberId];
    final muted = theme.colorScheme.onSurfaceVariant;
    final needsAdult =
        responsible == null && participants.any((m) => m.isChild);

    return InkWell(
      // Long-press to start picking several out, then tap to add and
      // remove. Tapping still opens the event when nothing is picked, so
      // the ordinary way in is untouched.
      onLongPress: () => selection.toggle(entry),
      onTap: () => selection.active
          ? selection.toggle(entry)
          : context.push(
              EventDetailScreen.pathFor(
                event.id,
                at: entry.occurrence.originalStart,
              ),
            ),
      child: Container(
        color: picked
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
            : null,
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
                      shownTitle(context, event, entry.start),
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
                        (responsible != null ||
                            needsAdult ||
                            conflicted ||
                            event.status == EventStatus.pendingApproval))
                      Text(
                        [
                          if (event.status == EventStatus.pendingApproval)
                            context.l10n.waitingForParent
                          else if (event.isCancelled)
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
              if (picked)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                MemberAvatars(
                  members: participants,
                  colors: state.colors,
                  initials: state.initials,
                  size: event.isRoutine ? 18 : 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
