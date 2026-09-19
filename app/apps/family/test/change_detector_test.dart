import 'package:family/src/reminders/change_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = ChangeDetector();
  final now = DateTime.utc(2026, 9, 14, 8);
  final thursday = DateTime.utc(2026, 9, 17, 15, 30);

  EventSnapshot training({
    String when = '2026-09-03T17:30|60|Europe/Stockholm|weekly',
    String? place = 'hall',
    String? responsible = 'anna',
    List<String> participants = const ['maja'],
    bool gone = false,
    String? editedBy = 'erik',
    Map<String, ExceptionSnapshot> exceptions = const {},
  }) => EventSnapshot(
    id: 'training',
    title: 'Training',
    when: when,
    place: place,
    responsible: responsible,
    participants: participants,
    gone: gone,
    editedBy: editedBy,
    exceptions: exceptions,
  );

  List<EventChange> detect(
    EventSnapshot? before,
    EventSnapshot? after, {
    String member = 'maja',
    DateTime? next,
  }) => detector.detect(
    before: {'training': ?before},
    after: {'training': ?after},
    memberId: member,
    now: now,
    nextStart: (_, occurrence) => occurrence ?? next ?? thursday,
  );

  test('time and place in one edit are one change', () {
    final changes = detect(
      training(),
      training(
        when: '2026-09-03T18:00|60|Europe/Stockholm|weekly',
        place: 'pool',
      ),
    );
    expect(changes.single.kind, ChangeKind.moved);
    expect(changes.single.timeChanged, isTrue);
    expect(changes.single.placeChanged, isTrue);
    expect(changes.single.occurrence, isNull, reason: 'the whole series');
  });

  test('a title change is minor: nothing', () {
    final after = EventSnapshot.fromJson(
      training().toJson()..['title'] = 'Football training',
    );
    expect(detect(training(), after), isEmpty);
  });

  test('never the person who made the edit', () {
    final changes = detect(
      training(),
      training(place: 'pool', editedBy: 'maja'),
    );
    expect(changes, isEmpty);
  });

  test('people the event doesn\'t involve hear nothing', () {
    expect(
      detect(training(), training(place: 'pool'), member: 'erik'),
      isEmpty,
    );
  });

  test('cancelling one occurrence names it', () {
    final at = thursday.toIso8601String();
    final changes = detect(
      training(),
      training(
        exceptions: {
          at: const ExceptionSnapshot(
            cancelled: true,
            moved: '|',
            responsible: null,
            editedBy: 'erik',
          ),
        },
      ),
    );
    expect(changes.single.kind, ChangeKind.cancelled);
    expect(changes.single.occurrence, thursday);
  });

  test('a driver swap tells both drivers', () {
    final swapped = training(responsible: 'erik', editedBy: 'maja');
    expect(
      detect(training(), swapped, member: 'anna').single.kind,
      ChangeKind.someoneElseDrives,
    );
    final toAnna = training(responsible: 'anna', editedBy: 'maja');
    expect(
      detect(training(responsible: 'erik'), toAnna, member: 'anna').single.kind,
      ChangeKind.youDrive,
    );
  });

  test('added to and taken off an event', () {
    final withAnna = training(participants: const ['maja', 'anna']);
    expect(
      detect(training(), withAnna, member: 'anna').map((c) => c.kind),
      contains(ChangeKind.youAreIn),
    );
    expect(
      detect(withAnna, training(), member: 'anna').map((c) => c.kind),
      contains(ChangeKind.youAreOut),
    );
  });

  test('changes more than a week out wait; cancellations never do', () {
    final far = DateTime.utc(2026, 10, 15, 15, 30);
    expect(detect(training(), training(place: 'pool'), next: far), isEmpty);
    expect(
      detect(training(), training(gone: true), next: far).single.kind,
      ChangeKind.cancelled,
    );
  });

  test('the past never notifies', () {
    final past = DateTime.utc(2026, 9, 10, 15, 30);
    expect(detect(training(), training(gone: true), next: past), isEmpty);
  });

  test('a new event someone else made, that involves them', () {
    expect(detect(null, training()).single.kind, ChangeKind.added);
    expect(detect(null, training(editedBy: 'maja')), isEmpty);
  });

  test('snapshots survive JSON', () {
    final snapshot = training(
      exceptions: {
        thursday.toIso8601String(): const ExceptionSnapshot(
          cancelled: false,
          moved: '2026-09-17T16:00:00.000Z|90',
          responsible: 'erik',
          editedBy: 'anna',
        ),
      },
    );
    final back = EventSnapshot.fromJson(snapshot.toJson());
    expect(back.toJson(), snapshot.toJson());
  });
}
