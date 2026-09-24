import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const erik = Member(id: 'erik', displayName: 'Erik', role: MemberRole.parent);
  const maja = Member(
    id: 'maja',
    displayName: 'Maja',
    role: MemberRole.child,
    tier: MaturityTier.kid,
  );
  const olle = Member(
    id: 'olle',
    displayName: 'Olle',
    role: MemberRole.child,
    tier: MaturityTier.teen,
  );
  const sitter = Member(
    id: 'sitter',
    displayName: 'Sara',
    role: MemberRole.helper,
  );
  const family = [anna, erik, maja, olle, sitter];
  const settings = FamilySettings(); // supervised up to kid

  const school = GeoPoint(57.6890, 11.9750);
  const home = GeoPoint(57.7000, 11.9500);
  final places = [
    const Place(
      id: 'school',
      name: 'Skolan',
      location: school,
      radiusMeters: 150,
    ),
    const Place(id: 'home', name: 'Hemma', location: home, radiusMeters: 80),
    const Place(id: 'nowhere', name: 'Tandläkaren'),
  ];

  test('distance is great-circle metres', () {
    expect(distanceMeters(school, home), closeTo(1920, 20));
    expect(distanceMeters(home, home), 0);
  });

  group('who can see a member (spec §7: no invisible watching)', () {
    test('nobody while sharing is off', () {
      expect(
        viewersOf(maja, const LocationShare(memberId: 'maja'), family),
        isEmpty,
      );
    });

    test('parents, or the whole family, never helpers', () {
      const toParents = LocationShare(
        memberId: 'olle',
        mode: ShareMode.whileUsing,
      );
      expect(viewersOf(olle, toParents, family), {'anna', 'erik'});
      const toFamily = LocationShare(
        memberId: 'anna',
        mode: ShareMode.whileUsing,
        audience: ShareAudience.family,
      );
      expect(viewersOf(anna, toFamily, family), {'erik', 'maja', 'olle'});
    });
  });

  group('being followed in the background is never silent', () {
    test('a child made to share is told, and told it was not their choice', () {
      const made = LocationShare(memberId: 'maja', floor: ShareMode.always);

      final notice = sharingNotice(maja, made, settings);

      expect(notice.mode, ShareMode.always);
      expect(notice.mustBeTold, isTrue);
      expect(notice.imposed, isTrue, reason: 'a parent set this, not Maja');
      expect(notice.mayChange, isFalse);
    });

    test('a child who chose it themselves is not told someone made them', () {
      // The floor is doing no work here: she picked the same thing. Saying
      // "your parents set this" would be a small lie told to a child.
      const hers = LocationShare(
        memberId: 'maja',
        mode: ShareMode.always,
        floor: ShareMode.always,
      );

      final notice = sharingNotice(maja, hers, settings);

      expect(notice.mode, ShareMode.always);
      expect(notice.imposed, isFalse);
    });

    test('a teen is above the floor and decides for himself', () {
      const floored = LocationShare(memberId: 'olle', floor: ShareMode.always);

      final notice = sharingNotice(olle, floored, settings);

      expect(notice.mode, ShareMode.off,
          reason: 'the floor does not reach him');
      expect(notice.imposed, isFalse);
      expect(notice.mayChange, isTrue);
    });

    test('an adult sharing in the background is told too', () {
      const mine = LocationShare(memberId: 'anna', mode: ShareMode.always);

      final notice = sharingNotice(anna, mine, settings);

      expect(notice.mustBeTold, isTrue);
      expect(notice.imposed, isFalse);
      expect(notice.mayChange, isTrue);
    });

    test('nothing to say when nothing runs in the background', () {
      for (final mode in [ShareMode.off, ShareMode.whileUsing]) {
        final notice = sharingNotice(
          anna,
          LocationShare(memberId: 'anna', mode: mode),
          settings,
        );
        expect(notice.mustBeTold, isFalse, reason: mode.name);
      }
    });

    test('always outranks while-using, so a floor of it raises the mode', () {
      const floored = LocationShare(
        memberId: 'maja',
        mode: ShareMode.whileUsing,
        floor: ShareMode.always,
      );
      expect(effectiveMode(maja, floored, settings), ShareMode.always);
    });
  });

  group('a parent’s floor, as for messages (open question 9)', () {
    const floored = LocationShare(
      memberId: 'maja',
      floor: ShareMode.whileUsing,
    );

    test('holds for a supervised child', () {
      expect(effectiveMode(maja, floored, settings), ShareMode.whileUsing);
      expect(mayPause(maja, floored, settings), isFalse);
    });

    test('is ignored above the tier: a teen decides', () {
      const teen = LocationShare(memberId: 'olle', floor: ShareMode.whileUsing);
      expect(effectiveMode(olle, teen, settings), ShareMode.off);
      expect(mayPause(olle, teen, settings), isTrue);
    });

    test('only a parent sets it, and only for a supervised child', () {
      expect(maySetFloor(anna, maja, settings), isTrue);
      expect(maySetFloor(anna, olle, settings), isFalse);
      expect(maySetFloor(olle, maja, settings), isFalse);
    });
  });

  group('what leaves the phone', () {
    final at = DateTime.utc(2026, 9, 21, 8, 12);
    const nearSchool = GeoPoint(57.6895, 11.9752); // ~55 m from its centre

    test('exact keeps the point and names the place it is in', () {
      final p = reducePosition(
        at: nearSchool,
        accuracyMeters: 12,
        capturedAt: at,
        precision: SharePrecision.exact,
        places: places,
      );
      expect(p.point, nearSchool);
      expect(p.placeId, 'school');
      expect(p.since, at);
    });

    test('place only sends no coordinates at all', () {
      final p = reducePosition(
        at: nearSchool,
        accuracyMeters: 12,
        capturedAt: at,
        precision: SharePrecision.placeOnly,
        places: places,
      );
      expect(p.point, isNull);
      expect(p.accuracyMeters, isNull);
      expect(p.placeId, 'school');
    });

    test('approximate snaps to a kilometre grid', () {
      final a = reducePosition(
        at: nearSchool,
        accuracyMeters: 12,
        capturedAt: at,
        precision: SharePrecision.approximate,
        places: places,
      );
      final b = reducePosition(
        at: const GeoPoint(57.6880, 11.9790),
        accuracyMeters: 5,
        capturedAt: at,
        precision: SharePrecision.approximate,
        places: places,
      );
      expect(a.point, b.point, reason: 'same cell, same answer');
      expect(distanceMeters(a.point!, nearSchool), lessThan(1000));
      expect(a.accuracyMeters, greaterThanOrEqualTo(1000));
    });

    test('arrival time carries over while still there', () {
      final first = reducePosition(
        at: nearSchool,
        accuracyMeters: 12,
        capturedAt: at,
        precision: SharePrecision.exact,
        places: places,
      );
      final later = reducePosition(
        at: school,
        accuracyMeters: 12,
        capturedAt: at.add(const Duration(minutes: 40)),
        precision: SharePrecision.exact,
        places: places,
        previous: first,
      );
      expect(later.since, at);
      final left = reducePosition(
        at: const GeoPoint(57.6950, 11.9600),
        accuracyMeters: 12,
        capturedAt: at.add(const Duration(hours: 1)),
        precision: SharePrecision.exact,
        places: places,
        previous: later,
      );
      expect(left.placeId, isNull);
      expect(left.since, at.add(const Duration(hours: 1)));
    });
  });

  test('a position says how old it is (spec §7 "Accuracy honesty")', () {
    final now = DateTime.utc(2026, 9, 21, 12);
    expect(isFresh(now.subtract(const Duration(minutes: 4)), now), isTrue);
    expect(isFresh(now.subtract(const Duration(minutes: 20)), now), isFalse);
  });
}
