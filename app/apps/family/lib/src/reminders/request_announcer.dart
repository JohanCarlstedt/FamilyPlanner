import 'dart:convert';
import 'dart:ui';

import 'package:family_data/family_data.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../common/l10n.dart';
import '../data/store_providers.dart';

/// Runs with the change wake, beside the event announcer: a new "Can I…?"
/// for the parents, its answer for the child who asked, a new meal poll
/// for those who may vote. Compared with what this device last saw; the
/// first run only takes stock.
class RequestAnnouncer {
  RequestAnnouncer(this._prefs);

  final DevicePreferences _prefs;

  static const _seenPref = 'changes.requests';
  static final _notifications = FlutterLocalNotificationsPlugin();

  /// Takes stock once, so the first change wake has something to compare.
  Future<void> ensureSeen(FamilyStore store) async {
    if (await _prefs.read(_seenPref) != null) return;
    await _prefs.write(
      _seenPref,
      jsonEncode({
        for (final (id, r) in await store.watchRequests().first)
          'r:$id': r.state.name,
        for (final (id, p) in await store.watchPolls().first)
          'p:$id': p.state.name,
      }),
    );
  }

  Future<void> announce({
    required FamilyStore store,
    required String memberId,
    required bool isParent,
    required Map<String, String> names,
  }) async {
    final requests = await store.watchRequests().first;
    final polls = await store.watchPolls().first;
    final now = {
      for (final (id, r) in requests) 'r:$id': r.state.name,
      for (final (id, p) in polls) 'p:$id': p.state.name,
    };
    final raw = await _prefs.read(_seenPref);
    await _prefs.write(_seenPref, jsonEncode(now));
    if (raw == null) return;
    final seen = (jsonDecode(raw) as Map<String, dynamic>)
        .cast<String, String>();
    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );

    for (final (id, r) in requests) {
      final before = seen['r:$id'];
      if (isParent &&
          before == null &&
          r.state == RequestState.pending &&
          r.requestedBy != memberId) {
        await _post(
          'r:$id',
          l10n.asks(names[r.requestedBy] ?? l10n.someone),
          r.message,
          l10n,
        );
      } else if (r.requestedBy == memberId &&
          before == RequestState.pending.name &&
          r.state != RequestState.pending) {
        final who = names[r.decidedBy] ?? l10n.someone;
        await _post(
          'r:$id',
          r.state == RequestState.approved
              ? l10n.answeredYes(who)
              : l10n.answeredNo(who),
          [r.message, ?r.answer].join(' · '),
          l10n,
        );
      }
    }
    for (final (id, p) in polls) {
      final before = seen['p:$id'];
      if (before == null &&
          p.state == PollState.open &&
          p.createdBy != memberId &&
          p.eligible.contains(memberId)) {
        await _post(
          'p:$id',
          l10n.pollOpened(p.title),
          l10n.pollOpenedBody,
          l10n,
        );
      } else if (before == PollState.open.name &&
          p.state != PollState.open &&
          p.eligible.contains(memberId)) {
        // Everyone who could vote hears how it went, whether or not they
        // did. A poll that closes in silence teaches people not to bother
        // with the next one — and the person who asked is usually the
        // last to think of telling anyone.
        final won = p.winner;
        final choice = won == null
            ? null
            : p.options
                  .where((o) => o.id == won)
                  .map((o) => o.title)
                  .whereType<String>()
                  .firstOrNull;
        await _post(
          'p:$id:closed',
          l10n.pollClosed(p.title),
          choice == null ? l10n.pollClosedNoWinner : l10n.pollWon(choice),
          l10n,
        );
      }
    }
  }

  static Future<void> _post(
    String key,
    String title,
    String body,
    AppLocalizations l10n,
  ) => _notifications.show(
    key.hashCode & 0x7fffffff,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'changes',
        l10n.changesChannel,
        channelDescription: l10n.changesChannelDescription,
      ),
    ),
  );
}
