import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// The password list as a vault: kinds of item, how strong a password is,
/// the security check, the generator and the Wi-Fi join code.
void main() {
  group('item types', () {
    test('each has exactly one main field, stored as the secret', () {
      for (final type in VaultItemType.values) {
        expect(vaultFields[type]!.where((f) => f.main), hasLength(1),
            reason: type.name);
        expect(mainFieldOf(type).secret, isTrue, reason: type.name);
      }
    });

    test('a login is what a login always was', () {
      expect([for (final f in vaultFields[VaultItemType.login]!) f.key],
          ['username', 'password', 'url', 'note']);
    });
  });

  group('strength', () {
    test('short, common, or one character over and over is weak', () {
      for (final p in [
        '',
        'abc',
        'password',
        'Lösenord',
        '123456789',
        'aaaaaaaaaaaa',
        'sommar'
      ]) {
        expect(strengthOf(p), PasswordStrength.weak, reason: p);
      }
    });

    test('a run in order counts for little', () {
      expect(strengthOf('abcdefgh12'), isNot(PasswordStrength.strong));
    });

    test('length and variety make it strong', () {
      expect(strengthOf('kT7#mq9!Lp2x'), PasswordStrength.strong);
      expect(
          strengthOf('hasthagen-blabar-solros-kajak'), PasswordStrength.strong,
          reason: 'a long passphrase is strong on length');
      expect(strengthOf('Sommar2026'), PasswordStrength.fair);
    });

    test('what the generator makes is strong', () {
      for (var i = 0; i < 20; i++) {
        expect(strengthOf(generateWith(random: Random(i))),
            PasswordStrength.strong);
      }
    });
  });

  group('security check', () {
    final now = DateTime.utc(2026, 10, 10);
    VaultEntry login(String id, String secret, {DateTime? changed}) =>
        VaultEntry(
          id: id,
          type: VaultItemType.login,
          title: id,
          secret: secret,
          changedAt: changed,
        );

    test('weak, reused and old, each named', () {
      final check = securityCheck([
        login('mail', 'kT7#mq9!Lp2x'),
        login('bank', 'kT7#mq9!Lp2x'),
        login('shop', 'password'),
        login('old', 'Zq8!vR3#nW6p', changed: DateTime.utc(2025, 1, 1)),
        login('fine', 'Hy4@pL9!sD2w', changed: DateTime.utc(2026, 9, 1)),
      ], now: now);
      expect(check.withIssue(VaultIssue.reused),
          unorderedEquals(['mail', 'bank']));
      expect(check.withIssue(VaultIssue.weak), ['shop']);
      expect(check.withIssue(VaultIssue.old), ['old']);
      expect(check.issues.containsKey('fine'), isFalse);
      expect(check.score, lessThan(100));
    });

    test('nothing wrong scores 100, and an empty list is not a failing one',
        () {
      expect(securityCheck([login('a', 'kT7#mq9!Lp2x')], now: now).score, 100);
      expect(securityCheck(const [], now: now).score, 100);
    });

    test('a card number or a note is not judged as a password', () {
      final check = securityCheck([
        const VaultEntry(
          id: 'card',
          type: VaultItemType.card,
          title: 'Visa',
          secret: '4111111111111111',
        ),
        const VaultEntry(
          id: 'note',
          type: VaultItemType.note,
          title: 'Codes',
          secret: '1234',
        ),
      ], now: now);
      expect(check.issues, isEmpty);
    });
  });

  group('generator', () {
    test('the length asked for, and only the kinds asked for', () {
      final p = generateWith(
        length: 12,
        capitals: false,
        symbols: false,
        random: Random(1),
      );
      expect(p, hasLength(12));
      expect(RegExp(r'^[a-z2-9]+$').hasMatch(p), isTrue);
      expect(RegExp('[2-9]').hasMatch(p), isTrue, reason: 'digits asked for');
    });

    test('too short is refused', () {
      expect(() => generateWith(length: 7), throwsArgumentError);
    });
  });

  group('Wi-Fi join code', () {
    test('the standard string, with reserved characters escaped', () {
      expect(
        wifiJoinCode(ssid: 'Svensson; 5G', password: r'a:b\c'),
        r'WIFI:T:WPA;S:Svensson\; 5G;P:a\:b\\c;;',
      );
    });

    test('an open network has no password in it', () {
      expect(
          wifiJoinCode(ssid: 'Guest', password: ''), 'WIFI:T:nopass;S:Guest;;');
    });
  });
}
