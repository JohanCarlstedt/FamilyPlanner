import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/store_providers.dart';
import 'ica_api.dart';
import 'ica_auth.dart';

/// Pushing the family's shopping list to ICA's, so it reaches the hand
/// scanner in the shop (docs/ica.md).
///
/// Set up per device, never synced, because the ICA account is one
/// person's and the token for it lives in that phone's keychain alone.
/// The same shape the phone's own calendars have, and for the same
/// reason: another phone has no business seeing this account.
///
/// One direction only. The family's list is the truth; ICA's is a copy
/// kept useful enough to shop from. What comes back from ICA — someone
/// ticking an item off at the till — is not read, because a two-way merge
/// with two people in two shops is a thing that goes wrong quietly.
class IcaLists {
  const IcaLists(this._ref);

  final Ref _ref;

  /// Which ICA list the family's is pushed to. Per device.
  static const _chosen = 'ica.list.v1';

  /// The rows this device created, per list. Kept so that rows someone
  /// typed into ICA's own app are recognisable as not ours, which is the
  /// whole of the promise never to touch them.
  static String _ours(String listId) => 'ica.rows.$listId.v1';

  Future<String?> chosenList() async {
    // Disconnecting blanks it rather than deleting — preferences have no
    // delete — so empty has to mean the same as never set.
    final chosen = await (await _ref.read(devicePreferencesProvider.future))
        .read(_chosen);
    return (chosen == null || chosen.isEmpty) ? null : chosen;
  }

  Future<void> chooseList(String listId) async =>
      (await _ref.read(devicePreferencesProvider.future))
          .write(_chosen, listId);

  /// Sends what is still needed. Returns how much moved, or null when it
  /// could not be done at all — not signed in, no list chosen, no
  /// network, or a country ICA does not serve.
  Future<int?> push(List<ListedItem> items) async {
    final listId = await chosenList();
    if (listId == null) return null;
    if (!await _ref.read(icaAuthProvider).isConnected) return null;

    final api = _ref.read(icaApiProvider);
    final list = await api.list(listId);
    if (list == null) return null;

    final prefs = await _ref.read(devicePreferencesProvider.future);
    final mine = ((await prefs.read(_ours(listId)))?.split(',') ?? const [])
        .where((id) => id.isNotEmpty)
        .toSet();

    final plan = planShopPush(items, [
      for (final row in list.rows)
        ShopRow(
          id: row.id,
          name: row.name,
          struckThrough: row.struckThrough,
          ours: mine.contains(row.id),
        ),
    ]);
    if (plan.isEmpty) return 0;

    final created = await api.push(
      listId: listId,
      add: plan.add,
      strike: plan.strike,
      existing: list.rows,
    );
    if (created == null) return null;

    // Remembered only while the row is still there, so this does not grow
    // for ever on a list that is cleared every week.
    final alive = {for (final row in list.rows) row.id};
    await prefs.write(
      _ours(listId),
      {...mine.where(alive.contains), ...created}.join(','),
    );
    return plan.count;
  }

  /// Forgets this device's connection and which rows were its own. The
  /// account itself is untouched: access is withdrawn at ICA, by the
  /// person whose account it is.
  Future<void> disconnect() async {
    await _ref.read(icaAuthProvider).disconnect();
    final listId = await chosenList();
    if (listId == null) return;
    final prefs = await _ref.read(devicePreferencesProvider.future);
    await prefs.write(_ours(listId), '');
    await prefs.write(_chosen, '');
    debugPrint('ICA disconnected on this device');
  }
}

final icaListsProvider = Provider<IcaLists>(IcaLists.new);
