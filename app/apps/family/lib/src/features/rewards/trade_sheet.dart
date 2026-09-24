import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'rewards_providers.dart';

String goodEmoji(Good g) => switch (g) {
  Good.fish => '🐟',
  Good.wood => '🪵',
  Good.stone => '🪨',
  Good.wool => '🧶',
  Good.honey => '🍯',
};

String goodName(AppLocalizations l10n, Good g) => switch (g) {
  Good.fish => l10n.goodFish,
  Good.wood => l10n.goodWood,
  Good.stone => l10n.goodStone,
  Good.wool => l10n.goodWool,
  Good.honey => l10n.goodHoney,
};

String landmarkEmoji(Landmark l) => switch (l) {
  Landmark.harbour => '⚓',
  Landmark.castle => '🏰',
  Landmark.zoo => '🦒',
  Landmark.stadium => '🏟️',
  Landmark.bakery => '🥐',
};

String landmarkName(AppLocalizations l10n, Landmark l) => switch (l) {
  Landmark.harbour => l10n.landmarkHarbour,
  Landmark.castle => l10n.landmarkCastle,
  Landmark.zoo => l10n.landmarkZoo,
  Landmark.stadium => l10n.landmarkStadium,
  Landmark.bakery => l10n.landmarkBakery,
};

/// "3 🐟 · 3 🪵": a price, or a pile, in the symbols a child reads.
String goodsText(Map<Good, int> goods) => [
  for (final MapEntry(key: g, value: n) in goods.entries)
    if (n > 0) '$n ${goodEmoji(g)}',
].join(' · ');

/// Goods this version knows on both sides: an offer a later version
/// wrote in goods this one cannot name is left alone, not shown wrong.
bool _known(TradePayload t) => t.give != null && t.get != null;

/// Offers made to [me] and not answered yet.
List<(String, TradePayload)> offersTo(
  String? me,
  List<(String, TradePayload)> trades,
) => [
  for (final t in trades)
    if (me != null && t.$2.to == me && t.$2.isOpen && _known(t.$2)) t,
];

/// The trading house: what this child has, offers to them and from them,
/// and a new offer to a brother or sister. Only ever even trades.
Future<void> showTradeSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _TradeSheet(),
);

class _TradeSheet extends ConsumerStatefulWidget {
  const _TradeSheet();

  @override
  ConsumerState<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends ConsumerState<_TradeSheet> {
  String? _with;
  Good? _give;
  Good? _get;
  var _count = 1;

  Future<void> _run(Future<Object?> Function(FamilyStore s) f) async {
    final store = await ref.read(familyStoreProvider.future);
    await f(store);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value?.memberId;
    final ledger = ref.watch(goodsProvider);
    final traders = ref.watch(tradersProvider);
    final trades = ref.watch(tradesProvider).value ?? const [];
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    if (me == null) return const SizedBox(height: 120);
    final mine = {
      for (final g in Good.values)
        if (ledger.of(me, g) > 0) g: ledger.of(me, g),
    };
    final incoming = offersTo(me, trades);
    final outgoing = [
      for (final t in trades)
        if (t.$2.from == me && t.$2.isOpen && _known(t.$2)) t,
    ];
    final others = {
      for (final MapEntry(key: who, value: good) in traders.entries)
        if (who != me) who: good,
    };

    // The form keeps to what can actually be swapped right now.
    final partner = others.containsKey(_with) ? _with : others.keys.firstOrNull;
    final give = mine.containsKey(_give) ? _give : mine.keys.firstOrNull;
    final wanted = partner == null ? null : (_get ?? others[partner]);
    final get = wanted == give ? null : wanted;
    final theirs = partner == null || get == null ? 0 : ledger.of(partner, get);
    final most = give == null
        ? 0
        : [mine[give]!, theirs].reduce((a, b) => a < b ? a : b);
    final count = _count.clamp(1, most < 1 ? 1 : most);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.cityMarket, style: theme.textTheme.titleLarge),
            ),
            if (traders[me] case final good?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  '${goodEmoji(good)}  ${l10n.cityMarketMakes(goodName(l10n, good))}',
                ),
              ),
            heading(l10n.tradeYourGoods),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                mine.isEmpty ? l10n.tradeNoGoods : goodsText(mine),
                style: mine.isEmpty ? null : const TextStyle(fontSize: 22),
              ),
            ),
            if (incoming.isNotEmpty) ...[
              heading(l10n.tradeOffersToYou),
              for (final (id, t) in incoming)
                ListTile(
                  title: Text(
                    l10n.tradeOfferLine(
                      names[t.from] ?? '—',
                      '${t.count} ${goodEmoji(t.give!)}',
                      '${t.count} ${goodEmoji(t.get!)}',
                    ),
                  ),
                  subtitle: ledger.of(me, t.get!) < t.count
                      ? Text(l10n.tradeNotEnough)
                      : null,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _run((s) => s.answerTrade(id, accept: false)),
                        child: Text(l10n.tradeDecline),
                      ),
                      FilledButton(
                        onPressed: ledger.of(me, t.get!) < t.count
                            ? null
                            : () =>
                                  _run((s) => s.answerTrade(id, accept: true)),
                        child: Text(l10n.tradeAccept),
                      ),
                    ],
                  ),
                ),
            ],
            if (outgoing.isNotEmpty) ...[
              heading(l10n.tradeYourOffers),
              for (final (id, t) in outgoing)
                ListTile(
                  title: Text(
                    l10n.tradeYourOfferLine(
                      names[t.to] ?? '—',
                      '${t.count} ${goodEmoji(t.give!)}',
                      '${t.count} ${goodEmoji(t.get!)}',
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => _run((s) => s.withdrawTrade(id)),
                    child: Text(l10n.tradeWithdraw),
                  ),
                ),
            ],
            heading(l10n.tradeNew),
            if (others.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.tradeNobody),
              )
            else if (mine.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.tradeNoGoods),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: partner,
                      decoration: InputDecoration(labelText: l10n.tradeWith),
                      items: [
                        for (final MapEntry(key: who, value: good)
                            in others.entries)
                          DropdownMenuItem(
                            value: who,
                            child: Text(
                              '${names[who] ?? '—'}  ${goodEmoji(good)}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _with = v;
                        _get = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.tradeGive, style: theme.textTheme.labelLarge),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final g in mine.keys)
                          ChoiceChip(
                            label: Text('${goodEmoji(g)} ${mine[g]}'),
                            selected: g == give,
                            onSelected: (_) => setState(() => _give = g),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.tradeGet, style: theme.textTheme.labelLarge),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final g in Good.values)
                          if (g != give)
                            ChoiceChip(
                              label: Text(goodEmoji(g)),
                              selected: g == get,
                              onSelected: (_) => setState(() => _get = g),
                            ),
                      ],
                    ),
                    if (partner != null && get != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.tradeTheyHave(
                            names[partner] ?? '—',
                            '$theirs ${goodEmoji(get)}',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: count > 1
                              ? () => setState(() => _count = count - 1)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          give == null || get == null
                              ? '$count'
                              : '$count ${goodEmoji(give)}  ⇄  $count ${goodEmoji(get)}',
                          style: theme.textTheme.titleMedium,
                        ),
                        IconButton(
                          onPressed: count < most
                              ? () => setState(() => _count = count + 1)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Text(l10n.tradeEven, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed:
                          partner == null ||
                              give == null ||
                              get == null ||
                              most < 1
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _run(
                                (s) => s.offerTrade(
                                  to: partner,
                                  give: give,
                                  get: get,
                                  count: count,
                                ),
                              );
                              messenger.showSnackBar(
                                SnackBar(content: Text(l10n.tradeSent)),
                              );
                              setState(() => _count = 1);
                            },
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.tradeSend),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
