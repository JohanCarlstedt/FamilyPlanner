import 'dart:async';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';
import 'security_check_screen.dart';
import 'vault_sheets.dart';
import 'vault_words.dart';

/// The passwords this device can open: the family's, and this member's own.
final credentialsProvider = StreamProvider<List<(String, CredentialPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchCredentials();
});

/// Asks the phone to confirm it's the right person before a secret is
/// shown or copied. A phone with no lock set answers yes: it has nothing
/// to ask with, and refusing would only hide the passwords from the
/// person who saved them.
Future<bool> confirmItsYou(BuildContext context) async {
  final l10n = context.l10n;
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return true;
    return await auth.authenticate(
      localizedReason: l10n.passwordUnlockReason,
      persistAcrossBackgrounding: true,
    );
  } on PlatformException {
    return false;
  }
}

/// Saved passwords (the wifi, a streaming account, a member's own). Each
/// is sealed to the people it is for: a device that may not open one has
/// no key for it, and the kitchen tablet has none of them.
class PasswordsScreen extends ConsumerStatefulWidget {
  const PasswordsScreen({super.key});

  static const segment = 'passwords';

  @override
  ConsumerState<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends ConsumerState<PasswordsScreen> {
  final _search = TextEditingController();

  /// The filter chosen: null for all, a kind, `favourites`, or a folder.
  Object? _filter;

  @override
  void initState() {
    super.initState();
    // The keys a password is sealed to are made the first time the screen
    // is opened, not at pairing: most families never save one.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_keys()));
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _keys() async {
    try {
      final membership = await ref.read(membershipProvider.future);
      if (membership == null) return;
      await ref
          .read(pairingServiceProvider)
          .ensurePasswordGroups(
            membership: membership,
            device: await ref.read(deviceProvider.future),
            keyring: await ref.read(keyringProvider.future),
            members: await ref.read(membersProvider.future),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.passwordKeysFailed)),
        );
      }
    }
  }

  static const _favourites = 'favourites';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saved =
        [
          ...ref.watch(credentialsProvider).value ??
              const <(String, CredentialPayload)>[],
        ]..sort(
          (a, b) =>
              a.$2.title.toLowerCase().compareTo(b.$2.title.toLowerCase()),
        );
    final me = ref.watch(membershipProvider).value?.memberId;
    final used = ref.watch(vaultUsedProvider).value ?? const {};
    final folders = {for (final (_, c) in saved) ?c.folder}.toList()..sort();
    final types = {for (final (_, c) in saved) c.type};
    final check = securityCheck([
      for (final (id, c) in saved) c.entry(id),
    ], now: DateTime.now().toUtc());

    final query = _search.text;
    final shown = [
      for (final (id, c) in saved)
        if (vaultMatches(c, query) &&
            switch (_filter) {
              null => true,
              _favourites => c.favourite,
              final VaultItemType t => c.type == t,
              final String folder => c.folder == folder,
              _ => true,
            })
          (id, c),
    ];
    final browsing = query.trim().isEmpty && _filter == null;
    final favourites = [
      for (final e in shown)
        if (e.$2.favourite) e,
    ];
    final recent = (([
      for (final e in shown)
        if (used.containsKey(e.$1)) e,
    ])..sort((a, b) => used[b.$1]!.compareTo(used[a.$1]!))).take(5).toList();
    final mine = [
      for (final (id, c) in shown)
        if (c.scope case MemberPassword(:final memberId) when memberId == me)
          (id, c),
    ];
    final family = [
      for (final (id, c) in shown)
        if (c.scope is FamilyPassword) (id, c),
    ];
    final parents = [
      for (final (id, c) in shown)
        if (c.scope is ParentsPassword) (id, c),
    ];
    final children = [
      for (final (id, c) in shown)
        if (c.scope is ChildrenPassword) (id, c),
    ];

    Widget section(String title, List<(String, CredentialPayload)> entries) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            for (final (id, c) in entries)
              _Entry(
                credential: c,
                warned: check.issues.containsKey(id),
                onOpen: () => showVaultItem(
                  context,
                  id: id,
                  onEdit: () => _edit(id, c, folders),
                ),
                onCopy: () => copySecret(context, ref, id, c.secret),
              ),
          ],
        );

    Widget chip(String label, Object? value, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwords),
        actions: [
          if (saved.isNotEmpty)
            IconButton(
              tooltip: l10n.vaultCheck,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SecurityCheckScreen(),
                ),
              ),
              icon: Badge(
                isLabelVisible: check.issues.isNotEmpty,
                label: Text('${check.issues.length}'),
                child: const Icon(Icons.shield_outlined),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null, null, folders),
        icon: const Icon(Icons.add),
        label: Text(l10n.passwordAdd),
      ),
      body: saved.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.passwordsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SearchBar(
                    controller: _search,
                    hintText: l10n.vaultSearch,
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _search.clear,
                        ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      chip(l10n.vaultAll, null),
                      if (saved.any((e) => e.$2.favourite))
                        chip(
                          l10n.vaultFavourites,
                          _favourites,
                          icon: Icons.star,
                        ),
                      if (types.length > 1)
                        for (final t in VaultItemType.values)
                          if (types.contains(t))
                            chip(
                              vaultTypeName(l10n, t),
                              t,
                              icon: vaultTypeIcon(t),
                            ),
                      for (final f in folders)
                        chip(f, f, icon: Icons.folder_outlined),
                    ],
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.vaultNoResults),
                  ),
                if (browsing && favourites.isNotEmpty)
                  section(l10n.vaultFavourites, favourites),
                if (browsing && recent.isNotEmpty)
                  section(l10n.vaultRecent, recent),
                if (family.isNotEmpty) section(l10n.passwordsFamily, family),
                if (parents.isNotEmpty) section(l10n.passwordsParents, parents),
                if (children.isNotEmpty)
                  section(l10n.passwordsChildren, children),
                if (mine.isNotEmpty) section(l10n.passwordsMine, mine),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.passwordsHelp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _edit(
    String? id,
    CredentialPayload? existing,
    List<String> folders,
  ) async {
    final me = ref.read(membershipProvider).value?.memberId;
    if (me == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => VaultEditSheet(
        id: id,
        existing: existing,
        memberId: me,
        folders: folders,
        isParent: ref.read(membershipProvider).value?.isParent ?? false,
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.credential,
    required this.warned,
    required this.onOpen,
    required this.onCopy,
  });

  final CredentialPayload credential;

  /// The security check found something wrong with it.
  final bool warned;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      leading: VaultAvatar(item: credential),
      title: Row(
        children: [
          Flexible(
            child: Text(credential.title, overflow: TextOverflow.ellipsis),
          ),
          if (credential.favourite)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.star, size: 16, color: Color(0xFFE0A100)),
            ),
          if (warned)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      subtitle: Text(
        [vaultSummary(l10n, credential), ?credential.folder].join(' · '),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onOpen,
      trailing: IconButton(
        tooltip: l10n.passwordCopy,
        icon: const Icon(Icons.copy),
        onPressed: onCopy,
      ),
    );
  }
}
