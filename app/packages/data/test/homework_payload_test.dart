import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who is seeing to a piece of homework.
///
/// Added late, so the field has to behave the way every late field here
/// has to: present when it is set, absent when it never was, and never
/// quietly dropped by a rewrite that was about something else
/// (CLAUDE.md invariant 3).
void main() {
  final due = DateTime.utc(2026, 9, 25, 8);

  HomeworkPayload homework({
    Payload? existing,
    String? responsible,
    bool clear = false,
    String title = 'Glosor',
  }) => HomeworkPayload.write(
    existing: existing,
    memberId: 'maja',
    title: title,
    dueAt: due,
    responsibleMemberId: responsible,
    clearResponsible: clear,
  );

  test('nobody is on it until somebody is', () {
    expect(homework().responsibleMemberId, isNull);
  });

  test('and then it is them', () {
    final h = homework(responsible: 'anna');
    expect(HomeworkPayload.read(h.payload).responsibleMemberId, 'anna');
  });

  test('an edit about something else does not drop them', () {
    // The homework dialog rewrites the whole payload to change a title.
    // If that counted as "no responsible given", Anna would quietly stop
    // being on it every time anyone corrected a spelling.
    final first = homework(responsible: 'anna');
    final renamed = homework(existing: first.payload, title: 'Glosor v39');
    expect(renamed.title, 'Glosor v39');
    expect(renamed.responsibleMemberId, 'anna');
  });

  test('and saying nobody is on it works', () {
    final first = homework(responsible: 'anna');
    final cleared = homework(existing: first.payload, clear: true);
    expect(cleared.responsibleMemberId, isNull);
  });

  test('homework written before the field existed still reads', () {
    final old = HomeworkPayload.write(
      memberId: 'maja',
      title: 'Läsläxa',
      dueAt: due,
    );
    final read = HomeworkPayload.read(old.payload);
    expect(read.responsibleMemberId, isNull);
    expect(read.title, 'Läsläxa');
    expect(read.state, HomeworkState.notStarted);
  });
}
