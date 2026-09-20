import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const maja = Member(
    id: 'maja',
    displayName: 'Maja',
    role: MemberRole.child,
    tier: MaturityTier.kid,
  );
  const sitter = Member(
    id: 'sitter',
    displayName: 'Sara',
    role: MemberRole.helper,
  );

  group('who a saved password is for', () {
    test('the family scope is everyone with a device of their own', () {
      expect(canOpen(anna, const PasswordFor.family()), isTrue);
      expect(canOpen(maja, const PasswordFor.family()), isTrue);
      // A babysitter is in the family's calendar, not its passwords.
      expect(canOpen(sitter, const PasswordFor.family()), isFalse);
    });

    test('a member\'s own is theirs alone', () {
      expect(canOpen(maja, const PasswordFor.member('maja')), isTrue);
      expect(canOpen(anna, const PasswordFor.member('maja')), isFalse);
      expect(canOpen(anna, const PasswordFor.member('anna')), isTrue);
    });

    test('a former member opens nothing', () {
      final gone = Member(
        id: 'gone',
        displayName: 'G',
        role: MemberRole.parent,
        endedAt: DateTime.utc(2026),
      );
      expect(canOpen(gone, const PasswordFor.family()), isFalse);
      expect(canOpen(gone, const PasswordFor.member('gone')), isFalse);
    });
  });

  group('making one up', () {
    test('the length asked for, from every kind of character', () {
      final made = generatePassword(random: Random(7));
      expect(made.length, 20);
      expect(made, matches(RegExp(r'[a-z]')));
      expect(made, matches(RegExp(r'[A-Z]')));
      expect(made, matches(RegExp(r'[0-9]')));
      expect(made, matches(RegExp(r'[-_!?@#%+=]')));
      expect(generatePassword(length: 12, random: Random(7)).length, 12);
    });

    test('nothing that is read back wrongly over the phone', () {
      final made = generatePassword(length: 4000, random: Random(3));
      // No l/I/1, O/0: a password dictated to a grandparent has to survive.
      expect(made, isNot(matches(RegExp(r'[lI1O0]'))));
    });

    test('two never come out the same', () {
      final made = {for (var i = 0; i < 200; i++) generatePassword()};
      expect(made, hasLength(200));
    });

    test('a short one is still not a toy', () {
      expect(() => generatePassword(length: 3), throwsArgumentError);
    });
  });
}
