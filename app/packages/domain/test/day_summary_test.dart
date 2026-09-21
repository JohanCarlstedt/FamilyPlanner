import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 7);

  AgendaEntry entry(
    String title,
    int hour, {
    EventKind kind = EventKind.activity,
    EventStatus status = EventStatus.confirmed,
  }) {
    final start = DateTime.utc(2026, 9, 22, hour);
    final event = CalendarEvent(
      title: title,
      kind: kind,
      status: status,
      series: EventSeries(
        eventId: title,
        localStart: start,
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
      ),
    );
    return AgendaEntry(
      event,
      Occurrence(
        eventId: title,
        originalStart: start,
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
    );
  }

  DayAgenda agenda({
    List<AgendaEntry> entries = const [],
    List<AgendaEntry> routines = const [],
    List<AgendaEntry> unassigned = const [],
    List<Conflict> conflicts = const [],
    List<Absence> away = const [],
  }) => DayAgenda(
    entries: entries,
    routines: routines,
    unassigned: unassigned,
    conflicts: conflicts,
    away: away,
    nextUp: entries.where((e) => e.start.isAfter(now)).firstOrNull,
  );

  test('a quiet day says so, and says it about itself only', () {
    final s = summariseDay(agenda: agenda(), todos: 0, now: now);
    expect(s.isQuiet, isTrue);
    expect(s.events, 0);
    expect(s.nextStart, isNull);
    expect(s.needsAttention, isFalse);
  });

  test('routines and cancellations are not things happening today', () {
    // "Six things today" that counts breakfast, bedtime and the match
    // that was called off is not a number anyone can act on.
    final s = summariseDay(
      agenda: agenda(
        entries: [
          entry('Training', 17),
          entry('Match', 19, status: EventStatus.cancelled),
        ],
        routines: [entry('Bedtime', 20, kind: EventKind.routine)],
      ),
      todos: 0,
      now: now,
    );
    expect(s.events, 1);
    expect(s.isQuiet, isFalse);
  });

  test('the next start is the next one, not the day\'s first', () {
    // Read at six in the evening, "first at 08:00" is about a morning
    // that has been and gone.
    final s = summariseDay(
      agenda: agenda(entries: [entry('School', 8), entry('Training', 17)]),
      todos: 0,
      now: DateTime.utc(2026, 9, 22, 12),
    );
    expect(s.nextStart, DateTime.utc(2026, 9, 22, 17));
  });

  test('a cancelled event is never what comes next', () {
    final s = summariseDay(
      agenda: agenda(
        entries: [entry('Match', 17, status: EventStatus.cancelled)],
      ),
      todos: 0,
      now: now,
    );
    expect(s.nextStart, isNull);
    expect(s.events, 0);
  });

  test('what wants a decision is counted apart from what is simply on', () {
    final unassigned = entry('Swimming', 16);
    final s = summariseDay(
      agenda: agenda(
        entries: [unassigned, entry('Training', 17)],
        unassigned: [unassigned],
        conflicts: [Conflict('anna', unassigned, entry('Training', 17))],
      ),
      todos: 2,
      now: now,
    );
    expect(s.events, 2);
    expect(s.unassigned, 1);
    expect(s.conflicts, 1);
    expect(s.todos, 2);
    expect(s.needsAttention, isTrue);
  });

  test('to-dos alone make a day worth reading about', () {
    final s = summariseDay(agenda: agenda(), todos: 3, now: now);
    expect(s.isQuiet, isFalse);
    expect(s.todos, 3);
  });

  test('who is away, named, without repeating a name', () {
    final s = summariseDay(
      agenda: agenda(
        away: [
          Absence(
            id: 'a',
            title: 'Sportlov',
            startsOn: DateTime.utc(2026, 9, 22),
            endsOn: DateTime.utc(2026, 9, 26),
            memberIds: const {'ella'},
          ),
          Absence(
            id: 'b',
            title: 'Skidresa',
            startsOn: DateTime.utc(2026, 9, 22),
            endsOn: DateTime.utc(2026, 9, 22),
            memberIds: const {'ella', 'maja'},
          ),
        ],
      ),
      todos: 0,
      now: now,
    );
    expect(s.awayMemberIds, ['ella', 'maja']);
    expect(s.isQuiet, isFalse);
  });

  test('an absence for the whole family names nobody', () {
    final s = summariseDay(
      agenda: agenda(
        away: [
          Absence(
            id: 'a',
            title: 'Jul',
            startsOn: DateTime.utc(2026, 9, 22),
            endsOn: DateTime.utc(2026, 9, 22),
          ),
        ],
      ),
      todos: 0,
      now: now,
    );
    expect(s.awayMemberIds, isEmpty);
    // Still not a quiet day: the whole family being away is the thing
    // about the day.
    expect(s.isQuiet, isFalse);
  });
}
