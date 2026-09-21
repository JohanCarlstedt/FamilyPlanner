import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 12);

  group('an install that has not asked', () {
    test('has nothing, and says it does not know', () {
      const nothing = Entitlement.unknown();
      expect(nothing.known, isFalse);
      expect(nothing.isPremiumAt(now), isFalse);
    });
  });

  group('premium in force', () {
    test('lasts until the date the server gave', () {
      final paid = Entitlement(
        until: now.add(const Duration(days: 20)),
        checkedAt: now,
        source: EntitlementSource.appStore,
      );
      expect(paid.isPremiumAt(now), isTrue);
      expect(paid.allows(PaidFeature.map, now), isTrue);
      expect(paid.isPremiumAt(now.add(const Duration(days: 19))), isTrue);

      // Past the date it is grace that keeps it, not the subscription —
      // this install last heard from the server before expiry, so it has
      // no way to know a renewal did not happen. The group below covers
      // where that ends.
      expect(paid.isPremiumAt(now.add(const Duration(days: 21))), isTrue);

      // Once the server has been asked after expiry and given the same
      // date, it really is over.
      final told = Entitlement(
        until: now.add(const Duration(days: 20)),
        checkedAt: now.add(const Duration(days: 20, minutes: 1)),
        source: EntitlementSource.appStore,
      );
      expect(told.isPremiumAt(now.add(const Duration(days: 21))), isFalse);
    });

    test('a family that never paid has nothing', () {
      final free = Entitlement(until: null, checkedAt: now);
      expect(free.known, isTrue);
      for (final feature in PaidFeature.values) {
        expect(free.allows(feature, now), isFalse, reason: feature.name);
      }
    });
  });

  group('a server we cannot reach', () {
    // A subscription renews on the day it expires. A phone offline across
    // that day has not stopped paying; it has stopped hearing.
    final expires = now.add(const Duration(days: 1));

    test('keeps premium for a week past expiry when we never got an answer', () {
      final lastHeard = Entitlement(until: expires, checkedAt: now);

      expect(lastHeard.isPremiumAt(expires.add(const Duration(days: 3))), isTrue);
      expect(lastHeard.isPremiumAt(expires.add(const Duration(days: 6))), isTrue);
    });

    test('but not forever', () {
      final lastHeard = Entitlement(until: expires, checkedAt: now);
      expect(lastHeard.isPremiumAt(expires.add(const Duration(days: 8))), isFalse);
    });

    test('and not at all once the server has actually said it is over', () {
      // Asked after it ran out and told the same date: that is an answer,
      // not silence, so there is nothing to be generous about.
      final told = Entitlement(
        until: expires,
        checkedAt: expires.add(const Duration(minutes: 5)),
      );
      expect(told.isPremiumAt(expires.add(const Duration(hours: 1))), isFalse);
    });

    test('a family that never paid gets no grace either', () {
      final free = Entitlement(until: null, checkedAt: now);
      expect(free.isPremiumAt(now.add(const Duration(days: 3))), isFalse);
    });
  });

  group('caching it across a restart', () {
    test('survives a round trip', () {
      final paid = Entitlement(
        until: now.add(const Duration(days: 30)),
        checkedAt: now,
        source: EntitlementSource.granted,
      );

      final back = Entitlement.fromJson(
        Map<String, dynamic>.from(paid.toJson()),
      );

      expect(back.until, paid.until);
      expect(back.checkedAt, paid.checkedAt);
      expect(back.source, EntitlementSource.granted);
      expect(back.isPremiumAt(now), isTrue);
    });

    test('a cache written before there was one reads as unknown', () {
      final back = Entitlement.fromJson(const {});
      expect(back.known, isFalse);
      expect(back.isPremiumAt(now), isFalse);
    });
  });
}
