import 'calendar_event.dart';
import 'recurrence.dart';

/// Spec §3 `action.kind`.
/// What kind of task. An activity is being physically active: an
/// activity from the calendar attended, or time outside logged.
enum ActionKind { chore, prep, errand, admin, activity }

/// Spec §3 `action_template`: recurring prep on an event ("wash the kit two
/// days before each match"), or a chore on its own [schedule] ("bins out
/// every other Tuesday"). Instances are planned from it a window ahead.
class ActionTemplate {
  const ActionTemplate({
    required this.id,
    required this.title,
    this.kind = ActionKind.chore,
    this.offsetMinutes = 0,
    this.eventId,
    this.schedule,
    this.assignee,
    this.rotateAmong = const [],
    this.blocking = false,
  });

  final String id;
  final String title;
  final ActionKind kind;

  /// Due this long after the occurrence starts; negative lands before.
  final int offsetMinutes;

  /// The event it prepares for; null for a chore on its own [schedule].
  final String? eventId;
  final EventSeries? schedule;

  /// Who it goes to when nobody rotates; null leaves it in the family pool.
  final String? assignee;

  /// Turns taken by occurrence, deterministically, so everyone can see
  /// whose turn is next.
  final List<String> rotateAmong;

  /// The event can't happen without it.
  final bool blocking;
}

/// One action a template calls for.
class PlannedAction {
  const PlannedAction({
    required this.templateId,
    required this.occurrenceStart,
    required this.dueAt,
    required this.assignee,
    required this.cancelled,
  });

  final String templateId;

  /// The occurrence as the unmodified series has it: its identity.
  final DateTime occurrenceStart;
  final DateTime dueAt;
  final String? assignee;

  /// Its occurrence (or the whole event) was cancelled: so is the action,
  /// by the rule that governs reminders too (CLAUDE.md invariant 6).
  final bool cancelled;

  /// The same on every device, so any of them can create it once.
  String get key => '$templateId/${occurrenceStart.toUtc().toIso8601String()}';
}

/// The actions [template] calls for, one per occurrence starting between
/// [from] and [until] (spec §3: generated a window ahead, never the whole
/// season).
/// Prep needs its [event]; without it, nothing is planned.
List<PlannedAction> planActions({
  required ActionTemplate template,
  CalendarEvent? event,
  required DateTime from,
  required DateTime until,
  RecurrenceExpander expander = const RecurrenceExpander(),
}) {
  final series = template.eventId == null ? template.schedule : event?.series;
  if (series == null) return const [];
  final plain = EventSeries(
    eventId: series.eventId,
    localStart: series.localStart,
    duration: series.duration,
    timeZone: series.timeZone,
    rule: series.rule,
    recurrenceUntil: series.recurrenceUntil,
  );
  final offset = Duration(minutes: template.offsetMinutes);
  // Occurrences in the window, even if their prep is already overdue: the
  // kit still needs washing before Saturday.
  final original = expander.expand(plain, from, until);
  if (original.isEmpty) return const [];
  final actual = {
    for (final o in expander.expand(
      series,
      from.subtract(const Duration(days: 60)),
      until.add(const Duration(days: 60)),
    ))
      o.originalStart.toUtc(): o,
  };
  // Turns count from the first occurrence of the unmodified series.
  final before = template.rotateAmong.isEmpty
      ? 0
      : expander
          .expand(
            plain,
            DateTime.utc(1970),
            original.first.originalStart.subtract(const Duration(seconds: 1)),
          )
          .length;
  final eventCancelled = event?.isCancelled ?? false;
  return [
    for (final (i, o) in original.indexed)
      () {
        final now = actual[o.originalStart.toUtc()];
        return PlannedAction(
          templateId: template.id,
          occurrenceStart: o.originalStart.toUtc(),
          dueAt: (now?.start ?? o.start).toUtc().add(offset),
          assignee: template.rotateAmong.isEmpty
              ? template.assignee
              : template
                  .rotateAmong[(before + i) % template.rotateAmong.length],
          cancelled: eventCancelled || now == null,
        );
      }(),
  ];
}
