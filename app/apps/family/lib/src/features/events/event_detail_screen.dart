import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import 'new_event_screen.dart';

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

/// Spec §10 screen 3, first cut: what, when, where, who, and who's
/// responsible, with edit and delete. Recurring events are edited as a whole
/// series until exceptions are stored (this occurrence / this and future).
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  static const path = '/event/:id';

  static String pathFor(String id) => '/event/$id';

  final String eventId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EventPayload e,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${e.title}"?'),
        content: Text(
          e.rule == null
              ? 'It disappears for the whole family.'
              : 'Every occurrence disappears for the whole family.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.delete(ObjectKind.event, eventId);
    ref.read(syncControllerProvider.notifier).syncNow();
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventPayloadProvider(eventId));
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final colors = {
      for (final (i, m) in members.indexed) m.id: MemberStyle.colorOf(m, i),
    };
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (event.value case final e?) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(NewEventScreen.editPathFor(eventId)),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, e),
            ),
          ],
        ],
      ),
      body: switch (event) {
        AsyncValue(value: final e?) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              e.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                decoration: e.status == EventStatus.cancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _Line(icon: Icons.schedule, text: _when(e)),
            if (e.rule case final rule?)
              _Line(icon: Icons.repeat, text: _repeats(rule)),
            if (e.location case final place?)
              _Line(icon: Icons.place_outlined, text: place),
            if (e.visibility == EventVisibility.parentsOnly)
              const _Line(
                icon: Icons.lock_outline,
                text: "Parents only: children's devices get no readable copy",
              ),
            const Divider(height: 32),
            Text("Who's going", style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (e.participantIds.isEmpty)
              const Text('The whole family')
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
            Text('Responsible', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              byId[e.responsibleMemberId]?.displayName ?? 'No one yet',
              style: byId[e.responsibleMemberId] == null
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
            if (e.notes case final notes? when notes.isNotEmpty) ...[
              const Divider(height: 32),
              Text(notes),
            ],
          ],
        ),
        AsyncValue(isLoading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => const Center(child: Text('This event is no longer here.')),
      },
    );
  }

  static String _when(EventPayload e) {
    final start = e.localStart!;
    final end = start.add(e.duration);
    final time = DateFormat('HH:mm');
    return '${DateFormat('EEEE d MMMM').format(start)}, '
        '${time.format(start)}–${time.format(end)}';
  }

  static String _repeats(RecurrenceRule rule) => switch (rule.frequency) {
    Frequency.weekly when rule.byWeekday.isNotEmpty =>
      'Every week on ${[for (final d in rule.byWeekday) _weekdayName(d)].join(', ')}',
    Frequency.daily => 'Every day',
    Frequency.weekly => 'Every week',
    Frequency.monthly => 'Every month',
    Frequency.yearly => 'Every year',
  };

  static String _weekdayName(Weekday d) =>
      DateFormat('EEEE').format(DateTime(2026, 9, 14 + d.index));
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
