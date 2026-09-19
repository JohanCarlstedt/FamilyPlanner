import 'calendar_event.dart';
import 'recurrence.dart';

/// Spec §3 `custody_arrangement.pattern`, the common Swedish ones.
enum CustodyPattern { alternatingWeeks, alternatingWeekends }

/// A holiday or a swap: the child is [here] (or not) from [from] up to, not
/// including, [until] (dates, `DateTime.utc` fields).
class CustodySwap {
  const CustodySwap({
    required this.from,
    required this.until,
    required this.here,
  });

  final DateTime from;
  final DateTime until;
  final bool here;
}

/// Where a child of two homes is (spec §3 "Custody across two households"),
/// seen from this family: here, or with the other home.
class CustodyArrangement {
  const CustodyArrangement({
    required this.childId,
    required this.pattern,
    required this.reference,
    this.coParentId,
    this.swaps = const [],
  });

  final String childId;

  /// The other home's parent, when they use the app (a member here).
  final String? coParentId;
  final CustodyPattern pattern;

  /// A changeover, wall clock (`DateTime.utc` fields): for alternating
  /// weeks, when the child comes here; for alternating weekends, the
  /// Friday they go to the other home. Everything counts from it, both
  /// ways.
  final DateTime reference;
  final List<CustodySwap> swaps;

  static const _weekend = Duration(days: 2);

  /// Whether the child is here at wall-clock [local] (`DateTime.utc`
  /// fields).
  bool isHere(DateTime local) {
    final day = DateTime.utc(local.year, local.month, local.day);
    for (final s in swaps) {
      if (!day.isBefore(s.from) && day.isBefore(s.until)) return s.here;
    }
    final since = local.difference(reference);
    switch (pattern) {
      case CustodyPattern.alternatingWeeks:
        final weeks = since.inMinutes.floorDiv(7 * 24 * 60);
        return weeks.isEven;
      case CustodyPattern.alternatingWeekends:
        const period = 14 * 24 * 60;
        final into = since.inMinutes % period;
        return into >= _weekend.inMinutes;
    }
  }

  /// The changeovers as events for the child (spec §3: "changeover is
  /// itself an event"): one series each way, every other week.
  List<CalendarEvent> changeoverEvents({
    required String timeZone,
    required String toUs,
    required String toThem,
    required String Function(String direction) idFor,
  }) {
    final (inStart, outStart) = switch (pattern) {
      CustodyPattern.alternatingWeeks => (
          reference,
          reference.add(const Duration(days: 7)),
        ),
      CustodyPattern.alternatingWeekends => (
          reference.add(_weekend),
          reference,
        ),
    };
    CalendarEvent series(String direction, String title, DateTime start) =>
        CalendarEvent(
          series: EventSeries(
            eventId: idFor(direction),
            localStart: start,
            duration: const Duration(minutes: 30),
            timeZone: timeZone,
            rule: RecurrenceRule(
              frequency: Frequency.weekly,
              interval: 2,
              byWeekday: {Weekday.values[start.weekday - 1]},
            ),
          ),
          title: title,
          kind: EventKind.appointment,
          participantIds: [childId],
        );
    return [series('in', toUs, inStart), series('out', toThem, outStart)];
  }
}

extension on int {
  int floorDiv(int other) => (this / other).floor();
}
