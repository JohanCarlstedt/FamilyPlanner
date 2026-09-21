import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../integrations/ica/ica_api.dart';
import '../../integrations/ica/ica_auth.dart';
import '../../integrations/ica/ica_lists.dart';
import '../../integrations/ica/ica_login_screen.dart';
import 'shopping_providers.dart';

/// Shopping > Send to ICA: connecting this device to an ICA account, and
/// pushing what is still needed to a list the shop's hand scanner reads.
///
/// Per device, and said so on the screen: the account belongs to whoever
/// signs in here, the token stays in this phone, and nobody else's phone
/// learns about it. "Send the list" is still there for everyone else and
/// for the day this stops working, which will come without notice.
class IcaScreen extends ConsumerStatefulWidget {
  const IcaScreen({super.key});

  static const segment = 'ica';

  @override
  ConsumerState<IcaScreen> createState() => _IcaScreenState();
}

class _IcaScreenState extends ConsumerState<IcaScreen> {
  bool _busy = false;
  bool _connected = false;
  String? _listId;
  List<IcaList> _lists = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final connected = await ref.read(icaAuthProvider).isConnected;
    final listId = await ref.read(icaListsProvider).chosenList();
    final lists = connected
        ? await ref.read(icaApiProvider).lists()
        : const <IcaList>[];
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _listId = listId;
      _lists = lists;
    });
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final login = await ref.read(icaAuthProvider).begin();
    if (!mounted) return;
    setState(() => _busy = false);
    if (login == null) {
      _say(context.l10n.icaUnavailable);
      return;
    }

    final code = await IcaLoginScreen.show(context, login);
    if (code == null || !mounted) return;

    setState(() => _busy = true);
    final ok = await ref.read(icaAuthProvider).finish(login, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _say(context.l10n.icaSignInFailed);
      return;
    }
    await _refresh();
  }

  Future<void> _disconnect() async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.icaDisconnect),
        content: Text(l10n.icaDisconnectNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.icaDisconnect),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(icaListsProvider).disconnect();
    await _refresh();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final items = await _stillNeeded();
    final moved = await ref.read(icaListsProvider).push(items);
    if (!mounted) return;
    setState(() => _busy = false);
    _say(
      moved == null
          ? context.l10n.icaSendFailed
          : context.l10n.icaSent(moved),
    );
  }

  /// The current list, as names a shop can hold. Bought items travel too,
  /// so their rows can be struck through rather than left looking needed.
  Future<List<ListedItem>> _stillNeeded() async {
    final listId = await ref.read(currentListProvider.future);
    final items = await ref.read(shoppingItemsProvider.future);
    return [
      for (final (_, item) in items)
        if (item.listId == listId && item.state != ItemState.unavailable)
          ListedItem(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit?.label,
            bought: item.state == ItemState.bought,
          ),
    ];
  }

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.icaTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(l10n.icaHelp, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.icaCaveats,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (!IcaAuth.available)
            Text(l10n.icaUnavailable, style: theme.textTheme.bodyMedium)
          else if (!_connected)
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.login),
              label: Text(l10n.icaConnect),
            )
          else ...[
            Text(l10n.icaWhichList, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_lists.isEmpty)
              Text(l10n.icaNoLists, style: theme.textTheme.bodySmall)
            else
              for (final list in _lists)
                RadioListTile<String>(
                  value: list.id,
                  // ignore: deprecated_member_use
                  groupValue: _listId,
                  title: Text(list.title),
                  subtitle: Text(l10n.icaRowCount(list.rows.length)),
                  // ignore: deprecated_member_use
                  onChanged: _busy
                      ? null
                      : (id) async {
                          if (id == null) return;
                          await ref.read(icaListsProvider).chooseList(id);
                          await _refresh();
                        },
                ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || _listId == null ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(l10n.icaSend),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _disconnect,
              child: Text(l10n.icaDisconnect),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
