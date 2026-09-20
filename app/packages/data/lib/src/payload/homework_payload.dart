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
