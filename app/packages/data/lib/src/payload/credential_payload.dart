import 'package:domain/domain.dart';

import 'payload.dart';

/// Everyone in the family with a device of their own. Not `all`: that
/// includes the kitchen tablet, and a screen on the wall is read by
/// whoever walks past it (crypto doc §6).
const familyPasswordsGroup = 'passwords';

/// One member's own devices, and nobody else's — their parents included.
String memberPasswordsGroup(String memberId) => 'passwords:$memberId';

/// The group a password saved for [scope] is sealed to.
String passwordGroup(PasswordFor scope) => switch (scope) {
  FamilyPassword() => familyPasswordsGroup,
  MemberPassword(:final memberId) => memberPasswordsGroup(memberId),
};

/// A saved password (kind 28): what it is for, who it belongs to, and the
/// secret itself. Everything but the routing metadata is encrypted, like
/// every other object here.
class CredentialPayload {
  CredentialPayload._(this.payload);

  static const version = 1;

  factory CredentialPayload.read(Payload payload) =>
      CredentialPayload._(payload);

  factory CredentialPayload.write({
    Payload? existing,
    required String title,
    required String secret,
    required PasswordFor scope,
    String? username,
    String? url,
    String? note,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setText('secret', secret)
      ..setText('username', username)
      ..setText('url', url)
      ..setText('note', note)
      ..setText('scope', switch (scope) {
        FamilyPassword() => 'family',
        MemberPassword() => 'member',
      })
      ..setText('member', switch (scope) {
        FamilyPassword() => null,
        MemberPassword(:final memberId) => memberId,
      });
    return CredentialPayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  String get secret => payload.text('secret') ?? '';
  String? get username => payload.text('username');
  String? get url => payload.text('url');
  String? get note => payload.text('note');

  PasswordFor get scope => switch (payload.text('member')) {
    final member? when payload.text('scope') == 'member' => PasswordFor.member(
      member,
    ),
    _ => const PasswordFor.family(),
  };
}
