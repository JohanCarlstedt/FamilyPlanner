import 'calendar_event.dart';
import 'recurrence.dart';
import 'reminders.dart';

/// Spec §3 `person.celebration_type`.
enum CelebrationType { birthday, nameday, anniversary, other }

/// Birthdays and other yearly days (spec §3 `person`): a celebration event
/// that repeats every year on its own, with gift-buying reminders.
class Celebrations {
  Celebrations._();

  /// When nobody knows the year, it's stored as this one.
  static const unknownYear = 1900;

  /// Reminders fire at this local time on their day.
  static const reminderHour = 9;

  /// The yearly event for a day first celebrated on [date] (`DateTime.utc`
  /// fields). All day; 29 February falls on the 28th in a common year
  /// (RFC 7529 SKIP=BACKWARD); gift reminders [leadDays] ahead reach the
  /// adults.
  static CalendarEvent event({
    required String eventId,
    required String title,
    required DateTime date,
    required String timeZone,
    List<int> leadDays = const [14, 3, 0],
    List<String> participantIds = const [],
  }) =>
      CalendarEvent(
        series: EventSeries(
          eventId: eventId,
          localStart: DateTime.utc(date.year, date.month, date.day),
          duration: const Duration(days: 1),
          timeZone: timeZone,
          rule: RecurrenceRule(
            frequency: Frequency.yearly,
            byMonth: date.month,
            byMonthDay: date.day,
            skip: RecurrenceSkip.backward,
          ),
        ),
        title: title,
        kind: EventKind.celebration,
        participantIds: participantIds,
        reminders: [
          for (final d in leadDays)
            EventReminder(
              minutesBefore: d * 24 * 60 - reminderHour * 60,
              target: ReminderTarget.adults,
            ),
        ],
      );

  /// How old someone born on [birthdate] turns on [on]; null when the year
  /// isn't known.
  static int? ageOn(DateTime birthdate, DateTime on) =>
      birthdate.year <= unknownYear ? null : on.year - birthdate.year;
}
