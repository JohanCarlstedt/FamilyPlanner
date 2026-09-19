import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';

import '../data/family_repository.dart';
import '../features/events/occurrence_editing.dart';
import 'l10n.dart';

/// An event's title as the calendar shows it: a birthday says who and what
/// they turn that year.
String shownTitle(BuildContext context, CalendarEvent event, DateTime start) {
  if (event.kind != EventKind.celebration) return event.title;
  final born = event.series.localStart;
  final on = wallClock(start, familyTimeZone);
  final age = Celebrations.ageOn(born, on);
  return age == null || age <= 0
      ? '🎂 ${event.title}'
      : '🎂 ${context.l10n.celebrationTurns(event.title, age)}';
}
