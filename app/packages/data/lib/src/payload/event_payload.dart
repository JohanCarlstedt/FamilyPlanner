import 'package:domain/domain.dart';
import 'package:uuid/uuid.dart';

import 'payload.dart';

/// Visibility of an event (spec §3), mapped to audiences in crypto doc §6.
enum EventVisibility {
  /// Everyone in the family: wrapped to `all`.
  family,

  /// Parents only: wrapped to `adults`. Enforced cryptographically.
  parentsOnly,
}

/// Schema of an event's payload. v1 stores recurrence as a structured map
/// rather than an RRULE string: the domain engine works on the structure, and
/// RRULE import and export can come later without touching stored data.
class EventPayload {
  EventPayload._(this.payload);

  /// This client's schema version for events.
  static const version = 1;

  /// Reads an event from a decoded payload.
  factory EventPayload.read(Payload payload) => EventPayload._(payload);

  /// A new event, or an edit of [existing] that keeps its unknown fields.
  factory EventPayload.write({
    Payload? existing,
    required String title,
    required EventKind kind,
    required DateTime localStart,
    required Duration duration,
    required String timeZone,
    EventStatus status = EventStatus.confirmed,
    EventVisibility visibility = EventVisibility.family,
    RecurrenceRule? rule,
    List<String> participantIds = const [],
    String? responsibleMemberId,
    String? location,
    String? placeId,
    String? notes,
    List<EventReminder> reminders = const [],
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setText('kind', kind.name)
      ..setText('status', status.name)
      ..setText('visibility', visibility.name)
      ..setText('start', _localIso(localStart))
      ..setInteger('minutes', duration.inMinutes)
      ..setText('tz', timeZone)
      ..setTexts('participants', participantIds)
      ..setText('responsible', responsibleMemberId)
      ..setText('location', location)
      ..setText('place', placeId)
      ..setText('notes', notes);
    p.setNested('rule', rule == null ? null : _writeRule(rule));
    p.setNestedList('reminders', [
      for (final r in reminders)
        Payload.map()
          ..setInteger('minutes', r.minutesBefore)
          ..setText('target', r.target.name),
    ]);
    return EventPayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';

  EventKind get kind =>
      _byName(EventKind.values, payload.text('kind')) ?? EventKind.appointment;

  EventStatus get status =>
      _byName(EventStatus.values, payload.text('status')) ??
      EventStatus.confirmed;

  EventVisibility get visibility =>
      _byName(EventVisibility.values, payload.text('visibility')) ??
      EventVisibility.family;

  /// Wall-clock start in [timeZone], as `DateTime.utc` fields.
  DateTime? get localStart => _parseLocal(payload.text('start'));

  Duration get duration => Duration(minutes: payload.integer('minutes') ?? 60);

  String get timeZone => payload.text('tz') ?? 'Europe/Stockholm';

  List<String> get participantIds => payload.texts('participants') ?? const [];

  String? get responsibleMemberId => payload.text('responsible');

  /// Where it happens, as text: the place's name when [placeId] is set, so
  /// a device that can't find the place still says where.
  String? get location => payload.text('location');

  String? get placeId => payload.text('place');

  String? get notes => payload.text('notes');

  /// Kit lists for every occurrence (spec §3: on the master event).
  List<String> get equipmentSets => payload.texts('equipment') ?? const [];

  /// Be there this many minutes before the start; set by a calendar feed's
  /// meeting time.
  int? get meetMinutesBefore => payload.integer('meet');

  /// When the event was put in the family's recently deleted list, or null.
  /// A soft delete lives in the payload, so the server can't tell a deleted
  /// event from any other.
  DateTime? get deletedAt => _parseInstant(payload.text('deletedAt'));

  bool get isDeleted => deletedAt != null;

  /// Marks the event deleted at [when], or restores it with null. Nothing
  /// else about it changes.
  void setDeletedAt(DateTime? when) =>
      payload.setText('deletedAt', when == null ? null : _instantIso(when));

  /// Spec §8 `event_reminder`. A reminder too damaged to schedule is dropped.
  List<EventReminder> get reminders => [
    for (final r in payload.nestedList('reminders') ?? const <Payload>[])
      if (r.integer('minutes') case final minutes? when minutes >= 0)
        EventReminder(
          minutesBefore: minutes,
          target:
              _byName(ReminderTarget.values, r.text('target')) ??
              ReminderTarget.participants,
        ),
  ];

  RecurrenceRule? get rule {
    final r = payload.nested('rule');
    if (r == null) return null;
    final frequency = _byName(Frequency.values, r.text('freq'));
    if (frequency == null) return null;
    return RecurrenceRule(
      frequency: frequency,
      interval: r.integer('interval') ?? 1,
      byWeekday: {
        for (final d in r.texts('byWeekday') ?? const <String>[])
          ?_byName(Weekday.values, d),
      },
      byMonthDay: r.integer('byMonthDay'),
      byMonth: r.integer('byMonth'),
      until: _parseLocal(r.text('until')),
      count: r.integer('count'),
      skip:
          _byName(RecurrenceSkip.values, r.text('skip')) ?? RecurrenceSkip.omit,
    );
  }

  /// The domain view, or null if the payload is too damaged to schedule.
  CalendarEvent? toDomain(String id) {
    final start = localStart;
    if (start == null) return null;
    return CalendarEvent(
      series: EventSeries(
        eventId: id,
        localStart: start,
        duration: duration,
        timeZone: timeZone,
        rule: rule,
      ),
      title: title,
      kind: kind,
      status: status,
      participantIds: participantIds,
      responsibleMemberId: responsibleMemberId,
      location: location,
      placeId: placeId,
      reminders: reminders,
      meetMinutesBefore: meetMinutesBefore,
    );
  }

  static Payload _writeRule(RecurrenceRule rule) => Payload.map()
    ..setText('freq', rule.frequency.name)
    ..setInteger('interval', rule.interval)
    ..setTexts('byWeekday', [for (final d in rule.byWeekday) d.name])
    ..setInteger('byMonthDay', rule.byMonthDay)
    ..setInteger('byMonth', rule.byMonth)
    ..setText('until', rule.until == null ? null : _localIso(rule.until!))
    ..setInteger('count', rule.count)
    ..setText('skip', rule.skip.name);
}

/// One occurrence of a recurring event cancelled, moved or changed: spec §3
/// `event_exception`, stored as its own object so a one-week change never
/// rewrites the series. Times here are UTC instants, not wall-clock: an
/// exception belongs to one date and never recurs, so the zone rule for
/// series (CLAUDE.md invariant 4) doesn't apply.
class EventExceptionPayload {
  EventExceptionPayload._(this.payload);

  static const version = 1;

  factory EventExceptionPayload.read(Payload payload) =>
      EventExceptionPayload._(payload);

  factory EventExceptionPayload.write({
    Payload? existing,
    required String eventId,
    required DateTime originalStart,
    required ExceptionType type,
    DateTime? overrideStart,
    Duration? overrideDuration,
    String? overrideTitle,
    String? overrideResponsibleMemberId,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('event', eventId)
      ..setText('original', _instantIso(originalStart))
      ..setText('type', type.name)
      ..setText(
        'start',
        overrideStart == null ? null : _instantIso(overrideStart),
      )
      ..setInteger('minutes', overrideDuration?.inMinutes)
      ..setText('title', overrideTitle)
      ..setText('responsible', overrideResponsibleMemberId);
    return EventExceptionPayload._(p);
  }

  /// The object id for [eventId]'s occurrence at [originalStart]: the same on
  /// every device, so two edits of one occurrence update one object instead
  /// of stacking up.
  static String idFor(String eventId, DateTime originalStart) => const Uuid()
      .v5(_exceptionNamespace, '$eventId/${_instantIso(originalStart)}');

  final Payload payload;

  String get eventId => payload.text('event') ?? '';

  DateTime? get originalStart => _parseInstant(payload.text('original'));

  ExceptionType get type =>
      _byName(ExceptionType.values, payload.text('type')) ??
      ExceptionType.modified;

  DateTime? get overrideStart => _parseInstant(payload.text('start'));

  Duration? get overrideDuration => switch (payload.integer('minutes')) {
    final m? => Duration(minutes: m),
    null => null,
  };

  String? get overrideTitle => payload.text('title');

  String? get overrideResponsibleMemberId => payload.text('responsible');

  /// The domain view, or null if the payload can't say which occurrence.
  ExceptionEntry? toDomain() {
    final original = originalStart;
    if (original == null || eventId.isEmpty) return null;
    return ExceptionEntry(
      originalStart: original,
      type: type,
      overrideStart: overrideStart,
      overrideDuration: overrideDuration,
      overrideTitle: overrideTitle,
      overrideResponsibleMemberId: overrideResponsibleMemberId,
    );
  }
}

/// Namespace for [EventExceptionPayload.idFor]: UUIDv5 of
/// `https://github.com/JohanCarlstedt/FamilyPlanner/event-exception` in the
/// URL namespace. Fixed forever: changing it would give every stored
/// exception a second id.
const _exceptionNamespace = '15b6f8aa-7e1e-5355-b709-83456e9b0344';

/// A UTC instant, to the minute: `2026-09-17T15:30Z`.
String _instantIso(DateTime instant) {
  final u = instant.toUtc();
  return '${_localIso(u)}Z';
}

DateTime? _parseInstant(String? iso) {
  if (iso == null || !iso.endsWith('Z')) return null;
  return _parseLocal(iso.substring(0, iso.length - 1));
}

/// A member's name and colour: the `MemberProfile` object, keyed by member id.
class MemberProfile {
  MemberProfile._(this.payload);

  static const version = 1;

  factory MemberProfile.read(Payload payload) => MemberProfile._(payload);

  factory MemberProfile.write({
    Payload? existing,
    required String displayName,
    required MemberRole role,
    String? color,
    MaturityTier? tier,
    DateTime? endedAt,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('name', displayName)
      ..setText('role', role.name)
      ..setText('color', color)
      ..setText('tier', role == MemberRole.child ? tier?.name : null)
      ..setText('endedAt', endedAt == null ? null : _instantIso(endedAt));
    return MemberProfile._(p);
  }

  final Payload payload;

  String get displayName => payload.text('name') ?? '';

  /// A copy of the member's role, readable offline; the server's role decides
  /// what a device may do, this one only what the app shows.
  MemberRole get role =>
      _byName(MemberRole.values, payload.text('role')) ?? MemberRole.parent;

  String? get color => payload.text('color');

  MaturityTier? get tier => _byName(MaturityTier.values, payload.text('tier'));

  /// When they left or were removed (spec §9), or null.
  DateTime? get endedAt => _parseInstant(payload.text('endedAt'));

  /// Their data was erased: no name, colour or age group left, only the id
  /// that history still points at.
  bool get erased => payload.boolean('erased') ?? false;

  /// What they don't or can't eat (spec §4 `member_dietary_note`). On the
  /// profile, so whoever plans a meal can see it.
  List<DietNote> dietNotes(String memberId) => [
    for (final d in payload.nestedList('diet') ?? const <Payload>[])
      DietNote.values(
        memberId: memberId,
        type: d.text('type') ?? 'dislike',
        value: d.text('value') ?? '',
        strict: d.boolean('strict') ?? false,
        note: d.text('note'),
      ),
  ];

  /// This profile with [notes] as its dietary notes, everything else kept.
  MemberProfile withDiet(List<DietNote> notes) {
    final p = Payload.decode(payload.encode())
      ..setNestedList('diet', [
        for (final n in notes)
          Payload.map()
            ..setText('type', n.type.name)
            ..setText('value', n.value)
            ..setBoolean('strict', n.strict)
            ..setText('note', n.note),
      ]);
    return MemberProfile._(p);
  }

  Member toDomain(String memberId) => Member(
    id: memberId,
    displayName: displayName,
    role: role,
    color: color,
    tier: role == MemberRole.child ? tier : null,
    endedAt: endedAt,
  );
}

/// ISO 8601 local date-time without offset: wall-clock, per the recurrence
/// invariant (CLAUDE.md invariant 4).
String _localIso(DateTime local) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}';
}

/// Wall-clock times travel as `DateTime.utc` fields: a local `DateTime` would
/// be normalised through this device's own zone, turning 02:30 on a DST-gap
/// day into 03:30 before the recurrence engine ever saw it.
DateTime? _parseLocal(String? iso) {
  if (iso == null) return null;
  // Read the fields directly: DateTime.parse of an offset-less string is
  // local time too, and would move the same gap hour.
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?$')
      .firstMatch(iso);
  if (m == null) return null;
  int field(int i) => int.parse(m.group(i) ?? '0');
  return DateTime.utc(field(1), field(2), field(3), field(4), field(5));
}

T? _byName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
