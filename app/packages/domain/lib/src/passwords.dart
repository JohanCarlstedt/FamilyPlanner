import 'dart:math';

import 'family.dart';
import 'vault.dart';

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

  /// The parents' own: the bank, the insurance, the alarm code. The
  /// parents' devices, not the children's, and not the other home's.
  const factory PasswordFor.parents() = ParentsPassword;

  /// The children's: a game account, the school tablet. The children's
  /// devices, and their parents', so a forgotten one can be looked up.
  const factory PasswordFor.children() = ChildrenPassword;
}

class ParentsPassword extends PasswordFor {
  const ParentsPassword();
}

class ChildrenPassword extends PasswordFor {
  const ChildrenPassword();
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
    ParentsPassword() => member.role == MemberRole.parent && !member.isCoParent,
    ChildrenPassword() =>
      member.role == MemberRole.child ||
          (member.role == MemberRole.parent && !member.isCoParent),
  };
}

/// A password worth saving: long, from every kind of character, and drawn
/// from the platform's secure random unless a [random] is given for a test.
String generatePassword({int length = 20, Random? random}) =>
    generateWith(length: length, random: random);
