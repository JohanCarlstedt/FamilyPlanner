import 'package:domain/domain.dart';

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
    String? notes,
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
      ..setText('notes', notes);
    p.setNested('rule', rule == null ? null : _writeRule(rule));
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

  String? get location => payload.text('location');

  String? get notes => payload.text('notes');

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
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('name', displayName)
      ..setText('role', role.name)
      ..setText('color', color);
    return MemberProfile._(p);
  }

  final Payload payload;

  String get displayName => payload.text('name') ?? '';

  /// A copy of the member's role, readable offline; the server's role decides
  /// what a device may do, this one only what the app shows.
  MemberRole get role =>
      _byName(MemberRole.values, payload.text('role')) ?? MemberRole.parent;

  String? get color => payload.text('color');

  Member toDomain(String memberId) =>
      Member(id: memberId, displayName: displayName, role: role, color: color);
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
