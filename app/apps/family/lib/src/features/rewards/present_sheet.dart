import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'trade_sheet.dart';

/// A parent's present to a child's city ([to]), or to the family's
/// project: a few coins or goods, with what it was for.
Future<void> showPresentSheet(
  BuildContext context, {
  required String to,
  String? name,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PresentSheet(to: to, name: name),
);

class _PresentSheet extends ConsumerStatefulWidget {
  const _PresentSheet({required this.to, this.name});

  final String to;
  final String? name;

  @override
  ConsumerState<_PresentSheet> createState() => _PresentSheetState();
}

class _PresentSheetState extends ConsumerState<_PresentSheet> {
  var _coins = true;
  var _amount = 3;
  var _good = Good.fish;
  var _toProject = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _give() async {
    final me = ref.read(membershipProvider).value;
    if (me == null || !me.isParent) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final store = await ref.read(familyStoreProvider.future);
    final coins = _coins && !_toProject;
    final given = await store.givePresent(
      from: me.memberId,
      to: _toProject ? CityGift.family : widget.to,
      coins: coins ? _amount : 0,
      good: coins ? null : _good,
      count: coins ? 0 : _amount,
      note: _note.text,
    );
    if (!given) return;
    ref.read(syncControllerProvider.notifier).syncNow();
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.presentSent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final coins = _coins && !_toProject;
    final most = coins ? maxGiftCoins : maxGiftGoods;
    if (_amount > most) _amount = most;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '🎁 ${l10n.presentGive}'
                '${widget.name == null ? '' : ' · ${widget.name}'}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.presentHow,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.presentCoins),
                    icon: const Text('🪙'),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.presentGoods),
                    icon: const Text('📦'),
                  ),
                ],
                selected: {coins},
                onSelectionChanged: (v) => setState(() {
                  _coins = v.single;
                  if (_coins) _toProject = false;
                }),
              ),
              if (!coins) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in Good.values)
                      ChoiceChip(
                        label: Text('${goodEmoji(g)} ${goodName(l10n, g)}'),
                        selected: _good == g,
                        onSelected: (_) => setState(() => _good = g),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _toProject,
                  onChanged: (v) => setState(() => _toProject = v),
                  title: Text(l10n.presentToProject),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _amount > 1
                        ? () => setState(() => _amount--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Text(
                      '$_amount ${coins ? '🪙' : goodEmoji(_good)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _amount < most
                        ? () => setState(() => _amount++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.presentNote),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _give,
                icon: const Icon(Icons.card_giftcard),
                label: Text(l10n.presentSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
