import 'package:domain/domain.dart';

import 'event_payload.dart';
import 'payload.dart';

enum ActionState { open, done, approved, skipped, cancelled }

/// One step in an action's story (spec §3 "Delegation": "I thought you were
/// doing it" should be answered by what's recorded, not remembered).
class ActionStep {
  const ActionStep({
    required this.what,
    required this.by,
    required this.at,
    this.to,
    this.note,
  });

  /// `created`, `assigned`, `claimed`, `unclaimed`, `delegated`, `accepted`,
  /// `declined`, `done`, `approved`, `reopened`, `skipped`.
  final String what;
  final String by;
  final String? to;
  final DateTime at;
  final String? note;

  Payload toPayload() => Payload.map()
    ..setText('what', what)
    ..setText('by', by)
    ..setText('to', to)
    ..setText('at', at.toUtc().toIso8601String())
    ..setText('note', note);

  static ActionStep read(Payload p) => ActionStep(
    what: p.text('what') ?? '',
    by: p.text('by') ?? '',
    to: p.text('to'),
    at: DateTime.tryParse(p.text('at') ?? '') ?? DateTime.utc(1970),
    note: p.text('note'),
  );
}

/// An asked-for handover (spec §3 "Delegation"): the action stays with
/// [from] until [to] accepts.
class Delegation {
  const Delegation({required this.from, required this.to, this.note});

  final String from;
  final String to;
  final String? note;
}

/// A thing that needs doing (spec §3 `action`, kind 3): a chore, prep for
/// an event, an errand. Unassigned, it's in the family pool.
/// The most seeds one chore can be worth.
const maxWorth = 3;

class ActionPayload {
  ActionPayload._(this.payload);

  static const version = 1;

  factory ActionPayload.read(Payload payload) => ActionPayload._(payload);

  factory ActionPayload.write({
    Payload? existing,
    required String title,
    ActionKind kind = ActionKind.chore,
    String? description,
    String? eventId,
    DateTime? occurrenceStart,
    String? templateId,
    String? assignedTo,
    List<String> alsoAssigned = const [],
    DateTime? dueAt,
    bool blocking = false,
    bool requiresApproval = false,
    int? worth,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setText('kind', kind.name)
      ..setText('description', description)
      ..setText('event', eventId)
      ..setText('occurrence', occurrenceStart?.toUtc().toIso8601String())
      ..setText('template', templateId)
      ..setText('assigned', assignedTo)
      // The others it is given to, beside the first. A version that knows
      // only one sees it as the first one's; this one as everyone's.
      ..setTexts('with', [
        for (final m in alsoAssigned)
          if (m != assignedTo) m,
      ])
      ..setText('due', dueAt?.toUtc().toIso8601String())
      ..setBoolean('blocking', blocking)
      ..setBoolean('approval', requiresApproval);
    // Left as it was unless given: editing a chore's title keeps its worth.
    if (worth != null) p.setInteger('worth', worth <= 1 ? null : worth);
    if (existing == null) p.setText('state', ActionState.open.name);
    return ActionPayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  ActionKind get kind =>
      ActionKind.values.asNameMap()[payload.text('kind')] ?? ActionKind.chore;
  String? get description => payload.text('description');
  String? get eventId => payload.text('event');
  DateTime? get occurrenceStart =>
      DateTime.tryParse(payload.text('occurrence') ?? '');
  String? get templateId => payload.text('template');

  /// Null: the family pool. The first of [assignees].
  String? get assignedTo => payload.text('assigned');

  /// Everyone it is given to: one, several doing it together, or nobody
  /// (the family pool). Done by any of them, it is done, and counts for
  /// all of them.
  List<String> get assignees => [
    ?assignedTo,
    if (assignedTo != null)
      for (final m in payload.texts('with') ?? const <String>[])
        if (m != assignedTo) m,
  ];

  /// Whether [member] is one of those it is given to.
  bool isFor(String? member) => member != null && assignees.contains(member);

  /// Given to more than one, to do together.
  bool get shared => assignees.length > 1;
  DateTime? get dueAt => DateTime.tryParse(payload.text('due') ?? '');
  bool get blocking => payload.boolean('blocking') ?? false;
  bool get requiresApproval => payload.boolean('approval') ?? false;

  /// Seeds it grows a child's city by, from 1 to [maxWorth]: a parent
  /// can make a big job count for more. Beyond the range, the nearest.
  int get worth => (payload.integer('worth') ?? 1).clamp(1, maxWorth);
  ActionState get state =>
      ActionState.values.asNameMap()[payload.text('state')] ?? ActionState.open;
  String? get completedBy => payload.text('completedBy');
  DateTime? get completedAt =>
      DateTime.tryParse(payload.text('completedAt') ?? '');

  /// Done, but a parent is still to confirm it.
  bool get awaitingApproval => state == ActionState.done && requiresApproval;

  /// The parent who has seen it done, or null. Not approval: a chore that
  /// asks for none is finished on the child's word, and this only says a
  /// grown-up noticed. Cleared when it is reopened, so done again is new.
  String? get seenBy => payload.text('seenBy');
  DateTime? get seenAt => DateTime.tryParse(payload.text('seenAt') ?? '');

  bool get isOpen => state == ActionState.open;

  Delegation? get delegation => switch (payload.nested('delegation')) {
    final d? => Delegation(
      from: d.text('from') ?? '',
      to: d.text('to') ?? '',
      note: d.text('note'),
    ),
    null => null,
  };

  List<ActionStep> get history => [
    for (final s in payload.nestedList('history') ?? const <Payload>[])
      ActionStep.read(s),
  ];

  /// A copy with [changes] applied and [step] added to its history.
  ActionPayload next(
    ActionStep step, {
    ActionState? state,
    String? assignedTo,
    bool unassign = false,
    String? leaving,
    DateTime? dueAt,
    String? completedBy,
    DateTime? completedAt,
    bool clearCompletion = false,
    String? seenBy,
    DateTime? seenAt,
    Delegation? delegation,
    bool clearDelegation = false,
  }) {
    final p = Payload.decode(payload.encode());
    if (state != null) p.setText('state', state.name);
    if (unassign) {
      p
        ..setText('assigned', null)
        ..setTexts('with', const []);
    }
    if (assignedTo != null) {
      p
        ..setText('assigned', assignedTo)
        ..setTexts('with', const []);
    }
    // One of several steps out; the rest keep it. The last one out puts
    // it back in the pool.
    if (leaving != null) {
      final rest = [
        for (final m in assignees)
          if (m != leaving) m,
      ];
      p
        ..setText('assigned', rest.firstOrNull)
        ..setTexts('with', rest.skip(1).toList());
    }
    if (dueAt != null) p.setText('due', dueAt.toUtc().toIso8601String());
    if (clearCompletion) {
      p
        ..setText('completedBy', null)
        ..setText('completedAt', null)
        ..setText('seenBy', null)
        ..setText('seenAt', null);
    }
    if (seenBy != null) p.setText('seenBy', seenBy);
    if (seenAt != null) p.setText('seenAt', seenAt.toUtc().toIso8601String());
    if (completedBy != null) p.setText('completedBy', completedBy);
    if (completedAt != null) {
      p.setText('completedAt', completedAt.toUtc().toIso8601String());
    }
    if (clearDelegation) p.setNested('delegation', null);
    if (delegation != null) {
      p.setNested(
        'delegation',
        Payload.map()
          ..setText('from', delegation.from)
          ..setText('to', delegation.to)
          ..setText('note', delegation.note),
      );
    }
    p.setNestedList('history', [
      for (final s in history) s.toPayload(),
      step.toPayload(),
    ]);
    return ActionPayload._(p);
  }
}

/// Recurring prep or a chore (spec §3 `action_template`, kind 21). A
/// chore's own schedule is kept as an event would be, so it repeats by the
/// same rules.
class ActionTemplatePayload {
  ActionTemplatePayload._(this.payload);

  static const version = 1;

  factory ActionTemplatePayload.read(Payload payload) =>
      ActionTemplatePayload._(payload);

  factory ActionTemplatePayload.write({
    Payload? existing,
    required String title,
    ActionKind kind = ActionKind.chore,
    int offsetMinutes = 0,
    String? eventId,
    EventPayload? schedule,
    String? assignee,
    List<String> rotateAmong = const [],
    bool blocking = false,
    bool requiresApproval = false,
    bool paused = false,
    int? worth,
    bool together = false,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setText('kind', kind.name)
      ..setInteger('offset', offsetMinutes)
      ..setText('event', eventId)
      ..setNested('schedule', schedule?.payload)
      ..setText('assignee', assignee)
      ..setTexts('rotate', rotateAmong)
      ..setBoolean('blocking', blocking)
      ..setBoolean('approval', requiresApproval)
      ..setBoolean('paused', paused)
      ..setBoolean('together', together ? true : null);
    if (worth != null) p.setInteger('worth', worth <= 1 ? null : worth);
    return ActionTemplatePayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  ActionKind get kind =>
      ActionKind.values.asNameMap()[payload.text('kind')] ?? ActionKind.chore;
  int get offsetMinutes => payload.integer('offset') ?? 0;
  String? get eventId => payload.text('event');
  EventPayload? get schedule => switch (payload.nested('schedule')) {
    final s? => EventPayload.read(s),
    null => null,
  };
  String? get assignee => payload.text('assignee');
  List<String> get rotateAmong => payload.texts('rotate') ?? const [];
  bool get blocking => payload.boolean('blocking') ?? false;
  bool get requiresApproval => payload.boolean('approval') ?? false;

  /// Everyone in [rotateAmong] does it together each time, rather than
  /// taking turns.
  bool get together => payload.boolean('together') ?? false;

  /// What each chore it makes is worth: see [ActionPayload.worth].
  int get worth => (payload.integer('worth') ?? 1).clamp(1, maxWorth);

  /// Generation switched off (spec §3 "the overload trap").
  bool get paused => payload.boolean('paused') ?? false;

  ActionTemplate toDomain(String id) => ActionTemplate(
    id: id,
    title: title,
    kind: kind,
    offsetMinutes: offsetMinutes,
    eventId: eventId,
    schedule: schedule?.toDomain(id)?.series,
    assignee: assignee,
    rotateAmong: rotateAmong,
    blocking: blocking,
  );
}
