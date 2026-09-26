import 'dart:convert';
import 'dart:ui';

import 'package:family_data/family_data.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../common/l10n.dart';
import '../data/store_providers.dart';

/// Runs with the change wake: a new wish on someone else's list, and a
/// gift someone else has taken. For the family and the relatives alike.
///
/// Secret by construction: a claim on a member's list is sealed to
/// everyone but them, so their phone cannot read it and has nothing to
/// announce, and [FamilyStore.watchClaimsFor] leaves out claims on the
/// viewer's own lists besides. On Android the text is also hidden on the
/// lock screen, where whoever the gift is for might glance at it.
class GiftAnnouncer {
  GiftAnnouncer(this._prefs);

  final DevicePreferences _prefs;

  static const _seenPref = 'gifts.announced';
  static final _notifications = FlutterLocalNotificationsPlugin();

  /// Takes stock once, when the app starts, so the first wake after has
  /// something to compare with and nothing old is news.
  Future<void> ensureSeen(FamilyStore store, String memberId) async {
    if (await _prefs.read(_seenPref) != null) return;
    await _prefs.write(
      _seenPref,
      jsonEncode([
        for (final (id, _) in await store.watchWishlistItems().first) 'w:$id',
        for (final (id, _) in await store.watchClaimsFor(memberId).first)
          'c:$id',
      ]),
    );
  }

  Future<void> announce({
    required FamilyStore store,
    required String memberId,
    required Map<String, String> names,
  }) async {
    final people = {
      for (final (id, p) in await store.watchPeople().first) id: p,
    };
    final lists = {
      for (final (id, l) in await store.watchWishlists().first) id: l,
    };
    final items = await store.watchWishlistItems().first;
    final claims = await store.watchClaimsFor(memberId).first;

    // Whose list an item is on, and whether that is this member's own.
    PersonPayload? personOf(WishlistItemPayload i) =>
        people[lists[i.wishlistId]?.personId];
    bool ownList(WishlistItemPayload i) => personOf(i)?.memberId == memberId;

    final now = {
      for (final (id, _) in items) 'w:$id',
      for (final (id, _) in claims) 'c:$id',
    };
    final raw = await _prefs.read(_seenPref);
    await _prefs.write(_seenPref, jsonEncode(now.toList()));
    // The first run only takes stock: nothing old is news.
    if (raw == null) return;
    final seen = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();

    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );
    final byId = {for (final (id, i) in items) id: i};

    for (final (id, item) in items) {
      if (seen.contains('w:$id') || ownList(item)) continue;
      // Wishing for something yourself, or adding it, is not news to you.
      if (item.payload.editedBy == memberId) continue;
      if (item.received) continue;
      await _post(
        'w:$id',
        l10n.giftNewWish(personOf(item)?.name ?? l10n.someone, item.title),
        l10n,
      );
    }
    for (final (id, claim) in claims) {
      if (seen.contains('c:$id') || claim.claimedBy == memberId) continue;
      final item = byId[claim.itemId];
      if (item == null || ownList(item)) continue;
      await _post(
        'c:$id',
        l10n.giftTaken(
          names[claim.claimedBy] ?? l10n.someone,
          personOf(item)?.name ?? l10n.someone,
          item.title,
        ),
        l10n,
      );
    }
  }

  static Future<void> _post(
    String key,
    String text,
    AppLocalizations l10n,
  ) => _notifications.show(
    key.hashCode & 0x7fffffff,
    '🎁 ${l10n.giftChannel}',
    text,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'gifts',
        l10n.giftChannel,
        channelDescription: l10n.giftChannelDescription,
        // On the lock screen: that there is news, not what it is, for
        // whoever the gift is for might glance at it.
        visibility: NotificationVisibility.private,
      ),
    ),
  );
}
