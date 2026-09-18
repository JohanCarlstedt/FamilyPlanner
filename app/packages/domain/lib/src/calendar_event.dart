import 'recurrence.dart';

/// Spec §3 `event.kind`. Discriminates behaviour without fragmenting storage.
enum EventKind {
  appointment,
  activity,
  celebration,
  routine,
  actionBlock,
  homework
}

enum EventStatus { confirmed, tentative, pendingApproval, cancelled }

/// A decrypted event as the client sees it: the recurrence series plus the
/// content the server never reads.
class CalendarEvent {
  final EventSeries series;
  final String title;
  final EventKind kind;
  final EventStatus status;
  final List<String> participantIds;

  /// Who is accountable or driving. Required on any event involving a child
  /// (spec §1 decision 3); null here means that requirement is unmet.
  final String? responsibleMemberId;

  /// Display text for the place, until `place` exists as its own type.
  final String? location;

  const CalendarEvent({
    required this.series,
    required this.title,
    required this.kind,
    this.status = EventStatus.confirmed,
    this.participantIds = const [],
    this.responsibleMemberId,
    this.location,
  });

  String get id => series.eventId;

  bool get isCancelled => status == EventStatus.cancelled;

  bool get isRoutine => kind == EventKind.routine;
}
