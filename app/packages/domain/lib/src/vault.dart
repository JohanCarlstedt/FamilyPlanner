import 'dart:math';

/// What a saved item in the password list is: a login, as before, or one
/// of the other things a family keeps safe (LastPass's item types, as far
/// as a family needs them).
enum VaultItemType { login, note, card, identity, wifi }

/// One field an item type has, beside its title.
class VaultField {
  const VaultField(
    this.key, {
    this.secret = false,
    this.main = false,
    this.multiline = false,
    this.digits = false,
  });

  /// Its name in the stored item, and the string key for its label.
  final String key;

  /// Hidden until the phone has confirmed who is holding it, and copied
  /// to a clipboard that clears itself.
  final bool secret;

  /// The one stored as the item's `secret`, where a version that knows
  /// only logins finds it: the password, the card number, the note.
  final bool main;

  final bool multiline;
  final bool digits;
}

/// The fields of each type, in the order they are shown. Each type has
/// exactly one main field.
const vaultFields = <VaultItemType, List<VaultField>>{
  VaultItemType.login: [
    VaultField('username'),
    VaultField('password', secret: true, main: true),
    VaultField('url'),
    VaultField('note', multiline: true),
  ],
  VaultItemType.note: [
    VaultField('text', secret: true, main: true, multiline: true),
  ],
  VaultItemType.card: [
    VaultField('holder'),
    VaultField('number', secret: true, main: true, digits: true),
    VaultField('expiry'),
    VaultField('cvc', secret: true, digits: true),
    VaultField('pin', secret: true, digits: true),
    VaultField('note', multiline: true),
  ],
  VaultItemType.identity: [
    VaultField('name'),
    VaultField('idNumber', secret: true, main: true),
    VaultField('personalNumber', secret: true),
    VaultField('expiry'),
    VaultField('note', multiline: true),
  ],
  VaultItemType.wifi: [
    VaultField('ssid'),
    VaultField('password', secret: true, main: true),
    VaultField('security'),
    VaultField('note', multiline: true),
  ],
};

/// The main field of [type]: what is stored as its `secret`.
VaultField mainFieldOf(VaultItemType type) =>
    vaultFields[type]!.firstWhere((f) => f.main);

/// How hard a password is to guess, roughly.
enum PasswordStrength { weak, fair, strong }

/// Passwords people use most, which any guesser tries first.
const _common = {
  '123456',
  '1234567',
  '12345678',
  '123456789',
  '1234567890',
  'password',
  'lösenord',
  'losenord',
  'qwerty',
  'qwertyuiop',
  'abc123',
  '111111',
  '000000',
  'iloveyou',
  'admin',
  'welcome',
  'sommar',
  'vinter',
  'hejsan',
  'hemligt',
  'password1',
  'qwerty123',
  'monkey',
  'dragon',
  'football',
  'letmein',
  'sunshine',
  'princess',
  'starwars',
  'passw0rd',
};

/// [password]'s strength: length and variety, with a common password, a
/// run like "abcd" or "1234", or one character over and over counted as
/// what they are. A guide for a person, not a cracking estimate.
PasswordStrength strengthOf(String password) {
  if (password.isEmpty) return PasswordStrength.weak;
  final lower = password.toLowerCase();
  if (_common.contains(lower) || password.length < 8) {
    return PasswordStrength.weak;
  }
  if (password.split('').toSet().length <= 2) return PasswordStrength.weak;
  var kinds = 0;
  if (RegExp('[a-zåäö]').hasMatch(password)) kinds++;
  if (RegExp('[A-ZÅÄÖ]').hasMatch(password)) kinds++;
  if (RegExp('[0-9]').hasMatch(password)) kinds++;
  if (RegExp('[^a-zA-Z0-9åäöÅÄÖ]').hasMatch(password)) kinds++;
  // A run of four or more in order, up or down, counts for little.
  var run = 1, longest = 1;
  for (var i = 1; i < password.length; i++) {
    final step = password.codeUnitAt(i) - password.codeUnitAt(i - 1);
    run = step.abs() == 1 ? run + 1 : 1;
    longest = max(longest, run);
  }
  var score = password.length + kinds * 3 - (longest >= 4 ? longest : 0);
  // A long passphrase of plain words is strong on length alone.
  if (password.length >= 20) score += 6;
  if (score >= 24) return PasswordStrength.strong;
  if (score >= 16) return PasswordStrength.fair;
  return PasswordStrength.weak;
}

/// One item as the security check sees it.
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.secret,
    this.changedAt,
  });

  final String id;
  final VaultItemType type;
  final String title;
  final String secret;

  /// When its secret was last changed; null when not known.
  final DateTime? changedAt;

  /// Whether it is a password at all: a card number or a note is not
  /// something a person picks, reuses or should be told to change.
  bool get isPassword =>
      type == VaultItemType.login || type == VaultItemType.wifi;
}

/// What the check found wrong with one item.
enum VaultIssue { weak, reused, old }

/// A password unchanged for this long is worth changing.
const passwordGetsOld = Duration(days: 365);

/// The security check: each password's problems, and a score out of 100
/// for the whole list (LastPass's security dashboard, as a family needs
/// it). Only passwords are judged, and only problems are listed.
class SecurityCheck {
  const SecurityCheck({required this.issues, required this.score});

  /// The items with something wrong, by id.
  final Map<String, Set<VaultIssue>> issues;

  /// 100 with nothing wrong; each problem takes its share off.
  final int score;

  List<String> withIssue(VaultIssue issue) => [
        for (final MapEntry(key: id, value: found) in issues.entries)
          if (found.contains(issue)) id,
      ];
}

SecurityCheck securityCheck(List<VaultEntry> entries, {required DateTime now}) {
  final passwords = [
    for (final e in entries)
      if (e.isPassword && e.secret.isNotEmpty) e,
  ];
  final bySecret = <String, int>{};
  for (final e in passwords) {
    bySecret[e.secret] = (bySecret[e.secret] ?? 0) + 1;
  }
  final issues = <String, Set<VaultIssue>>{};
  for (final e in passwords) {
    final found = {
      if (strengthOf(e.secret) == PasswordStrength.weak) VaultIssue.weak,
      if (bySecret[e.secret]! > 1) VaultIssue.reused,
      if (e.changedAt case final at? when now.difference(at) > passwordGetsOld)
        VaultIssue.old,
    };
    if (found.isNotEmpty) issues[e.id] = found;
  }
  if (passwords.isEmpty) return SecurityCheck(issues: issues, score: 100);
  // Weak and reused weigh twice what old does.
  var lost = 0.0;
  for (final found in issues.values) {
    lost += (found.contains(VaultIssue.weak) ? 2 : 0) +
        (found.contains(VaultIssue.reused) ? 2 : 0) +
        (found.contains(VaultIssue.old) ? 1 : 0);
  }
  final score = (100 - lost / (passwords.length * 5) * 100).round();
  return SecurityCheck(issues: issues, score: score.clamp(0, 100));
}

/// Letters that survive being read aloud or copied off a screen: no l, I,
/// 1, O or 0, which are the ones people get wrong.
const _plain = 'abcdefghijkmnopqrstuvwxyz';
const _capitals = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _figures = '23456789';
const _marks = '-_!?@#%+=';

/// A password made to [length] from the kinds asked for, at least one of
/// each, from the platform's secure random unless a [random] is given for
/// a test. Lower-case letters always: a password of only digits is a PIN.
String generateWith({
  int length = 20,
  bool capitals = true,
  bool digits = true,
  bool symbols = true,
  Random? random,
}) {
  if (length < 8) {
    throw ArgumentError.value(length, 'length', 'too short to be worth saving');
  }
  final source = random ?? Random.secure();
  final alphabets = [
    _plain,
    if (capitals) _capitals,
    if (digits) _figures,
    if (symbols) _marks,
  ];
  final characters = [
    for (final alphabet in alphabets) alphabet[source.nextInt(alphabet.length)],
  ];
  final all = alphabets.join();
  while (characters.length < length) {
    characters.add(all[source.nextInt(all.length)]);
  }
  characters.shuffle(source);
  return characters.join();
}

/// What a phone's camera reads to join a Wi-Fi network: the standard
/// `WIFI:` string, with the characters it reserves escaped.
String wifiJoinCode({
  required String ssid,
  required String password,
  String? security,
}) {
  String escape(String s) => s.replaceAllMapped(
        RegExp(r'([\\;,":])'),
        (m) => '\\${m[1]}',
      );
  final kind = switch (security?.toUpperCase() ?? '') {
    '' when password.isEmpty => 'nopass',
    '' => 'WPA',
    final s when s.contains('WEP') => 'WEP',
    final s when s.contains('NONE') || s.contains('OPEN') => 'nopass',
    _ => 'WPA',
  };
  return 'WIFI:T:$kind;S:${escape(ssid)};'
      '${kind == 'nopass' ? '' : 'P:${escape(password)};'};';
}
