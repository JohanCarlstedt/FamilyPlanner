import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';

import '../../common/l10n.dart';
import 'week_providers.dart';
import 'week_selection.dart';

/// Removing several things at once.
///
/// Clearing a cancelled tournament weekend used to mean opening six
/// events and answering the same question six times. Picked out together,
/// they go together.
///
/// Two rules it will not bend on:
///
/// - **A repeating event loses only the day that was picked**, never the
///   series. Someone sweeping a week clear did not mean to end football
///   until June, and a bulk action is the worst possible place to find
///   out otherwise.
/// - **Only what this person may remove.** The permission is the same one
///   the event's own screen applies; picking things out in a list does
///   not become a way around it.
class RemoveMany {
  const RemoveMany._();

  /// What is picked, resolved back to entries. Anything that has since
  /// disappeared — synced away, already removed elsewhere — is simply not
  /// there any more, which is the right answer.
  static List<AgendaEntry> picked(WeekState state, Set<String> keys) => [
    for (final day in state.agenda.days)
      for (final entry in day.entries)
        if (keys.contains(WeekSelection.keyFor(entry))) entry,
  ];

  /// Those the person may actually remove.
  static List<AgendaEntry> allowed(
    List<AgendaEntry> entries,
    Permissions permissions,
    Map<String, Payload> payloads,
  ) => [
    for (final e in entries)
      if (permissions.editEvent(
        e.event,
        createdBy: payloads[e.event.id]?.createdBy,
      ))
        e,
  ];

  /// Removes them, and returns how to put them back.
  ///
  /// The undo is collected as it goes rather than worked out afterwards:
  /// what a removal displaced is known at the moment of removing and
  /// nowhere else.
  static Future<Future<void> Function()> remove(
    FamilyStore store,
    List<AgendaEntry> entries,
  ) async {
    final undos = <Future<void> Function()>[];

    for (final entry in entries) {
      final id = entry.event.id;
      final existing = await store.payloadOf(id);
      if (existing == null) continue;
      final payload = EventPayload.read(existing);

      if (payload.rule == null) {
        final before = Payload.decode(existing.encode());
        await store.delete(ObjectKind.event, id);
        undos.add(() => store.saveEvent(EventPayload.read(before)));
        continue;
      }

      // Repeating: the picked day only.
      final at = entry.occurrence.originalStart;
      final exceptionId = EventExceptionPayload.idFor(id, at);
      final previous = await store.payloadOf(exceptionId);
      await store.saveException(
        EventExceptionPayload.write(
          existing: previous == null ? null : Payload.decode(previous.encode()),
          eventId: id,
          originalStart: at,
          type: ExceptionType.cancelled,
        ),
        visibility: payload.visibility,
      );
      undos.add(() async {
        if (previous == null) {
          await store.delete(ObjectKind.eventException, exceptionId);
        } else {
          await store.saveException(
            EventExceptionPayload.read(previous),
            visibility: payload.visibility,
          );
        }
      });
    }

    return () async {
      for (final undo in undos) {
        await undo();
      }
    };
  }

  /// Asks first, saying plainly what a repeating one will lose.
  static Future<bool> confirm(
    BuildContext context,
    List<AgendaEntry> entries,
  ) async {
    final l10n = context.l10n;
    final repeating = entries.where((e) => e.event.series.rule != null).length;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.removeManyTitle(entries.length)),
            content: Text(
              repeating == 0
                  ? l10n.removeManyBody
                  : l10n.removeManyBodyRepeating(repeating),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.removeItem),
              ),
            ],
          ),
        ) ??
        false;
  }
}
