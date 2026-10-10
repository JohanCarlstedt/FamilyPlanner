import 'dart:async';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import 'passwords_screen.dart' show confirmItsYou, credentialsProvider;
import 'vault_words.dart';

Timer? _clearClipboard;

/// Copies [secret] after the phone has confirmed who is holding it, and
/// clears the clipboard again shortly: the clipboard is read by anything
/// that asks, and keeps nothing safe.
Future<void> copySecret(
  BuildContext context,
  WidgetRef ref,
  String id,
  String secret, {
  bool confirmed = false,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!confirmed && !await confirmItsYou(context)) return;
  await Clipboard.setData(ClipboardData(text: secret));
  unawaited(markVaultUsed(ref, id));
  messenger.showSnackBar(SnackBar(content: Text(l10n.passwordCopied)));
  _clearClipboard?.cancel();
  _clearClipboard = Timer(const Duration(seconds: 45), () async {
    final held = await Clipboard.getData(Clipboard.kTextPlain);
    if (held?.text == secret) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  });
}

/// The generator, LastPass's way: how long, which kinds of character, a
/// new one at a tap. Returns the password chosen, or null.
Future<String?> showGenerator(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _Generator(),
    );

class _Generator extends StatefulWidget {
  const _Generator();

  @override
  State<_Generator> createState() => _GeneratorState();
}

class _GeneratorState extends State<_Generator> {
  var _length = 20;
  var _capitals = true;
  var _digits = true;
  var _symbols = true;
  late var _made = _make();

  String _make() => generateWith(
    length: _length,
    capitals: _capitals,
    digits: _digits,
    symbols: _symbols,
  );

  void _again() => setState(() => _made = _make());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final strength = strengthOf(_made);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.vaultGenerator, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SelectableText(
              _made,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Text(
              strengthName(l10n, strength),
              style: TextStyle(color: strengthColor(strength)),
            ),
            const SizedBox(height: 8),
            Text(l10n.vaultLength(_length)),
            Slider(
              value: _length.toDouble(),
              min: 8,
              max: 40,
              divisions: 32,
              label: '$_length',
              onChanged: (v) => setState(() {
                _length = v.round();
                _made = _make();
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vaultCapitals),
              value: _capitals,
              onChanged: (v) => setState(() {
                _capitals = v;
                _made = _make();
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vaultDigits),
              value: _digits,
              onChanged: (v) => setState(() {
                _digits = v;
                _made = _make();
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vaultSymbols),
              value: _symbols,
              onChanged: (v) => setState(() {
                _symbols = v;
                _made = _make();
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _again,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.vaultAnother),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _made),
                  child: Text(l10n.vaultUse),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One item, opened: each field with its own copy button, secrets hidden
/// until the phone has confirmed who is holding it (once for the sheet),
/// the earlier passwords, and for a Wi-Fi network the code another phone
/// joins with.
Future<void> showVaultItem(
  BuildContext context, {
  required String id,
  required void Function() onEdit,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ItemSheet(id: id, onEdit: onEdit),
);

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.id, required this.onEdit});

  final String id;
  final void Function() onEdit;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  /// The phone has confirmed who is holding it, for as long as the sheet
  /// is open.
  var _open = false;

  Future<bool> _unlock() async {
    if (_open) return true;
    final ok = await confirmItsYou(context);
    if (ok && mounted) {
      setState(() => _open = true);
      unawaited(markVaultUsed(ref, widget.id));
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final item =
        (ref.watch(credentialsProvider).value ??
                const <(String, CredentialPayload)>[])
            .where((e) => e.$1 == widget.id)
            .firstOrNull
            ?.$2;
    if (item == null) return const SizedBox(height: 120);
    final dates = DateFormat('d MMM y');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                VaultAvatar(item: item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: theme.textTheme.titleLarge),
                      Text(
                        [
                          vaultTypeName(l10n, item.type),
                          ?item.folder,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (item.favourite)
                  const Icon(Icons.star, color: Color(0xFFE0A100)),
              ],
            ),
            const SizedBox(height: 8),
            for (final f in vaultFields[item.type]!)
              if (item.field(f.key) case final value? when value.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    vaultFieldName(l10n, f.key),
                    style: theme.textTheme.labelMedium,
                  ),
                  subtitle: Text(
                    f.secret && !_open ? '••••••••' : value,
                    style: f.secret && _open
                        ? theme.textTheme.bodyLarge?.copyWith(
                            fontFamily: 'monospace',
                          )
                        : theme.textTheme.bodyLarge,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (f.key == 'url')
                        IconButton(
                          tooltip: l10n.openLink,
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => launchUrl(
                            Uri.parse(
                              value.startsWith('http')
                                  ? value
                                  : 'https://$value',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      if (f.secret && !_open)
                        IconButton(
                          tooltip: l10n.passwordShow,
                          icon: const Icon(Icons.visibility),
                          onPressed: _unlock,
                        ),
                      IconButton(
                        tooltip: l10n.passwordCopy,
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          if (f.secret && !await _unlock()) return;
                          if (!context.mounted) return;
                          await copySecret(
                            context,
                            ref,
                            widget.id,
                            value,
                            confirmed: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
            if (item.type == VaultItemType.wifi &&
                (item.field('ssid') ?? '').isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.vaultJoinWifi),
                onPressed: () async {
                  if (!await _unlock() || !context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(item.field('ssid')!),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 220,
                            child: QrImageView(
                              data: wifiJoinCode(
                                ssid: item.field('ssid')!,
                                password: item.secret,
                                security: item.field('security'),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.vaultJoinWifiHelp),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (item.history.isNotEmpty) ...[
              const Divider(height: 32),
              Text(l10n.vaultHistory, style: theme.textTheme.titleSmall),
              for (final h in item.history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    _open ? h.secret : '••••••••',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  subtitle: Text(
                    l10n.vaultUsedUntil(dates.format(h.until.toLocal())),
                  ),
                  trailing: _open
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: _unlock,
                        ),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                widget.onEdit();
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.vaultEdit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds or changes one item. The kind is chosen for a new one; the
/// fields follow it. The scope decides which key it is sealed to, so it
/// is asked for plainly rather than hidden in a menu.
class VaultEditSheet extends ConsumerStatefulWidget {
  const VaultEditSheet({
    super.key,
    required this.id,
    required this.existing,
    required this.memberId,
    required this.folders,
  });

  final String? id;
  final CredentialPayload? existing;
  final String memberId;

  /// The folders already in use, offered as the folder is typed.
  final List<String> folders;

  @override
  ConsumerState<VaultEditSheet> createState() => _VaultEditSheetState();
}

class _VaultEditSheetState extends ConsumerState<VaultEditSheet> {
  late var _type = widget.existing?.type ?? VaultItemType.login;
  late final _title = TextEditingController(text: widget.existing?.title);

  /// The folder's field, once the autocomplete has made it.
  TextEditingController? _folderInput;
  late var _favourite = widget.existing?.favourite ?? false;
  late var _family = widget.existing?.scope is FamilyPassword;
  final _fields = <String, TextEditingController>{};
  final _hidden = <String>{};
  var _saving = false;

  TextEditingController _controller(String key) => _fields.putIfAbsent(
    key,
    () =>
        TextEditingController(text: widget.existing?.field(key))
          ..addListener(() => setState(() {})),
  );

  @override
  void initState() {
    super.initState();
    for (final type in VaultItemType.values) {
      for (final f in vaultFields[type]!) {
        if (f.secret) _hidden.add(f.key);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_title, ..._fields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _value(String key) {
    final v = _fields[key]?.text.trim();
    return v == null || v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final main = mainFieldOf(_type);
    // A password is kept as typed, spaces and all; the rest are trimmed.
    final secret = main.key == 'password'
        ? (_fields[main.key]?.text ?? '')
        : (_value(main.key) ?? '');
    if (_title.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.vaultNeedsTitle)));
      return;
    }
    if (secret.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.vaultNeedsMain(vaultFieldName(l10n, main.key).toLowerCase()),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final store = await ref.read(familyStoreProvider.future);
      final login = _type == VaultItemType.login;
      await store.saveCredential(
        CredentialPayload.write(
          existing: widget.existing?.payload,
          title: _title.text.trim(),
          secret: secret,
          username: login ? _value('username') : null,
          url: login ? _value('url') : null,
          // Only the note field: a secure note's text is its secret, and
          // `note` is shown openly by an app that knows only logins.
          note: _value('note'),
          type: _type,
          fields: {
            for (final f in vaultFields[_type]!)
              if (!f.main &&
                  !(login && (f.key == 'username' || f.key == 'url')))
                if (f.key != 'note') f.key: _value(f.key),
          },
          folder: _folderInput?.text ?? widget.existing?.folder,
          favourite: _favourite,
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

  Widget _fieldInput(VaultField f) {
    final l10n = context.l10n;
    final controller = _controller(f.key);
    final hidden = f.secret && _hidden.contains(f.key);
    final password = f.key == 'password';
    final strength = password && controller.text.isNotEmpty
        ? strengthOf(controller.text)
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: !f.secret,
            obscureText: hidden && !f.multiline,
            minLines: f.multiline ? 2 : 1,
            maxLines: f.multiline ? 6 : 1,
            keyboardType: f.digits
                ? TextInputType.number
                : f.key == 'url'
                ? TextInputType.url
                : null,
            decoration: InputDecoration(
              labelText: vaultFieldName(l10n, f.key),
              suffixIcon: f.secret && !f.multiline
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (password)
                          IconButton(
                            tooltip: l10n.vaultGenerator,
                            icon: const Icon(Icons.casino_outlined),
                            onPressed: () async {
                              final made = await showGenerator(context);
                              if (made == null) return;
                              setState(() {
                                controller.text = made;
                                _hidden.remove(f.key);
                              });
                            },
                          ),
                        IconButton(
                          tooltip: hidden
                              ? l10n.passwordShow
                              : l10n.passwordHide,
                          icon: Icon(
                            hidden ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => hidden
                                ? _hidden.remove(f.key)
                                : _hidden.add(f.key),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          if (strength != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      color: i <= strength.index
                          ? strengthColor(strength)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    strengthName(l10n, strength),
                    style: TextStyle(
                      color: strengthColor(strength),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
              if (widget.existing == null) ...[
                Text(
                  l10n.vaultKind,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final type in VaultItemType.values)
                      ChoiceChip(
                        avatar: Icon(vaultTypeIcon(type), size: 18),
                        label: Text(vaultTypeName(l10n, type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _title,
                autofocus: widget.id == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.passwordTitle),
              ),
              for (final f in vaultFields[_type]!) _fieldInput(f),
              const SizedBox(height: 8),
              Autocomplete<String>(
                initialValue: TextEditingValue(
                  text: widget.existing?.folder ?? '',
                ),
                optionsBuilder: (value) => [
                  for (final f in widget.folders)
                    if (f.toLowerCase().contains(value.text.toLowerCase())) f,
                ],
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  _folderInput = controller;
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l10n.vaultFolder),
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.star_outline),
                title: Text(l10n.vaultFavourite),
                value: _favourite,
                onChanged: (v) => setState(() => _favourite = v),
              ),
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
