/// ISO 8601 week number, as Swedish schools and clubs use it: weeks start on
/// Monday, and week 1 is the week containing the year's first Thursday.
///
/// Only the calendar date of [date] is used.
int isoWeekNumber(DateTime date) {
  // Work in UTC so a DST change can't shift the day arithmetic.
  final day = DateTime.utc(date.year, date.month, date.day);

  // The Thursday of this week decides which year the week belongs to.
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final firstOfYear = DateTime.utc(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(firstOfYear).inDays;
  return dayOfYear ~/ 7 + 1;
}
