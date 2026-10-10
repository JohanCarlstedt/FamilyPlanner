import 'package:domain/domain.dart';

import 'payload.dart';

/// Everyone in the family with a device of their own. Not `all`: that
/// includes the kitchen tablet, and a screen on the wall is read by
/// whoever walks past it (crypto doc §6).
const familyPasswordsGroup = 'passwords';

/// One member's own devices, and nobody else's — their parents included.
String memberPasswordsGroup(String memberId) => 'passwords:$memberId';

/// The parents' devices. Named apart from a member's own group, which is
/// `passwords:` and a member id.
const parentsPasswordsGroup = 'passwords-parents';

/// The children's devices and their parents'.
const childrenPasswordsGroup = 'passwords-children';

/// The group a password saved for [scope] is sealed to.
String passwordGroup(PasswordFor scope) => switch (scope) {
  FamilyPassword() => familyPasswordsGroup,
  MemberPassword(:final memberId) => memberPasswordsGroup(memberId),
  ParentsPassword() => parentsPasswordsGroup,
  ChildrenPassword() => childrenPasswordsGroup,
};

/// Whether a device of [memberId], a [role], belongs in the passwords
/// [group]: the one rule for granting a passwords key, and for granting it
/// again after a rotation (`canOpen`, in key terms). A co-parent from the
/// other home is in none but their own; a helper in none at all; and the
/// kitchen tablet, whoever it belongs to, is kept out by the caller.
bool belongsInPasswordGroup(
  String group, {
  required String memberId,
  required MemberRole role,
  bool coParent = false,
}) {
  if (group == memberPasswordsGroup(memberId)) return true;
  if (role == MemberRole.helper || coParent) return false;
  return switch (group) {
    familyPasswordsGroup => true,
    parentsPasswordsGroup => role == MemberRole.parent,
    childrenPasswordsGroup =>
      role == MemberRole.child || role == MemberRole.parent,
    _ => false,
  };
}

/// Every passwords group a member of [role] holds, beside their own.
List<String> sharedPasswordGroupsFor(MemberRole role) => [
  if (role != MemberRole.helper) familyPasswordsGroup,
  if (role == MemberRole.parent) parentsPasswordsGroup,
  if (role == MemberRole.parent || role == MemberRole.child)
    childrenPasswordsGroup,
];

/// A saved item in the password list (kind 28): a login, or a secure
/// note, a payment card, an ID or a Wi-Fi network (`VaultItemType`); who
/// it belongs to; and its secrets. Everything but the routing metadata is
/// encrypted, like every other object here.
///
/// Additive over the first version, which knew only logins: every item
/// keeps a title and its main secret (the password, the card number, the
/// note) in `secret`, and a login its username, address and note where
/// they always were, so an older app still shows every item. The rest of
/// a type's fields go in `fields`.
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
    VaultItemType type = VaultItemType.login,
    Map<String, String?> fields = const {},
    String? folder,
    bool? favourite,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    final was = existing == null ? null : CredentialPayload.read(existing);
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    // A changed secret: the old one kept, the last five, for the day a
    // site still wants it; and the date, for the security check.
    if (was == null) {
      p.setText('changed', at.toIso8601String());
    } else if (was.secret.isNotEmpty && was.secret != secret) {
      p
        ..setText('changed', at.toIso8601String())
        ..setNestedList('history', [
          Payload.map()
            ..setText('secret', was.secret)
            ..setText('until', at.toIso8601String()),
          ...?existing!.nestedList('history')?.take(4),
        ]);
    }
    p
      ..setText('type', type == VaultItemType.login ? null : type.name)
      ..setText(
        'folder',
        folder == null || folder.trim().isEmpty ? null : folder.trim(),
      );
    if (favourite != null) p.setBoolean('favourite', favourite ? true : null);
    // Written into what was there, so a field a later version added
    // survives this one.
    if (fields.isNotEmpty) {
      final kept = p.nested('fields') ?? Payload.map();
      for (final MapEntry(key: k, value: v) in fields.entries) {
        kept.setText(k, v == null || v.isEmpty ? null : v);
      }
      p.setNested('fields', kept);
    }
    p
      ..setText('title', title)
      ..setText('secret', secret)
      ..setText('username', username)
      ..setText('url', url)
      ..setText('note', note)
      ..setText('scope', switch (scope) {
        FamilyPassword() => 'family',
        MemberPassword() => 'member',
        ParentsPassword() => 'parents',
        ChildrenPassword() => 'children',
      })
      ..setText('member', switch (scope) {
        MemberPassword(:final memberId) => memberId,
        _ => null,
      });
    return CredentialPayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  String get secret => payload.text('secret') ?? '';
  String? get username => payload.text('username');
  String? get url => payload.text('url');
  String? get note => payload.text('note');

  /// What kind of item it is; a login unless it says otherwise, and a kind
  /// a later version added reads as a login, which shows its title and
  /// secret.
  VaultItemType get type =>
      VaultItemType.values.asNameMap()[payload.text('type')] ??
      VaultItemType.login;

  /// The value of the field [key] of its type: the main one from `secret`,
  /// a login's username and address and every type's note from where a
  /// login always kept them, the rest from `fields`.
  String? field(String key) {
    if (mainFieldOf(type).key == key) return secret;
    return switch (key) {
      'username' when type == VaultItemType.login => username,
      'url' when type == VaultItemType.login => url,
      'note' => note,
      _ => payload.nested('fields')?.text(key),
    };
  }

  String? get folder => payload.text('folder');
  bool get favourite => payload.boolean('favourite') ?? false;

  /// When its secret was last changed, if this app has seen it change or
  /// made it.
  DateTime? get changedAt => DateTime.tryParse(payload.text('changed') ?? '');

  /// Its earlier secrets, newest first, and until when each was used.
  List<({String secret, DateTime until})> get history => [
    for (final h in payload.nestedList('history') ?? const <Payload>[])
      if ((h.text('secret'), DateTime.tryParse(h.text('until') ?? '')) case (
        final secret?,
        final until?,
      ))
        (secret: secret, until: until),
  ];

  /// As the security check sees it.
  VaultEntry entry(String id) => VaultEntry(
    id: id,
    type: type,
    title: title,
    secret: secret,
    changedAt: changedAt,
  );

  PasswordFor get scope =>
      switch ((payload.text('scope'), payload.text('member'))) {
        ('member', final member?) => PasswordFor.member(member),
        ('parents', _) => const PasswordFor.parents(),
        ('children', _) => const PasswordFor.children(),
        _ => const PasswordFor.family(),
      };
}
