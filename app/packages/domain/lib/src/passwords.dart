import 'dart:math';

import 'family.dart';

/// Who a saved password is for. Not a preference: each one decides which
/// key the entry is sealed to, so a member who may not open one has no way
/// to (crypto doc §3, as for wishlist claims).
sealed class PasswordFor {
  const PasswordFor();

  /// Everyone in the family with a device of their own: the wifi, the
  /// streaming account, the library card. Never a helper's phone, and
  /// never the kitchen tablet — a screen on the wall is read by whoever
  /// walks past it.
  const factory PasswordFor.family() = FamilyPassword;

  /// One member's own. Their devices hold the key; nobody else's does,
  /// parents included.
  const factory PasswordFor.member(String memberId) = MemberPassword;
}

class FamilyPassword extends PasswordFor {
  const FamilyPassword();
}

class MemberPassword extends PasswordFor {
  const MemberPassword(this.memberId);

  final String memberId;
}

/// Whether [member] is among those a password saved [scope] is for.
bool canOpen(Member member, PasswordFor scope) {
  if (!member.isActive) return false;
  return switch (scope) {
    FamilyPassword() => member.role != MemberRole.helper && !member.isCoParent,
    MemberPassword(:final memberId) => member.id == memberId,
  };
}

/// Letters that survive being read aloud or copied off a screen: no l, I,
/// 1, O or 0, which are the ones people get wrong.
const _letters = 'abcdefghijkmnopqrstuvwxyz';
const _capitals = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _digits = '23456789';
const _symbols = '-_!?@#%+=';

/// A password worth saving: long, from every kind of character, and drawn
/// from the platform's secure random unless a [random] is given for a test.
String generatePassword({int length = 20, Random? random}) {
  if (length < 8) {
    throw ArgumentError.value(length, 'length', 'too short to be worth saving');
  }
  final source = random ?? Random.secure();
  const alphabets = [_letters, _capitals, _digits, _symbols];
  // One of each first, so "every kind" is a fact rather than a likelihood.
  final characters = [
    for (final alphabet in alphabets) alphabet[source.nextInt(alphabet.length)],
  ];
  const all = _letters + _capitals + _digits + _symbols;
  while (characters.length < length) {
    characters.add(all[source.nextInt(all.length)]);
  }
  // Otherwise the first four characters always run lower, upper, digit,
  // symbol, which is a pattern worth not having.
  characters.shuffle(source);
  return characters.join();
}
