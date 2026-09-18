import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/l10n.dart';

/// Which occurrences of a repeating event a change touches: spec §10 screen 3
/// (this occurrence / this and future / whole series).
enum EditScope { occurrence, thisAndAfter, series }

/// Asks which occurrences to change or remove. Null if dismissed.
Future<EditScope?> askEditScope(
  BuildContext context, {
  required bool removing,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<EditScope>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              removing ? l10n.removeWhich : l10n.changeWhich,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (scope, label) in [
            (
              EditScope.occurrence,
              removing ? l10n.cancelThisOne : l10n.scopeThisOne,
            ),
            (
              EditScope.thisAndAfter,
              removing ? l10n.removeThisAndAfter : l10n.scopeThisAndAfter,
            ),
            (EditScope.series, removing ? l10n.removeAll : l10n.scopeAll),
          ])
            ListTile(
              title: Text(label),
              onTap: () => Navigator.pop(context, scope),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// "Every week on Monday, Thursday", in the app's language.
String describeRule(AppLocalizations l10n, RecurrenceRule rule) =>
    switch (rule.frequency) {
      Frequency.weekly when rule.byWeekday.isNotEmpty => l10n.repeatsWeeklyOn(
        [for (final d in rule.byWeekday) weekdayName(d)].join(', '),
      ),
      Frequency.daily => l10n.repeatsDaily,
      Frequency.weekly => l10n.repeatsWeekly,
      Frequency.monthly => l10n.repeatsMonthly,
      Frequency.yearly => l10n.repeatsYearly,
    };

/// The weekday's full name in the app's language.
String weekdayName(Weekday d) =>
    DateFormat('EEEE').format(DateTime(2026, 9, 14 + d.index));

/// [instant] as wall-clock fields in [timeZone] (`DateTime.utc` fields, per
/// the recurrence invariant).
DateTime wallClock(DateTime instant, String timeZone) {
  final t = tz.TZDateTime.from(instant, tz.getLocation(timeZone));
  return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);
}

/// The UTC instant of wall-clock [wall] in [timeZone], as a plain DateTime:
/// a TZDateTime is never == a DateTime, so it mustn't leak into comparisons.
DateTime instantOf(DateTime wall, String timeZone) =>
    DateTime.fromMicrosecondsSinceEpoch(
      tz.TZDateTime(
        tz.getLocation(timeZone),
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      ).microsecondsSinceEpoch,
      isUtc: true,
    );

/// [rule] ending just before the occurrence whose wall-clock start is [wall].
/// `until` is inclusive and compared in wall-clock time, so a minute earlier
/// keeps every occurrence before it and none from it on.
RecurrenceRule endingBefore(RecurrenceRule rule, DateTime wall) {
  final end = wall.subtract(const Duration(minutes: 1));
  final until = rule.until;
  return RecurrenceRule(
    frequency: rule.frequency,
    interval: rule.interval,
    byWeekday: rule.byWeekday,
    byMonthDay: rule.byMonthDay,
    byMonth: rule.byMonth,
    until: until != null && until.isBefore(end) ? until : end,
    count: rule.count,
    skip: rule.skip,
  );
}

/// Whether any occurrence of [series] starts before [at]: if none does,
/// "this and all after it" is the whole series.
bool hasOccurrenceBefore(EventSeries series, DateTime at) =>
    const RecurrenceExpander()
        .expand(series, DateTime.utc(1900), at)
        .any((o) => o.originalStart.isBefore(at));

/// Rewrites the stored event [id] so its series stops before [at], keeping
/// every field of [payload] it doesn't touch.
Future<void> endSeriesBefore(
  FamilyStore store,
  String id,
  Payload payload,
  DateTime at,
) async {
  final e = EventPayload.read(Payload.decode(payload.encode()));
  final start = e.localStart;
  final rule = e.rule;
  if (start == null || rule == null) return;
  await store.saveEvent(
    EventPayload.write(
      existing: e.payload,
      title: e.title,
      kind: e.kind,
      localStart: start,
      duration: e.duration,
      timeZone: e.timeZone,
      status: e.status,
      visibility: e.visibility,
      rule: endingBefore(rule, wallClock(at, e.timeZone)),
      participantIds: e.participantIds,
      responsibleMemberId: e.responsibleMemberId,
      location: e.location,
      notes: e.notes,
    ),
    id: id,
  );
}
