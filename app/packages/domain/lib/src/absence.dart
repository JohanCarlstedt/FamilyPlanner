import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';
import 'recurrence.dart';

/// Away mode (spec §3 `absence`): a holiday, a trip, a school break. For
/// its days it suspends the covered members' occurrences of the kinds it
/// names, and their reminders, without touching any series.
class Absence {
  const Absence({
    required this.id,
    required this.title,
    required this.startsOn,
    required this.endsOn,
    this.memberIds = const {},
    this.suppressKinds = const {EventKind.activity, EventKind.routine},
    this.suppressReminders = false,
  });

  final String id;
  final String title;

  /// First and last day, inclusive, as `DateTime.utc` date fields.
  final DateTime startsOn;
  final DateTime endsOn;

  /// Who's away; empty is the whole family.
  final Set<String> memberIds;
  final Set<EventKind> suppressKinds;

  /// Silence every reminder to those away, not only for what's suspended.
  final bool suppressReminders;

  bool coversDay(DateTime localDate) {
    final d = DateTime.utc(localDate.year, localDate.month, localDate.day);
    return !d.isBefore(startsOn) && !d.isAfter(endsOn);
  }

  bool covers(String memberId) =>
      memberIds.isEmpty || memberIds.contains(memberId);

  /// Whether [occurrence] of [event] is suspended: of a kind named, on a day
  /// covered, and only for people away (an event for the whole family is
  /// suspended only when the whole family is).
  bool suspends(CalendarEvent event, Occurrence occurrence) {
    if (!suppressKinds.contains(event.kind)) return false;
    final local = tz.TZDateTime.from(
      occurrence.start,
      tz.getLocation(event.series.timeZone),
    );
    if (!coversDay(local)) return false;
    if (memberIds.isEmpty) return true;
    final people = event.participantIds;
    return people.isNotEmpty && people.every(memberIds.contains);
  }

  /// Whether reminders to [memberId] at [instant] are silenced.
  bool silences(String memberId, DateTime instant, String timeZone) =>
      suppressReminders &&
      covers(memberId) &&
      coversDay(tz.TZDateTime.from(instant, tz.getLocation(timeZone)));
}
