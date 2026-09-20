import 'ical.dart';

/// How much of a phone calendar the family sees.
enum CalendarDetail {
  /// The time is shared; what it is stays private. A work calendar full of
  /// client names has no business in a family planner, but "unavailable
  /// 14:00–15:00" is exactly what stops a double-booking.
  busy,

  /// Title, place and notes, as the calendar has them.
  full,
}

/// One entry of a calendar the phone already syncs — Google, Outlook,
/// iCloud, a work account — as an event for the family.
///
/// Reading the phone's own calendars rather than talking to Google or
/// Microsoft keeps every property this app is built on: no OAuth tokens to
/// store, no third party told who the family is, nothing leaving the device
/// that the family has not chosen to share. The phone did the syncing
/// already.
///
/// The result goes through the same import as a subscribed feed, so it
/// inherits all of that: a stable id per entry, an event the family deleted
/// staying deleted, and one that vanishes being cancelled rather than
/// disappearing.
ImportedEvent fromPhoneCalendar({
  required String id,
  required String? title,
  required DateTime localStart,
  required Duration duration,
  required CalendarDetail detail,
  /// What a hidden entry is called, in the reader's language.
  required String busyTitle,
  bool allDay = false,
  String? location,
  String? description,
  bool cancelled = false,
  /// Bumped when the phone says the entry changed, so an unchanged one is
  /// not rewritten on every sync.
  int sequence = 0,
}) => ImportedEvent(
  uid: id,
  sequence: sequence,
  title: switch (detail) {
    CalendarDetail.busy => busyTitle,
    CalendarDetail.full => switch (title?.trim()) {
      null || '' => busyTitle,
      final t => t,
    },
  },
  localStart: localStart,
  duration: duration,
  allDay: allDay,
  // Where and why are the private parts: a place name gives away as much as
  // a title ("Karolinska", "Advokatbyrån").
  location: detail == CalendarDetail.full ? location : null,
  description: detail == CalendarDetail.full ? description : null,
  cancelled: cancelled,
);
