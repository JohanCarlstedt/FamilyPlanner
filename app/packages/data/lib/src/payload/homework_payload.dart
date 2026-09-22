import 'package:domain/domain.dart';

import 'event_payload.dart';
import 'payload.dart';

/// One of a child's school subjects (spec §3 `subject`, kind 23): per child,
/// since siblings are in different years.
class SubjectPayload {
  SubjectPayload._(this.payload);

  static const version = 1;

  factory SubjectPayload.read(Payload payload) => SubjectPayload._(payload);

  factory SubjectPayload.write({
    Payload? existing,
    required String memberId,
    required String name,
    String? color,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', memberId)
      ..setText('name', name)
      ..setText('color', color);
    return SubjectPayload._(p);
  }

  final Payload payload;

  String get memberId => payload.text('member') ?? '';
  String get name => payload.text('name') ?? '';
  String? get color => payload.text('color');
}

/// A time set aside to work on homework: a `homework` event in the
/// calendar (spec §3 `homework_session`).
class HomeworkSession {
  const HomeworkSession({
    required this.eventId,
    required this.minutes,
    this.done = false,
  });

  final String eventId;
  final int minutes;
  final bool done;

  Payload toPayload() => Payload.map()
    ..setText('event', eventId)
    ..setInteger('minutes', minutes)
    ..setBoolean('done', done);

  static HomeworkSession read(Payload p) => HomeworkSession(
    eventId: p.text('event') ?? '',
    minutes: p.integer('minutes') ?? 0,
    done: p.boolean('done') ?? false,
  );
}

/// Homework (spec §3 `homework`, kind 9). No grades, ever: due dates and
/// whether it's done are the useful part.
class HomeworkPayload {
  HomeworkPayload._(this.payload);

  static const version = 1;

  factory HomeworkPayload.read(Payload payload) => HomeworkPayload._(payload);

  factory HomeworkPayload.write({
    Payload? existing,
    required String memberId,
    required String title,
    String? subjectId,
    String? description,
    HomeworkType type = HomeworkType.assignment,
    required DateTime dueAt,
    int? estimatedMinutes,
    String source = 'parent',
    String? responsibleMemberId,
    bool clearResponsible = false,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', memberId)
      ..setText('title', title)
      ..setText('subject', subjectId)
      ..setText('description', description)
      ..setText('type', type.name)
      ..setText('due', dueAt.toUtc().toIso8601String())
      ..setInteger('estimate', estimatedMinutes)
      ..setText('source', source);
    // Additive, and only written when it is being changed: a rewrite that
    // did not mention it would otherwise silently drop whoever had
    // already said they would sit down with it (invariant 3).
    if (clearResponsible) {
      p.setText('responsible', null);
    } else if (responsibleMemberId != null) {
      p.setText('responsible', responsibleMemberId);
    }
    if (existing == null) p.setText('state', HomeworkState.notStarted.name);
    return HomeworkPayload._(p);
  }

  final Payload payload;

  String get memberId => payload.text('member') ?? '';
  String get title => payload.text('title') ?? '';
  String? get subjectId => payload.text('subject');
  String? get description => payload.text('description');
  HomeworkType get type =>
      HomeworkType.values.asNameMap()[payload.text('type')] ??
      HomeworkType.assignment;
  DateTime? get dueAt => DateTime.tryParse(payload.text('due') ?? '');
  int? get estimatedMinutes => payload.integer('estimate');

  /// Who is seeing to it that this gets done — the adult who will sit
  /// down with the glosor, not the child whose homework it is.
  ///
  /// The same word the calendar already uses for an event, and for the
  /// same reason: "somebody will" is how a Thursday test becomes a
  /// Thursday morning.
  String? get responsibleMemberId => payload.text('responsible');
  HomeworkState get state =>
      HomeworkState.values.asNameMap()[payload.text('state')] ??
      HomeworkState.notStarted;
  List<HomeworkSession> get sessions => [
    for (final s in payload.nestedList('sessions') ?? const <Payload>[])
      HomeworkSession.read(s),
  ];

  bool get finished =>
      state == HomeworkState.done || state == HomeworkState.handedIn;

  /// Derived, never stored (spec §3).
  bool overdueAt(DateTime now) => !finished && (dueAt?.isBefore(now) ?? false);

  HomeworkPayload withState(HomeworkState state) => HomeworkPayload._(
    Payload.decode(payload.encode())..setText('state', state.name),
  );

  HomeworkPayload withSessions(List<HomeworkSession> sessions) =>
      HomeworkPayload._(
        Payload.decode(
          payload.encode(),
        )..setNestedList('sessions', [for (final s in sessions) s.toPayload()]),
      );
}

/// Homework that comes back every week (kind 29): glosor every Friday, a
/// reading log every Monday. It plans an ordinary `homework` object per
/// week, each done or not on its own — see HomeworkTemplate in domain for
/// why that rather than a recurrence on the homework itself.
///
/// The schedule is kept as an event would be, so it repeats by exactly the
/// same rules as everything else in the calendar.
class HomeworkTemplatePayload {
  HomeworkTemplatePayload._(this.payload);

  static const version = 1;

  factory HomeworkTemplatePayload.read(Payload payload) =>
      HomeworkTemplatePayload._(payload);

  factory HomeworkTemplatePayload.write({
    Payload? existing,
    required String memberId,
    required String title,
    required EventPayload schedule,
    String? subjectId,
    String? description,
    HomeworkType type = HomeworkType.assignment,
    int? estimatedMinutes,
    bool paused = false,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', memberId)
      ..setText('title', title)
      ..setNested('schedule', schedule.payload)
      ..setText('subject', subjectId)
      ..setText('description', description)
      ..setText('type', type.name)
      ..setInteger('estimate', estimatedMinutes)
      ..setBoolean('paused', paused);
    return HomeworkTemplatePayload._(p);
  }

  final Payload payload;

  String get memberId => payload.text('member') ?? '';
  String get title => payload.text('title') ?? '';
  EventPayload? get schedule => switch (payload.nested('schedule')) {
    final s? => EventPayload.read(s),
    null => null,
  };
  String? get subjectId => payload.text('subject');
  String? get description => payload.text('description');
  HomeworkType get type =>
      HomeworkType.values.asNameMap()[payload.text('type')] ??
      HomeworkType.assignment;
  int? get estimatedMinutes => payload.integer('estimate');

  /// Stopped: the weeks already planned stay, no new ones arrive. What a
  /// term ending looks like.
  bool get paused => payload.boolean('paused') ?? false;

  HomeworkTemplate? toDomain(String id) => switch (schedule?.toDomain(id)) {
    final event? => HomeworkTemplate(
      id: id,
      memberId: memberId,
      title: title,
      schedule: event.series,
      subjectId: subjectId,
      description: description,
      type: type,
      estimatedMinutes: estimatedMinutes,
    ),
    null => null,
  };
}

/// A school's week overview, kept so it can be looked at again (kind 30).
///
/// Most schools publish one document a week — a veckoöversikt or veckobrev
/// — at an address that does not change. Saving it turns a paste-it-every-
/// Sunday chore into a button, and lets the app offer the new week's
/// homework when it appears.
///
/// Not every family has one. A school that sends the letter by email, or
/// writes it on a whiteboard, is served by the other ways in: share the
/// document, paste the text, photograph the board. This is the convenience
/// for the schools that publish, not the only route.
class WeekPlanLinkPayload {
  WeekPlanLinkPayload._(this.payload);

  static const version = 1;

  factory WeekPlanLinkPayload.read(Payload payload) =>
      WeekPlanLinkPayload._(payload);

  factory WeekPlanLinkPayload.write({
    Payload? existing,
    required String memberId,
    required String url,
    String? group,
    String? name,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('member', memberId)
      ..setText('url', url)
      ..setText('group', group)
      ..setText('name', name);
    return WeekPlanLinkPayload._(p);
  }

  final Payload payload;

  /// Whose plan it is: one child's class, not the family's.
  String get memberId => payload.text('member') ?? '';

  String get url => payload.text('url') ?? '';

  /// The row in the table that is theirs — "5A". Null until someone picks.
  String? get group => payload.text('group');

  /// What to call it: "Önnerödsskolan åk 5".
  String? get name => payload.text('name');

  WeekPlanLinkPayload withGroup(String group) => WeekPlanLinkPayload._(
    Payload.decode(payload.encode())..setText('group', group),
  );
}
