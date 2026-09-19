import 'package:domain/domain.dart';

import '../../common/l10n.dart';

import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import 'new_event_screen.dart';
import 'occurrence_editing.dart';

/// One event's stored payload, for showing and editing it.
final eventPayloadProvider = FutureProvider.family<EventPayload?, String>((
  ref,
  id,
) async {
  // Re-read whenever the family's events change, e.g. after an edit syncs.
  ref.watch(eventsProvider);
  final store = await ref.watch(familyStoreProvider.future);
  final payload = await store.payloadOf(id);
  return payload == null ? null : EventPayload.read(payload);
});

/// Spec §10 screen 3: what, when, where, who, and who's responsible, with
/// edit and delete. Opened from a calendar, it shows one occurrence ([at]);
/// changes to a repeating event ask whether they touch this occurrence, this
/// and all after it, or the whole series.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId, this.at});

  static const path = '/event/:id';

  /// [at] is the occurrence's original start, which identifies it.
  static String pathFor(String id, {DateTime? at}) => Uri(
    path: '/event/$id',
    queryParameters: at == null ? null : {'at': at.toUtc().toIso8601String()},
  ).toString();

  final String eventId;

  /// The occurrence shown: its original start, a UTC instant.
  final DateTime? at;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EventPayload e,
    CalendarEvent? event,
  ) async {
    final l10n = context.l10n;
    final at = this.at;
    final repeating = e.rule != null && at != null && event != null;
    final scope = repeating
        ? await askEditScope(context, removing: true)
        : await _confirmDelete(context, e)
        ? EditScope.series
        : null;
    if (scope == null || !context.mounted) return;

    final store = await ref.read(familyStoreProvider.future);
    // The undo outlives this screen, so nothing it uses may come from `ref`.
    final sync = ref.read(syncControllerProvider.notifier);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (scope) {
      case EditScope.occurrence:
        final exceptionId = EventExceptionPayload.idFor(eventId, at!);
        final previous = await store.payloadOf(exceptionId);
        await store.saveException(
          EventExceptionPayload.write(
            existing: previous == null
                ? null
                : Payload.decode(previous.encode()),
            eventId: eventId,
            originalStart: at,
            type: ExceptionType.cancelled,
          ),
          visibility: e.visibility,
        );
        // A cancelled occurrence leaves the calendar, so undo is here or
        // nowhere.
        messenger.showSnackBar(
          SnackBar(
            // An undo is a moment's offer, not a standing one.
            persist: false,
            content: Text(
              l10n.occurrenceCancelled(
                e.title,
                DateFormat('EEEE d MMMM').format(wallClock(at, e.timeZone)),
              ),
            ),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () async {
                if (previous == null) {
                  await store.delete(ObjectKind.eventException, exceptionId);
                } else {
                  await store.saveException(
                    EventExceptionPayload.read(previous),
                    visibility: e.visibility,
                  );
                }
                sync.syncNow();
              },
            ),
          ),
        );
      case EditScope.thisAndAfter when hasOccurrenceBefore(event!.series, at!):
        // Undo puts the series back exactly as it was.
        final before = Payload.decode(e.payload.encode());
        await endSeriesBefore(store, eventId, e.payload, at);
        messenger.showSnackBar(
          SnackBar(
            // An undo is a moment's offer, not a standing one.
            persist: false,
            content: Text(
              l10n.seriesEnded(
                e.title,
                DateFormat('d MMMM').format(wallClock(at, e.timeZone)),
              ),
            ),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () async {
                await store.saveEvent(EventPayload.read(before), id: eventId);
                sync.syncNow();
              },
            ),
          ),
        );
      case EditScope.thisAndAfter || EditScope.series:
        // Recently deleted for 30 days; undo here is the quick way back.
        await store.softDeleteEvent(eventId);
        messenger.showSnackBar(
          SnackBar(
            // An undo is a moment's offer, not a standing one.
            persist: false,
            content: Text(l10n.eventRemoved(e.title)),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () async {
                await store.restoreEvent(eventId);
                sync.syncNow();
              },
            ),
          ),
        );
    }
    sync.syncNow();
    if (context.mounted) context.pop();
  }

  Future<bool> _confirmDelete(BuildContext context, EventPayload e) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEventTitle(e.title)),
        content: Text(
          e.rule == null ? l10n.deleteEventOnce : l10n.deleteEventSeries,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _edit(BuildContext context, EventPayload e) async {
    final at = this.at;
    final scope = e.rule != null && at != null
        ? await askEditScope(context, removing: false)
        : EditScope.series;
    if (scope == null || !context.mounted) return;
    await context.push(
      NewEventScreen.editPathFor(eventId, scope: scope, at: at),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(eventPayloadProvider(eventId));
    final events = ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
    final event = events.where((x) => x.id == eventId).firstOrNull;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final colors = {
      for (final (i, m) in members.indexed) m.id: MemberStyle.colorOf(m, i),
    };
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final at = this.at;
    final exception = at == null
        ? null
        : event?.series.exceptions
              .where((x) => x.originalStart == at)
              .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (payload.value case final e?) ...[
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, e),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, e, event),
            ),
          ],
        ],
      ),
      body: switch (payload) {
        AsyncValue(value: final e?) => () {
          final responsibleId =
              exception?.overrideResponsibleMemberId ?? e.responsibleMemberId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                exception?.overrideTitle ?? e.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  decoration: e.status == EventStatus.cancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _Line(icon: Icons.schedule, text: _when(e, at, exception)),
              if (e.rule case final rule?)
                _Line(icon: Icons.repeat, text: describeRule(l10n, rule)),
              if (exception != null)
                _Line(
                  icon: Icons.edit_calendar_outlined,
                  text: exception.overrideStart == null
                      ? l10n.changedThisTime
                      : l10n.movedFrom(
                          DateFormat('EEEE d MMMM HH:mm')
                              .format(wallClock(at!, e.timeZone)),
                        ),
                ),
              if (e.location case final place?)
                _Line(icon: Icons.place_outlined, text: place),
              for (final r in e.reminders)
                _Line(
                  icon: Icons.notifications_none,
                  text: describeLead(l10n, r.minutesBefore),
                ),
              if (e.visibility == EventVisibility.parentsOnly)
                _Line(icon: Icons.lock_outline, text: l10n.parentsOnlyNote),
              const Divider(height: 32),
              Text(l10n.whosGoing, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (e.participantIds.isEmpty)
                Text(l10n.wholeFamily)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in e.participantIds)
                      if (byId[id] case final m?)
                        Chip(
                          avatar: CircleAvatar(backgroundColor: colors[m.id]),
                          label: Text(m.displayName),
                        ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(l10n.responsible, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                byId[responsibleId]?.displayName ?? l10n.noOneYet,
                style: byId[responsibleId] == null
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
              if (e.notes case final notes? when notes.isNotEmpty) ...[
                const Divider(height: 32),
                Text(notes),
              ],
            ],
          );
        }(),
        AsyncValue(isLoading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => Center(child: Text(l10n.eventGone)),
      },
    );
  }

  /// The occurrence's own time when one was opened, else the series' first.
  static String _when(EventPayload e, DateTime? at, ExceptionEntry? ex) {
    final DateTime start;
    if (at != null) {
      start = wallClock(ex?.overrideStart ?? at, e.timeZone);
    } else {
      start = e.localStart!;
    }
    final end = start.add(ex?.overrideDuration ?? e.duration);
    final time = DateFormat('HH:mm');
    return '${DateFormat('EEEE d MMMM').format(start)}, '
        '${time.format(start)}–${time.format(end)}';
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
