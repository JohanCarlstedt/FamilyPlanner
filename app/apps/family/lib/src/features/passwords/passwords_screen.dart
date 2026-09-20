import 'dart:async';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';

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
  /// Which entries are showing their secret, until this screen is left.
  final _shown = <String>{};
  Timer? _clearClipboard;

  @override
  void initState() {
    super.initState();
    // The keys a password is sealed to are made the first time the screen
    // is opened, not at pairing: most families never save one.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_keys()));
  }

  @override
  void dispose() {
    _clearClipboard?.cancel();
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

  Future<void> _reveal(String id) async {
    if (!await confirmItsYou(context)) return;
    if (mounted) setState(() => _shown.add(id));
  }

  Future<void> _copy(String secret) async {
    final l10n = context.l10n;
    if (!await confirmItsYou(context)) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.passwordCopied)));
    // The clipboard is read by anything that asks: it doesn't keep it.
    _clearClipboard?.cancel();
    _clearClipboard = Timer(const Duration(seconds: 45), () async {
      final held = await Clipboard.getData(Clipboard.kTextPlain);
      if (held?.text == secret) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saved = ref.watch(credentialsProvider).value ?? const [];
    final me = ref.watch(membershipProvider).value?.memberId;
    final mine = [
      for (final (id, c) in saved)
        if (c.scope case MemberPassword(:final memberId) when memberId == me)
          (id, c),
    ];
    final family = [
      for (final (id, c) in saved)
        if (c.scope is FamilyPassword) (id, c),
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
                shown: _shown.contains(id),
                onReveal: () => _reveal(id),
                onHide: () => setState(() => _shown.remove(id)),
                onCopy: () => _copy(c.secret),
                onEdit: () => _edit(id, c),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.passwords)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null, null),
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
                if (family.isNotEmpty) section(l10n.passwordsFamily, family),
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

  Future<void> _edit(String? id, CredentialPayload? existing) async {
    final me = ref.read(membershipProvider).value?.memberId;
    if (me == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _PasswordSheet(id: id, existing: existing, memberId: me),
    );
    if ((saved ?? false) && mounted) setState(() => _shown.clear());
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.credential,
    required this.shown,
    required this.onReveal,
    required this.onHide,
    required this.onCopy,
    required this.onEdit,
  });

  final CredentialPayload credential;
  final bool shown;
  final VoidCallback onReveal;
  final VoidCallback onHide;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      title: Text(credential.title),
      subtitle: Text(
        shown
            ? credential.secret
            : [
                ?credential.username,
                if (credential.username == null) l10n.passwordHidden,
              ].join(),
        style: shown
            ? theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace')
            : null,
      ),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (credential.url case final url? when url.isNotEmpty)
            IconButton(
              tooltip: l10n.openLink,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(
                Uri.parse(url.startsWith('http') ? url : 'https://$url'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          IconButton(
            tooltip: shown ? l10n.passwordHide : l10n.passwordShow,
            icon: Icon(shown ? Icons.visibility_off : Icons.visibility),
            onPressed: shown ? onHide : onReveal,
          ),
          IconButton(
            tooltip: l10n.passwordCopy,
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// Adds or changes one. The scope decides which key it is sealed to, so
/// it is asked for plainly rather than hidden in a menu.
class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet({
    required this.id,
    required this.existing,
    required this.memberId,
  });

  final String? id;
  final CredentialPayload? existing;
  final String memberId;

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _username = TextEditingController(text: widget.existing?.username);
  late final _secret = TextEditingController(text: widget.existing?.secret);
  late final _url = TextEditingController(text: widget.existing?.url);
  late final _note = TextEditingController(text: widget.existing?.note);
  late var _family = widget.existing?.scope is FamilyPassword;
  var _saving = false;
  var _hidden = true;

  @override
  void dispose() {
    for (final c in [_title, _username, _secret, _url, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_title.text.trim().isEmpty || _secret.text.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordNeedsBoth)));
      return;
    }
    setState(() => _saving = true);
    try {
      final store = await ref.read(familyStoreProvider.future);
      await store.saveCredential(
        CredentialPayload.write(
          existing: widget.existing?.payload,
          title: _title.text.trim(),
          secret: _secret.text,
          username: _username.text.trim().isEmpty
              ? null
              : _username.text.trim(),
          url: _url.text.trim().isEmpty ? null : _url.text.trim(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          scope: _family
              ? const PasswordFor.family()
              : PasswordFor.member(widget.memberId),
        ),
        id: widget.id,
      );
      ref.read(syncControllerProvider.notifier).syncNow();
      navigator.pop(true);
    } on MissingPasswordKey {
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordKeysFailed)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final id = widget.id;
    if (id == null) return;
    final navigator = Navigator.of(context);
    final store = await ref.read(familyStoreProvider.future);
    await store.delete(ObjectKind.credential, id);
    ref.read(syncControllerProvider.notifier).syncNow();
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: widget.id == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.passwordTitle),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _username,
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.passwordUsername),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _secret,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _hidden,
                decoration: InputDecoration(
                  labelText: l10n.passwordSecret,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.passwordGenerate,
                        icon: const Icon(Icons.casino_outlined),
                        onPressed: () => setState(() {
                          _secret.text = generatePassword();
                          _hidden = false;
                        }),
                      ),
                      IconButton(
                        tooltip: _hidden
                            ? l10n.passwordShow
                            : l10n.passwordHide,
                        icon: Icon(
                          _hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l10n.passwordUrl),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.passwordNote),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(l10n.passwordsFamily),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.person_outline),
                    label: Text(l10n.passwordsMine),
                  ),
                ],
                selected: {_family},
                onSelectionChanged: (s) => setState(() => _family = s.single),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _family ? l10n.passwordScopeFamily : l10n.passwordScopeMine,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.id != null)
                    TextButton(
                      onPressed: _saving ? null : _remove,
                      child: Text(l10n.delete),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
