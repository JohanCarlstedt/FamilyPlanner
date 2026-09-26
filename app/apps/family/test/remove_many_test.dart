import 'package:domain/domain.dart';
import 'package:family/src/features/week/week_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family/src/features/week/remove_many.dart';
import 'package:family/src/features/week/week_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'week_screen_test.dart' show openWeek;

/// Picking several things out of the week and removing them together.
///
/// Clearing a cancelled tournament weekend used to mean opening six
/// events and answering the same question six times.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('long-press starts picking, and says how many', (tester) async {
    await openWeek(tester);

    await tester.longPress(find.text('Football training').first);
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    // The week arrows are gone: they would carry the selection to a week
    // it does not exist in.
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('tapping adds to the selection rather than opening', (
    tester,
  ) async {
    await openWeek(tester);

    await tester.longPress(find.text('Football training').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dentist').first);
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    // Not the event screen.
    expect(find.text('Week 38'), findsNothing);
  });

  testWidgets('closing puts the ordinary week back', (tester) async {
    await openWeek(tester);

    await tester.longPress(find.text('Football training').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.textContaining('selected'), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('the delete action is there once something is picked', (
    tester,
  ) async {
    await openWeek(tester);

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.longPress(find.text('Football training').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  test('a routine picked out of the week is found to remove', () {
    // Emmy's school: routines are listed among the week's events and can
    // be picked, and the bin used to look among the events alone, find
    // nothing, and do nothing.
    final school = CalendarEvent(
      title: 'Skola',
      kind: EventKind.routine,
      series: EventSeries(
        eventId: 'school',
        localStart: _tuesday,
        duration: const Duration(hours: 6),
        timeZone: 'Europe/Stockholm',
      ),
    );
    final entry = AgendaEntry(
      school,
      Occurrence(
        eventId: 'school',
        originalStart: _tuesday,
        start: _tuesday,
        end: _tuesday.add(const Duration(hours: 6)),
      ),
    );
    final state = WeekState(
      agenda: WeekAgenda(
        start: DateTime.utc(2026, 9, 21),
        days: [
          DayAgenda(
            entries: const [],
            routines: [entry],
            unassigned: const [],
            conflicts: const [],
            nextUp: null,
          ),
        ],
      ),
      members: const [],
      colors: const {},
      initials: const {},
      location: tz.getLocation('Europe/Stockholm'),
      now: _tuesday,
      today: DateTime.utc(2026, 9, 22),
    );
    expect(
      RemoveMany.picked(state, {WeekSelection.keyFor(entry)}),
      [entry],
    );
  });

  test('two days of one weekly series are picked apart, not together', () {
    // The rule the whole feature rests on. Keyed by the event alone,
    // picking next Tuesday's training would pick every Tuesday's — and a
    // bulk remove is the worst possible place to discover that.
    final event = CalendarEvent(
      title: 'Football training',
      kind: EventKind.activity,
      series: EventSeries(
        eventId: 'football',
        localStart: _tuesday,
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      ),
    );
    AgendaEntry on(DateTime day) => AgendaEntry(
      event,
      Occurrence(
        eventId: 'football',
        originalStart: day,
        start: day,
        end: day.add(const Duration(hours: 1)),
      ),
    );

    final first = WeekSelection.keyFor(on(_tuesday));
    final next = WeekSelection.keyFor(on(_nextTuesday));

    expect(first, isNot(next));
    expect(first, contains('football'));
  });
}

final _tuesday = DateTime.utc(2026, 9, 22, 17);
final _nextTuesday = DateTime.utc(2026, 9, 29, 17);
