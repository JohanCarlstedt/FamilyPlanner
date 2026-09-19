import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';

/// A regular block in the family's week, as chosen during setup.
class WeekBlock {
  const WeekBlock({
    required this.title,
    required this.from,
    required this.to,
    this.memberId,
    this.weekdaysOnly = true,
  });

  final String title;
  final TimeOfDay from;
  final TimeOfDay to;

  /// Whose it is; null for the whole family.
  final String? memberId;
  final bool weekdaysOnly;

  WeekBlock copyWith({TimeOfDay? from, TimeOfDay? to}) => WeekBlock(
    title: title,
    from: from ?? this.from,
    to: to ?? this.to,
    memberId: memberId,
    weekdaysOnly: weekdaysOnly,
  );
}

/// Spec §9 step 3, "a blank calendar reads as broken": the blocks as
/// repeating routines. Routines carry no default reminders, so a seeded
/// week never nags anyone about who's responsible.
List<EventPayload> firstWeekEvents({
  required DateTime today,
  required String timeZone,
  required List<WeekBlock> blocks,
}) {
  var weekday = DateTime.utc(today.year, today.month, today.day);
  while (weekday.weekday > DateTime.friday) {
    weekday = weekday.add(const Duration(days: 1));
  }
  return [
    for (final b in blocks)
      EventPayload.write(
        title: b.title,
        kind: EventKind.routine,
        localStart: (b.weekdaysOnly ? weekday : today).copyWith(
          hour: b.from.hour,
          minute: b.from.minute,
        ),
        duration: Duration(
          minutes: _minutes(b.to) - _minutes(b.from) > 0
              ? _minutes(b.to) - _minutes(b.from)
              : 30,
        ),
        timeZone: timeZone,
        rule: b.weekdaysOnly
            ? const RecurrenceRule(
                frequency: Frequency.weekly,
                byWeekday: {
                  Weekday.mo,
                  Weekday.tu,
                  Weekday.we,
                  Weekday.th,
                  Weekday.fr,
                },
              )
            : const RecurrenceRule(frequency: Frequency.daily),
        participantIds: [?b.memberId],
      ),
  ];
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
