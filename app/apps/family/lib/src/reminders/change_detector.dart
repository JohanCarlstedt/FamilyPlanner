import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';

/// What of an event matters for spec §8's "what is material", captured so a
/// device can compare what its member last heard about with what's there
/// now. Titles, notes and colours are minor: they're here only to name the
/// event in a notification.
class EventSnapshot {
  const EventSnapshot({
    required this.id,
    required this.title,
    required this.when,
    required this.place,
    required this.responsible,
    required this.participants,
    required this.gone,
    required this.editedBy,
    required this.exceptions,
    this.next,
  });

  final String id;
  final String title;

  /// Start, length, zone and rule, as one comparable string.
  final String when;
  final String? place;
  final String? responsible;
  final List<String> participants;

  /// Cancelled or deleted.
  final bool gone;
  final String? editedBy;

  /// Per occurrence (original start, ISO): what its exception changes.
  final Map<String, ExceptionSnapshot> exceptions;

  /// Its next start when the snapshot was taken: for an event that has since
  /// vanished, the only record of when it would have been.
  final DateTime? next;

  static EventSnapshot of(
    String id,
    EventPayload e,
    List<EventExceptionPayload> exceptions, {
    DateTime? next,
  }) => EventSnapshot(
    next: next,
    id: id,
    title: e.title,
    when: [
      e.payload.text('start'),
      e.duration.inMinutes,
      e.timeZone,
      e.payload.nested('rule')?.encode().join(','),
    ].join('|'),
    place: e.placeId ?? e.location,
    responsible: e.responsibleMemberId,
    participants: [...e.participantIds]..sort(),
    gone: e.isDeleted || e.status == EventStatus.cancelled,
    editedBy: e.payload.editedBy,
    exceptions: {
      for (final x in exceptions)
        if (x.originalStart case final at?)
          at.toUtc().toIso8601String(): ExceptionSnapshot(
            cancelled: x.type == ExceptionType.cancelled,
            moved: [
              x.overrideStart?.toUtc().toIso8601String(),
              x.overrideDuration?.inMinutes,
            ].join('|'),
            responsible: x.overrideResponsibleMemberId,
            editedBy: x.payload.editedBy,
          ),
    },
  );

  bool binds(String memberId) =>
      participants.isEmpty ||
      participants.contains(memberId) ||
      responsible == memberId;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'when': when,
    'place': place,
    'responsible': responsible,
    'participants': participants,
    'gone': gone,
    'editedBy': editedBy,
    'next': next?.toIso8601String(),
    'exceptions': {
      for (final MapEntry(:key, :value) in exceptions.entries)
        key: value.toJson(),
    },
  };

  static EventSnapshot fromJson(Map<String, dynamic> j) => EventSnapshot(
    id: j['id'] as String,
    title: j['title'] as String,
    when: j['when'] as String,
    place: j['place'] as String?,
    responsible: j['responsible'] as String?,
    participants: (j['participants'] as List).cast<String>(),
    gone: j['gone'] as bool,
    editedBy: j['editedBy'] as String?,
    next: switch (j['next']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    exceptions: {
      for (final MapEntry(:key, :value)
          in (j['exceptions'] as Map<String, dynamic>).entries)
        key: ExceptionSnapshot.fromJson(value as Map<String, dynamic>),
    },
  );
}

class ExceptionSnapshot {
  const ExceptionSnapshot({
    required this.cancelled,
    required this.moved,
    required this.responsible,
    required this.editedBy,
  });

  final bool cancelled;
  final String moved;
  final String? responsible;
  final String? editedBy;

  static const none = ExceptionSnapshot(
    cancelled: false,
    moved: '|',
    responsible: null,
    editedBy: null,
  );

  Map<String, Object?> toJson() => {
    'cancelled': cancelled,
    'moved': moved,
    'responsible': responsible,
    'editedBy': editedBy,
  };

  static ExceptionSnapshot fromJson(Map<String, dynamic> j) =>
      ExceptionSnapshot(
        cancelled: j['cancelled'] as bool,
        moved: j['moved'] as String,
        responsible: j['responsible'] as String?,
        editedBy: j['editedBy'] as String?,
      );
}

/// How a change reaches one member.
enum ChangeKind {
  /// A new event they're part of.
  added,

  /// Cancelled or deleted: the highest-priority change there is.
  cancelled,

  /// Time or place, or both.
  moved,

  /// They've been added to it.
  youAreIn,

  /// They've been taken off it.
  youAreOut,

  /// They're now the one driving.
  youDrive,

  /// Someone else drives now instead of them.
  someoneElseDrives,
}

/// One change worth telling one member about.
class EventChange {
  const EventChange({
    required this.eventId,
    required this.title,
    required this.kind,
    this.occurrence,
    this.timeChanged = false,
    this.placeChanged = false,
  });

  final String eventId;
  final String title;
  final ChangeKind kind;

  /// Set when only one occurrence changed: its original start. Null for the
  /// whole series, or an event that doesn't repeat.
  final DateTime? occurrence;

  final bool timeChanged;
  final bool placeChanged;
}

/// Compares what a member last heard about with what's there now, and
/// returns what they should hear (spec §8 "Change notifications"): material
/// changes only, never their own, never about the past, and nothing more than
/// seven days out unless it's a cancellation.
class ChangeDetector {
  const ChangeDetector();

  static const pushWithin = Duration(days: 7);

  List<EventChange> detect({
    required Map<String, EventSnapshot> before,
    required Map<String, EventSnapshot> after,
    required String memberId,
    required DateTime now,
    required DateTime? Function(String eventId, DateTime? occurrence) nextStart,
  }) {
    final changes = <EventChange>[];

    bool worthPushing(EventChange c) {
      final start = nextStart(c.eventId, c.occurrence);
      if (start == null || !start.isAfter(now)) return false;
      return c.kind == ChangeKind.cancelled ||
          !start.isAfter(now.add(pushWithin));
    }

    void add(EventChange c) {
      if (worthPushing(c)) changes.add(c);
    }

    for (final MapEntry(key: id, value: now_) in after.entries) {
      final was = before[id];
      if (was == null) {
        if (!now_.gone && now_.editedBy != memberId && now_.binds(memberId)) {
          add(
            EventChange(eventId: id, title: now_.title, kind: ChangeKind.added),
          );
        }
        continue;
      }

      if (now_.editedBy != memberId) {
        if (now_.gone && !was.gone) {
          if (was.binds(memberId)) {
            add(
              EventChange(
                eventId: id,
                title: was.title,
                kind: ChangeKind.cancelled,
              ),
            );
          }
          continue;
        }
        if (!now_.gone) {
          final moved = was.when != now_.when;
          final placed = was.place != now_.place;
          if ((moved || placed) &&
              (was.binds(memberId) || now_.binds(memberId))) {
            add(
              EventChange(
                eventId: id,
                title: now_.title,
                kind: ChangeKind.moved,
                timeChanged: moved,
                placeChanged: placed,
              ),
            );
          }
          final wasIn = was.participants.contains(memberId);
          final isIn = now_.participants.contains(memberId);
          if (isIn && !wasIn) {
            add(
              EventChange(
                eventId: id,
                title: now_.title,
                kind: ChangeKind.youAreIn,
              ),
            );
          }
          if (wasIn && !isIn) {
            add(
              EventChange(
                eventId: id,
                title: now_.title,
                kind: ChangeKind.youAreOut,
              ),
            );
          }
          if (was.responsible != now_.responsible) {
            if (now_.responsible == memberId) {
              add(
                EventChange(
                  eventId: id,
                  title: now_.title,
                  kind: ChangeKind.youDrive,
                ),
              );
            } else if (was.responsible == memberId) {
              add(
                EventChange(
                  eventId: id,
                  title: now_.title,
                  kind: ChangeKind.someoneElseDrives,
                ),
              );
            }
          }
        }
      }

      // One occurrence at a time.
      if (now_.gone || !now_.binds(memberId) && !was.binds(memberId)) continue;
      for (final MapEntry(key: at, value: x) in now_.exceptions.entries) {
        if (x.editedBy == memberId) continue;
        final old = was.exceptions[at] ?? ExceptionSnapshot.none;
        final occurrence = DateTime.parse(at);
        if (x.cancelled && !old.cancelled) {
          add(
            EventChange(
              eventId: id,
              title: now_.title,
              kind: ChangeKind.cancelled,
              occurrence: occurrence,
            ),
          );
          continue;
        }
        if (x.moved != old.moved) {
          add(
            EventChange(
              eventId: id,
              title: now_.title,
              kind: ChangeKind.moved,
              occurrence: occurrence,
              timeChanged: true,
            ),
          );
        }
        if (x.responsible != old.responsible) {
          if (x.responsible == memberId) {
            add(
              EventChange(
                eventId: id,
                title: now_.title,
                kind: ChangeKind.youDrive,
                occurrence: occurrence,
              ),
            );
          } else if ((old.responsible ?? was.responsible) == memberId) {
            add(
              EventChange(
                eventId: id,
                title: now_.title,
                kind: ChangeKind.someoneElseDrives,
                occurrence: occurrence,
              ),
            );
          }
        }
      }
    }

    // Deleted outright, not just marked: treat as cancelled.
    for (final MapEntry(key: id, value: was) in before.entries) {
      if (after.containsKey(id) || was.gone || !was.binds(memberId)) continue;
      add(
        EventChange(eventId: id, title: was.title, kind: ChangeKind.cancelled),
      );
    }
    return changes;
  }
}
