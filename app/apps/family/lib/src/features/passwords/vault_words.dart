import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';

String vaultTypeName(AppLocalizations l10n, VaultItemType type) =>
    switch (type) {
      VaultItemType.login => l10n.vaultTypeLogin,
      VaultItemType.note => l10n.vaultTypeNote,
      VaultItemType.card => l10n.vaultTypeCard,
      VaultItemType.identity => l10n.vaultTypeIdentity,
      VaultItemType.wifi => l10n.vaultTypeWifi,
    };

IconData vaultTypeIcon(VaultItemType type) => switch (type) {
  VaultItemType.login => Icons.key_outlined,
  VaultItemType.note => Icons.sticky_note_2_outlined,
  VaultItemType.card => Icons.credit_card,
  VaultItemType.identity => Icons.badge_outlined,
  VaultItemType.wifi => Icons.wifi,
};

String vaultFieldName(AppLocalizations l10n, String key) => switch (key) {
  'username' => l10n.vaultFieldUsername,
  'password' => l10n.vaultFieldPassword,
  'url' => l10n.vaultFieldUrl,
  'note' => l10n.vaultFieldNote,
  'text' => l10n.vaultFieldText,
  'holder' => l10n.vaultFieldHolder,
  'number' => l10n.vaultFieldNumber,
  'expiry' => l10n.vaultFieldExpiry,
  'cvc' => l10n.vaultFieldCvc,
  'pin' => l10n.vaultFieldPin,
  'name' => l10n.vaultFieldName,
  'idNumber' => l10n.vaultFieldIdNumber,
  'personalNumber' => l10n.vaultFieldPersonalNumber,
  'ssid' => l10n.vaultFieldSsid,
  'security' => l10n.vaultFieldSecurity,
  _ => key,
};

String strengthName(AppLocalizations l10n, PasswordStrength s) => switch (s) {
  PasswordStrength.weak => l10n.vaultStrengthWeak,
  PasswordStrength.fair => l10n.vaultStrengthFair,
  PasswordStrength.strong => l10n.vaultStrengthStrong,
};

Color strengthColor(PasswordStrength s) => switch (s) {
  PasswordStrength.weak => const Color(0xFFD64545),
  PasswordStrength.fair => const Color(0xFFE0A100),
  PasswordStrength.strong => const Color(0xFF2E9D57),
};

/// The line under an item's title in the list: never a secret, only what
/// tells two items apart.
String vaultSummary(AppLocalizations l10n, CredentialPayload c) =>
    switch (c.type) {
      VaultItemType.login => c.username ?? c.url ?? l10n.passwordHidden,
      VaultItemType.card => switch (c.secret.replaceAll(RegExp(r'\D'), '')) {
        final digits when digits.length >= 4 => l10n.vaultCardEnding(
          digits.substring(digits.length - 4),
        ),
        _ => l10n.vaultTypeCard,
      },
      VaultItemType.identity => c.field('name') ?? l10n.vaultTypeIdentity,
      VaultItemType.wifi => c.field('ssid') ?? l10n.vaultTypeWifi,
      VaultItemType.note => l10n.vaultTypeNote,
    };

/// What a search matches: the title and the things that are not secret.
bool vaultMatches(CredentialPayload c, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [
    c.title,
    c.folder,
    if (c.type == VaultItemType.login) ...[c.username, c.url],
    for (final f in vaultFields[c.type]!)
      if (!f.secret && f.key != 'note') c.field(f.key),
  ].whereType<String>().any((s) => s.toLowerCase().contains(q));
}

/// When this phone last used each item (copied or showed a secret), by
/// id: for "Recently used". Kept on the phone, never synced: what someone
/// looks up and when is nobody else's business.
final vaultUsedProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  final prefs = await ref.watch(devicePreferencesProvider.future);
  final raw = await prefs.read(_usedPreference);
  if (raw == null) return const {};
  try {
    return {
      for (final MapEntry(key: id, value: at)
          in (jsonDecode(raw) as Map<String, dynamic>).entries)
        id: ?DateTime.tryParse(at as String),
    };
  } on Object {
    return const {};
  }
});

const _usedPreference = 'vault.used';

Future<void> markVaultUsed(WidgetRef ref, String id) async {
  final prefs = await ref.read(devicePreferencesProvider.future);
  final used = {...await ref.read(vaultUsedProvider.future)};
  used[id] = DateTime.now().toUtc();
  // The thirty most recent are plenty for a list of five.
  final kept =
      (used.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(
        30,
      );
  await prefs.write(
    _usedPreference,
    jsonEncode({for (final e in kept) e.key: e.value.toIso8601String()}),
  );
  ref.invalidate(vaultUsedProvider);
}

/// A round mark for an item: its kind's symbol, on a colour taken from
/// its address or name, so the same site always looks the same. Drawn
/// here rather than fetched, so no site learns what the family keeps.
class VaultAvatar extends StatelessWidget {
  const VaultAvatar({super.key, required this.item});

  final CredentialPayload item;

  @override
  Widget build(BuildContext context) {
    final key = (item.url ?? item.title).toLowerCase();
    final hue = (key.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0xffff) % 360)
        .toDouble();
    final background = HSLColor.fromAHSL(1, hue, 0.45, 0.42).toColor();
    final letter = item.title.trim().isEmpty
        ? '?'
        : item.title.trim().characters.first.toUpperCase();
    return CircleAvatar(
      backgroundColor: background,
      foregroundColor: Colors.white,
      child: item.type == VaultItemType.login
          ? Text(letter, style: const TextStyle(fontWeight: FontWeight.w600))
          : Icon(vaultTypeIcon(item.type), size: 20),
    );
  }
}
