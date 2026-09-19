import 'package:timezone/timezone.dart' as tz;

import 'absence.dart';
import 'calendar_event.dart';
import 'custody.dart';
import 'family.dart';
import 'family_settings.dart';
import 'place.dart';
import 'recurrence.dart';

/// Who an event's reminder reaches (spec §8 `event_reminder.target`).
enum ReminderTarget {
  /// The people going and whoever is responsible. An event with no named
  /// participants is the whole family's, so it reaches everyone.
  participants,

  /// Only the responsible adult: the departure reminder's audience.
  responsible,

  /// Everyone in the family, going or not.
  allFamily,

  /// The parents: gift reminders, which a child isn't asked to act on.
  adults,
}

/// "Remind … N minutes before", set on the event and inherited by every
/// occurrence (spec §8 `event_reminder`).
class EventReminder {
  final int minutesBefore;
  final ReminderTarget target;

  const EventReminder({
    required this.minutesBefore,
    this.target = ReminderTarget.participants,
  });
}

/// Why a reminder exists: the spec §8 triggers this app implements.
enum ReminderKind {
  /// Set on the event by someone.
  custom,

  /// Actionable while there's still time: pack the kit bag.
  prep,

  /// Time to leave, aimed at whoever drives.
  departure,

  /// The evening before an appointment.
  dayBefore,

  /// A child's event with no responsible adult, 24 hours out: to every
  /// parent. The notification most worth sending.
  unassigned,
}

/// One reminder one member is owed.
class DueReminder {
  /// The occurrence as it will happen: its own title and responsible adult.
  final CalendarEvent event;

  /// Identifies the occurrence, as in [Occurrence.originalStart].
  final DateTime originalStart;

  /// When the occurrence starts, after any move. UTC.
  final DateTime start;

  /// When to remind. UTC.
  final DateTime fireAt;

  final ReminderKind kind;

  /// Set for [ReminderKind.custom]: the event's own reminder.
  final EventReminder? reminder;

  /// Inside quiet hours and exempt from moving (spec §8): deliver without
  /// sound where the platform allows.
  final bool silent;

  /// Set when this is a child's reminder routed to the adult responsible,
  /// because the child has no device (spec §8): the child's member id.
  final String? forMember;

  const DueReminder({
    required this.event,
    required this.originalStart,
    required this.start,
    required this.fireAt,
    required this.kind,
    this.reminder,
    this.silent = false,
    this.forMember,
  });

  DueReminder routedFor(String childId) => DueReminder(
        event: event,
        originalStart: originalStart,
        start: start,
        fireAt: fireAt,
        kind: kind,
        reminder: reminder,
        silent: silent,
        forMember: childId,
      );

  /// The same for the same occurrence and rule every time it's planned: the
  /// dedupe key of spec §8, so planning twice never schedules twice.
  String get key => '${forMember == null ? '' : '$forMember>'}'
      '${event.id}|${originalStart.toUtc().toIso8601String()}|${kind.name}'
      '${reminder == null ? '' : '|${reminder!.minutesBefore}|${reminder!.target.name}'}';
}

class ReminderPlanner {
  final RecurrenceExpander _expander;

  const ReminderPlanner([this._expander = const RecurrenceExpander()]);

  /// Leave this long before the start, plus parking and getting ready, while
  /// no route estimate exists (spec §3: unresolved places use a fixed lead).
  static const fixedTravelMinutes = 30;

  /// A prep reminder that would land in quiet hours moves to this long
  /// before they begin, the evening before (spec §8).
  static const beforeQuiet = Duration(minutes: 15);

  /// The longest lead any default rule uses, for how far past the window
  /// occurrences are looked for.
  static const _longestDefault = Duration(hours: 30);

  /// Reminders [memberId] is owed that fire in [from, until), in firing
  /// order. Cancelled events and cancelled occurrences owe nothing, and
  /// routines stay silent unless someone set a reminder on one.
  List<DueReminder> plan({
    required List<CalendarEvent> events,
    required String memberId,
    required DateTime from,
    required DateTime until,
    List<Member> members = const [],
    FamilySettings settings = FamilySettings.defaults,
    Map<String, Place> places = const {},
    Set<String> withDevices = const {},
    List<Absence> absences = const [],
    List<CustodyArrangement> custody = const [],
  }) {
    final due = _planFor(
      events: events,
      memberId: memberId,
      from: from,
      until: until,
      members: members,
      settings: settings,
      places: places,
      absences: absences,
      custody: custody,
    );
    // A child with no device still has reminders; they reach whoever is
    // responsible for that event, labelled with the child (spec §8
    // "Routing when the child has no device"). Unknown device lists route
    // nothing, rather than doubling reminders for children who do have one.
    if (withDevices.isNotEmpty) {
      for (final child in members) {
        if (!child.isChild || withDevices.contains(child.id)) continue;
        for (final r in _planFor(
          events: events,
          memberId: child.id,
          from: from,
          until: until,
          members: members,
          settings: settings,
          places: places,
          absences: absences,
          custody: custody,
        )) {
          if (r.event.responsibleMemberId == memberId &&
              r.kind != ReminderKind.departure) {
            due.add(r.routedFor(child.id));
          }
        }
      }
    }
    return due..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  }

  List<DueReminder> _planFor({
    required List<CalendarEvent> events,
    required String memberId,
    required DateTime from,
    required DateTime until,
    required List<Member> members,
    required FamilySettings settings,
    required Map<String, Place> places,
    List<Absence> absences = const [],
    List<CustodyArrangement> custody = const [],
  }) {
    final arrangements = {for (final c in custody) c.childId: c};
    final byId = {for (final m in members) m.id: m};
    final me = byId[memberId];
    final children = {
      for (final m in members)
        if (m.isChild) m.id,
    };
    final due = <DueReminder>[];

    for (final event in events) {
      // A request waits for a parent; nothing to remind anyone of yet.
      if (event.isCancelled || event.status == EventStatus.pendingApproval) {
        continue;
      }
      final longestCustom = event.reminders.isEmpty
          ? Duration.zero
          : Duration(
              minutes: event.reminders
                  .map((r) => r.minutesBefore)
                  .reduce((a, b) => a > b ? a : b),
            );
      final lookAhead =
          longestCustom > _longestDefault ? longestCustom : _longestDefault;
      final location = tz.getLocation(event.series.timeZone);

      for (final occurrence in _expander.expand(
        event.series,
        from,
        until.add(lookAhead),
      )) {
        // Away (spec §3 `absence`): suspended occurrences remind nobody.
        if (absences.any((a) => a.suspends(event, occurrence))) continue;
        final shown = event.forOccurrence(occurrence);
        final start = occurrence.start;

        DueReminder make(
          ReminderKind kind,
          DateTime fireAt, {
          EventReminder? reminder,
          bool movable = false,
        }) {
          var at = fireAt;
          var silent = false;
          if (settings.isQuiet(_minutesOf(at, location))) {
            if (movable) {
              at = _beforeQuiet(at, settings, location);
            } else {
              silent = true;
            }
          }
          return DueReminder(
            event: shown,
            originalStart: occurrence.originalStart,
            start: start,
            fireAt: at,
            kind: kind,
            reminder: reminder,
            silent: silent,
          );
        }

        final candidates = <DueReminder>[
          for (final r in event.reminders)
            if (_reaches(r.target, shown, memberId, me))
              make(
                ReminderKind.custom,
                start.subtract(Duration(minutes: r.minutesBefore)),
                reminder: r,
              ),
          if (!event.isRoutine &&
              !_withTheOtherHome(shown, start, location, arrangements))
            ..._defaults(
              shown,
              start,
              memberId,
              me,
              children,
              settings,
              places,
              location,
              make,
              members,
            ),
        ];
        for (final r in candidates) {
          if (absences.any(
            (a) => a.silences(memberId, r.fireAt, event.series.timeZone),
          )) {
            continue;
          }
          // Reminders after the start are no use, except on a day being
          // celebrated: its morning reminder is on the day. Ones in the
          // window are due.
          final latest =
              event.kind == EventKind.celebration ? occurrence.end : start;
          if (!r.fireAt.isBefore(from) &&
              r.fireAt.isBefore(until) &&
              r.fireAt.isBefore(latest.add(const Duration(minutes: 1)))) {
            due.add(r);
          }
        }
      }
    }
    return due..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  }

  /// Spec §8 "Default rules worth shipping with", for what the app has.
  Iterable<DueReminder> _defaults(
    CalendarEvent event,
    DateTime start,
    String memberId,
    Member? me,
    Set<String> children,
    FamilySettings settings,
    Map<String, Place> places,
    tz.Location location,
    DueReminder Function(ReminderKind, DateTime, {bool movable}) make,
    List<Member> members,
  ) sync* {
    final memberIds = {for (final m in members) m.id};
    final responsible = event.responsibleMemberId == memberId;
    final participant =
        event.participantIds.isEmpty || event.participantIds.contains(memberId);
    final parking = places[event.placeId]?.parkingBufferMinutes ?? 0;
    // A meeting time is when to be there; everything counts back from it.
    final arrive = start.subtract(
      Duration(minutes: event.meetMinutesBefore ?? 0),
    );
    final leave = arrive.subtract(
      Duration(
        minutes: fixedTravelMinutes + parking + settings.prepBufferMinutes,
      ),
    );

    switch (event.kind) {
      case EventKind.activity:
        if (responsible) {
          yield make(ReminderKind.departure, leave);
          yield make(
            ReminderKind.prep,
            _dayBeforeAt(start, 20 * 60, location),
            movable: true,
          );
        }
        if (me != null &&
            me.isChild &&
            event.participantIds.contains(memberId)) {
          yield make(
            ReminderKind.prep,
            arrive.subtract(const Duration(minutes: 60)),
            movable: true,
          );
        }
      case EventKind.appointment:
        if (responsible || participant) {
          yield make(
            ReminderKind.dayBefore,
            _dayBeforeAt(start, 18 * 60, location),
            movable: true,
          );
        }
        if (responsible) yield make(ReminderKind.departure, leave);
      case EventKind.routine ||
            EventKind.celebration ||
            EventKind.actionBlock ||
            EventKind.homework:
        break;
    }

    // Responsible means responsible and still in the family (spec §9).
    final unassigned = (event.responsibleMemberId == null ||
            (members.isNotEmpty &&
                !memberIds.contains(event.responsibleMemberId))) &&
        event.participantIds.any(children.contains);
    // Every parent: helpers aren't the ones to find someone.
    if (unassigned && me != null && me.isParent) {
      yield make(
        ReminderKind.unassigned,
        start.subtract(const Duration(hours: 24)),
        movable: true,
      );
    }
  }

  /// Spec §3 custody: an event only for children who are with the other
  /// home then is theirs to arrange; this home isn't asked who drives.
  static bool _withTheOtherHome(
    CalendarEvent event,
    DateTime start,
    tz.Location location,
    Map<String, CustodyArrangement> arrangements,
  ) {
    if (arrangements.isEmpty || event.participantIds.isEmpty) return false;
    final t = tz.TZDateTime.from(start, location);
    final wall = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);
    return event.participantIds.every(
      (p) => !(arrangements[p]?.isHere(wall) ?? true),
    );
  }

  static ClockMinutes _minutesOf(DateTime instant, tz.Location location) {
    final t = tz.TZDateTime.from(instant, location);
    return t.hour * 60 + t.minute;
  }

  /// [minutes] after midnight on the calendar day before [start]'s, in the
  /// family's zone.
  static DateTime _dayBeforeAt(
    DateTime start,
    ClockMinutes minutes,
    tz.Location location,
  ) {
    final t = tz.TZDateTime.from(start, location);
    return _plain(
      tz.TZDateTime(location, t.year, t.month, t.day - 1, 0, minutes),
    );
  }

  /// The evening before the quiet hours [at] falls in: [beforeQuiet] ahead of
  /// their start.
  static DateTime _beforeQuiet(
    DateTime at,
    FamilySettings settings,
    tz.Location location,
  ) {
    final t = tz.TZDateTime.from(at, location);
    final minutes = t.hour * 60 + t.minute;
    // Past midnight, the quiet hours began the day before.
    final dayOffset =
        settings.quietStart > settings.quietEnd && minutes < settings.quietEnd
            ? -1
            : 0;
    final quietBegan = tz.TZDateTime(
      location,
      t.year,
      t.month,
      t.day + dayOffset,
      0,
      settings.quietStart,
    );
    return _plain(quietBegan.subtract(beforeQuiet));
  }

  /// A plain UTC DateTime: TZDateTime is never == a DateTime.
  static DateTime _plain(DateTime d) =>
      DateTime.fromMicrosecondsSinceEpoch(d.microsecondsSinceEpoch,
          isUtc: true);

  static bool _reaches(
    ReminderTarget target,
    CalendarEvent event,
    String memberId,
    Member? me,
  ) =>
      switch (target) {
        ReminderTarget.allFamily => true,
        ReminderTarget.adults => me?.role == MemberRole.parent,
        ReminderTarget.responsible => event.responsibleMemberId == memberId,
        ReminderTarget.participants => event.participantIds.isEmpty ||
            event.participantIds.contains(memberId) ||
            event.responsibleMemberId == memberId,
      };
}
