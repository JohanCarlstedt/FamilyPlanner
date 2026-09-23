import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec section 3, "Contributions": what the stored objects count as.
void main() {
  final tuesday = DateTime.utc(2026, 9, 22, 16);

  (String, ActionPayload) chore(
    String id, {
    required ActionState state,
    String? by = 'maja',
    bool approval = false,
  }) {
    final written = ActionPayload.write(
      title: 'Diska',
      kind: ActionKind.chore,
      requiresApproval: approval,
    );
    written.payload
      ..setText('state', state.name)
      ..setText('completedBy', by)
      ..setText('completedAt', tuesday.toIso8601String());
    return (id, ActionPayload.read(written.payload));
  }

  (String, HomeworkPayload) homework(
    String id, {
    HomeworkState state = HomeworkState.done,
    String? seenBy,
  }) {
    var h = HomeworkPayload.write(
      memberId: 'maja',
      title: 'Glosor',
      dueAt: tuesday.add(const Duration(days: 2)),
    ).withState(state, at: tuesday);
    if (seenBy != null) h = h.seen(seenBy, tuesday.add(const Duration(days: 6)));
    return (id, h);
  }

  List<Contribution> from({
    List<(String, ActionPayload)> actions = const [],
    List<(String, HomeworkPayload)> work = const [],
  }) => FamilyStore.contributionsFrom(actions: actions, homework: work);

  group('chores', () {
    test('count for whoever did them, once done', () {
      final c = from(actions: [chore('a', state: ActionState.done, by: 'leo')]);
      expect(c.single.memberId, 'leo');
      expect(c.single.growsWorld, isTrue);
    });

    test('one waiting for approval counts for nothing yet', () {
      // Approval is the guard against ticking without doing.
      expect(
        from(actions: [chore('a', state: ActionState.done, approval: true)]),
        isEmpty,
      );
      expect(
        from(actions: [chore('a', state: ActionState.approved, approval: true)]),
        hasLength(1),
      );
    });

    test('open, skipped and cancelled ones count for nothing', () {
      expect(
        from(actions: [
          chore('a', state: ActionState.open, by: null),
          chore('b', state: ActionState.skipped),
          chore('c', state: ActionState.cancelled),
        ]),
        isEmpty,
      );
    });
  });

  group('homework', () {
    test('finished fills the jar but not the world, until a parent looks', () {
      final unseen = from(work: [homework('h')]).single;
      expect(unseen.growsWorld, isFalse);
      final seen = from(work: [homework('h', seenBy: 'anna')]).single;
      expect(seen.growsWorld, isTrue);
    });

    test('counts in the week it was finished, whenever a parent looks', () {
      // A parent seeing it the following Monday must not carry it into
      // the next week's jar.
      final seen = from(work: [homework('h', seenBy: 'anna')]).single;
      expect(seen.at, tuesday);
    });

    test('unfinished homework counts for nothing', () {
      expect(
        from(work: [homework('h', state: HomeworkState.inProgress)]),
        isEmpty,
      );
    });

    test('reopening it forgets when it was finished', () {
      final done = homework('h').$2;
      final again = done
          .withState(HomeworkState.inProgress)
          .withState(HomeworkState.done, at: tuesday.add(const Duration(days: 3)));
      expect(again.finishedAt, tuesday.add(const Duration(days: 3)));
    });
  });

  group('settings', () {
    test('the jar and the switch survive a round trip', () {
      const set = FamilySettings(rewardsOn: true, jarSize: 12, jarFor: 'Bio');
      final read = SettingsPayload.read(
        SettingsPayload.write(settings: set).payload,
      ).toDomain();
      expect((read.rewardsOn, read.jarSize, read.jarFor), (true, 12, 'Bio'));
    });

    test('settings saved before rewards existed read as off', () {
      final old = SettingsPayload.write(settings: FamilySettings.defaults).payload
        ..setBoolean('rewards', null)
        ..setInteger('jarSize', null);
      final read = SettingsPayload.read(old).toDomain();
      expect(read.rewardsOn, isFalse);
      expect(read.jarSize, 10);
    });

    test('a jar with no room is not a jar', () {
      final p = SettingsPayload.write(settings: FamilySettings.defaults).payload
        ..setInteger('jarSize', 0);
      expect(SettingsPayload.read(p).toDomain().jarSize, 10);
    });
  });

  group('a world', () {
    test('what is placed, and how many seeds are still waiting', () {
      final world = WorldPayload.write(
        memberId: 'maja',
        theme: WorldTheme.aquarium,
        placements: [
          WorldPlacement(level: 1, spot: 0, thing: 'clownfish', at: tuesday),
          WorldPlacement(level: 1, spot: 3, thing: 'seaweed', at: tuesday),
        ],
      );
      final read = WorldPayload.read(world.payload);
      expect(read.theme, WorldTheme.aquarium);
      expect(read.placedIn(1).keys, {0, 3});
      const progress = WorldProgress(seeds: 5, level: 1, filled: 5, room: 8);
      expect(read.waiting(progress), 3);
    });

    test('two things in one spot: the later is what is there', () {
      final world = WorldPayload.write(
        memberId: 'maja',
        theme: WorldTheme.garden,
        placements: [
          WorldPlacement(level: 1, spot: 2, thing: 'tulip', at: tuesday),
          WorldPlacement(
            level: 1,
            spot: 2,
            thing: 'sunflower',
            at: tuesday.add(const Duration(hours: 1)),
          ),
        ],
      );
      expect(world.placedIn(1)[2]!.thing, 'sunflower');
    });

    test('a thing this version has never heard of is kept, not dropped', () {
      final world = WorldPayload.write(
        memberId: 'maja',
        theme: WorldTheme.space,
        placements: [
          WorldPlacement(level: 1, spot: 0, thing: 'wormhole-v9', at: tuesday),
        ],
      );
      expect(WorldPayload.read(world.payload).placedIn(1)[0]!.thing, 'wormhole-v9');
    });
  });
}
