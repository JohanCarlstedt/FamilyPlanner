import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/server_address.dart';
import '../../common/l10n.dart';

/// Welcome > Use your own server.
///
/// Only reachable before this install has paired, which is the only time
/// it would be honest to offer: afterwards the device's identity lives on
/// the pinned server and moving it would strand the phone.
///
/// The address is checked before it is accepted. A typo that survived to
/// family creation would fail there instead, further from the person who
/// could fix it and with more to undo.
class ServerDialog extends ConsumerStatefulWidget {
  const ServerDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
    context: context,
    builder: (_) => const ServerDialog(),
  );

  @override
  ConsumerState<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends ConsumerState<ServerDialog> {
  late final TextEditingController _address = TextEditingController(
    text: ref.read(serverProvider.notifier).isCustom
        ? ref.read(serverProvider).host
        : '',
  );
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _use() async {
    final l10n = context.l10n;
    final candidate = normaliseServerAddress(_address.text);
    if (candidate == null) {
      setState(() => _error = l10n.serverBadAddress);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });

    final probe = FamilyApi(candidate);
    final answered = await probe.reachable();
    probe.close();
    if (!mounted) return;

    if (!answered) {
      setState(() {
        _checking = false;
        _error = l10n.serverNoAnswer(candidate.host);
      });
      return;
    }
    await ref.read(serverProvider.notifier).choose(candidate);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _standard() async {
    await ref.read(serverProvider.notifier).choose(defaultServer);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.serverTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.serverHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _address,
            autofocus: true,
            enabled: !_checking,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onSubmitted: (_) => _use(),
            decoration: InputDecoration(
              labelText: l10n.serverAddress,
              hintText: l10n.serverAddressHint,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          if (ref.watch(serverProvider.notifier).isCustom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _checking ? null : _standard,
                child: Text(l10n.serverStandard),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _checking ? null : _use,
          child: _checking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.serverCheck),
        ),
      ],
    );
  }
}
