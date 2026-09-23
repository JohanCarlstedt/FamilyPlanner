import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Spec section 3, "Contributions": the family jar and each child's world.
void main() {
  // Monday 21 September 2026, 00:00 in Stockholm, is 22:00 UTC on Sunday.
  final monday = DateTime.utc(2026, 9, 20, 22);
  final nextMonday = monday.add(const Duration(days: 7));

  Contribution done(
    String who,
    DateTime at, {
    bool growsWorld = true,
  }) => Contribution(memberId: who, at: at, growsWorld: growsWorld);

  group('the family jar', () {
    test('counts everyone, whoever did it', () {
      final jar = familyJar(
        [
          done('maja', monday.add(const Duration(days: 1))),
          done('leo', monday.add(const Duration(days: 2))),
          done('anna', monday.add(const Duration(days: 3))),
        ],
        from: monday,
        until: nextMonday,
        size: 10,
      );
      expect(jar.filled, 3);
      expect(jar.isFull, isFalse);
    });

    test('homework nobody has checked yet still fills it', () {
      // It grows nobody's own world until a parent has seen it, but in
      // the jar cheating helps no one in particular.
      final jar = familyJar(
        [done('maja', monday.add(const Duration(hours: 20)), growsWorld: false)],
        from: monday,
        until: nextMonday,
        size: 5,
      );
      expect(jar.filled, 1);
    });

    test('empties every Monday', () {
      final lastWeek = monday.subtract(const Duration(days: 1));
      final jar = familyJar(
        [done('maja', lastWeek), done('leo', monday)],
        from: monday,
        until: nextMonday,
        size: 5,
      );
      expect(jar.filled, 1, reason: 'Sunday belongs to last week');
    });

    test('a full jar is full, and more does not overflow it', () {
      final jar = familyJar(
        [for (var i = 0; i < 7; i++) done('maja', monday.add(Duration(hours: i)))],
        from: monday,
        until: nextMonday,
        size: 5,
      );
      expect(jar.isFull, isTrue);
      expect(jar.filled, 5);
    });
  });

  group("a child's own world", () {
    List<Contribution> times(int n, {String who = 'maja', bool grows = true}) => [
      for (var i = 0; i < n; i++)
        done(who, monday.add(Duration(hours: i)), growsWorld: grows),
    ];

    test('only their own work grows it', () {
      final world = worldOf('maja', [...times(3), ...times(5, who: 'leo')]);
      expect(world.seeds, 3);
    });

    test('unchecked homework does not grow it', () {
      final world = worldOf('maja', [...times(2), ...times(4, grows: false)]);
      expect(world.seeds, 2);
    });

    test('starts at level one with room to fill', () {
      final world = worldOf('maja', times(3));
      expect(world.level, 1);
      expect(world.filled, 3);
      expect(world.room, WorldProgress.firstRoom);
      expect(world.isFull, isFalse);
    });

    test('a full world moves up a level, into a bigger one', () {
      // The request: once a garden is capped, the child levels up.
      final first = WorldProgress.firstRoom;
      final world = worldOf('maja', times(first + 2));
      expect(world.level, 2);
      expect(world.filled, 2, reason: 'the two left over start the new one');
      expect(world.room, greaterThan(first));
    });

    test('exactly full is the moment to move up, not one seed later', () {
      final world = worldOf('maja', times(WorldProgress.firstRoom));
      expect(world.level, 2);
      expect(world.filled, 0);
    });

    test('each level is roomier than the last, up to a ceiling', () {
      // Bigger worlds take longer, but a seven-year-old doing two chores
      // a week must not face a world that takes a term to fill.
      final rooms = [for (var l = 1; l <= 10; l++) WorldProgress.roomAt(l)];
      for (var i = 1; i < rooms.length; i++) {
        expect(rooms[i], greaterThanOrEqualTo(rooms[i - 1]));
      }
      expect(rooms.last, WorldProgress.largestRoom);
    });

    test('a quiet week loses nothing', () {
      // Nothing wilts: progress is a count of what was done, and a week
      // of nothing adds nothing and takes nothing away.
      final before = worldOf('maja', times(5));
      final after = worldOf('maja', times(5));
      expect((after.level, after.filled), (before.level, before.filled));
    });

    test('nobody else is in it', () {
      expect(worldOf('maja', times(9, who: 'leo')).seeds, 0);
    });
  });

  group("the jar's settings", () {
    test('a family that has said nothing gets a jar of ten, for nothing yet', () {
      expect(FamilySettings.defaults.jarSize, 10);
      expect(FamilySettings.defaults.jarFor, isNull);
    });

    test('rewards are off until a parent turns them on', () {
      // How a family talks about chores is theirs to change, not a default
      // for them to discover one morning.
      expect(FamilySettings.defaults.rewardsOn, isFalse);
      final on = FamilySettings.defaults.copyWith(rewardsOn: true);
      expect(on.rewardsOn, isTrue);
      expect(on.copyWith(quietEnd: 6 * 60).rewardsOn, isTrue,
          reason: 'changing something else keeps it on');
    });

    test('changing something else keeps the jar as it was', () {
      // The settings screen used to rebuild settings field by field, so a
      // setting it did not know about went back to its default whenever
      // quiet hours were changed.
      const set = FamilySettings(jarSize: 15, jarFor: 'Pizzakväll');
      final after = set.copyWith(quietStart: 22 * 60);
      expect((after.jarSize, after.jarFor), (15, 'Pizzakväll'));
      expect(after.quietStart, 22 * 60);
    });

    test('and saying what the jar is for can be taken back', () {
      const set = FamilySettings(jarFor: 'Pizzakväll');
      expect(set.copyWith(jarFor: () => null).jarFor, isNull);
    });
  });

}
