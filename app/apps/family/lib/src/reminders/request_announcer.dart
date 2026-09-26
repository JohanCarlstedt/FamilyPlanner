import 'dart:convert';
import 'dart:ui';

import 'package:family_data/family_data.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../common/l10n.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../features/events/occurrence_editing.dart' show wallClock;
import '../features/rewards/trade_sheet.dart' show goodEmoji;

/// Runs with the change wake, beside the event announcer: a new "Can I…?"
/// for the parents, its answer for the child who asked, a new meal poll
/// for those who may vote, and for a child, a parent noticing what they
/// did: a chore approved or seen done, homework seen, a present. Compared
/// with what this device last saw; the first run only takes stock.
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
        for (final (id, a) in await store.watchActions().first)
          'a:$id': _actionState(a),
        ..._recognition(
          await store.watchActions().first,
          await store.watchHomework().first,
          await store.watchWorlds().first,
        ),
      }),
    );
  }

  /// What has been noticed, as keys: a chore approved or seen, homework
  /// seen, a present given. Anyone's: which are this member's is decided
  /// when announcing.
  static Map<String, String> _recognition(
    List<(String, ActionPayload)> actions,
    List<(String, HomeworkPayload)> homework,
    List<(String, WorldPayload)> worlds,
  ) => {
    // Marks a record that includes recognition: one from before it
    // existed is taken stock of, never announced from.
    '_ok': 'v1',
    for (final (id, a) in actions)
      if (a.state == ActionState.approved || a.seenBy != null)
        'ok:a:$id': '${a.state.name}|${a.seenBy ?? ''}',
    for (final (id, h) in homework)
      if (h.seenBy != null) 'ok:h:$id': h.seenBy!,
    for (final (_, w) in worlds)
      for (final p in w.presents) 'ok:g:${p.key}': p.to,
  };

  Future<void> announce({
    required FamilyStore store,
    required String memberId,
    required bool isParent,
    required Map<String, String> names,
    bool rewardsOn = false,
  }) async {
    final requests = await store.watchRequests().first;
    final polls = await store.watchPolls().first;
    final actions = await store.watchActions().first;
    final homework = await store.watchHomework().first;
    final worlds = await store.watchWorlds().first;
    final now = {
      for (final (id, r) in requests) 'r:$id': r.state.name,
      for (final (id, p) in polls) 'p:$id': p.state.name,
      for (final (id, a) in actions) 'a:$id': _actionState(a),
      ..._recognition(actions, homework, worlds),
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
    for (final (id, a) in actions) {
      if (!a.isFor(memberId) || !a.isOpen) continue;
      final before = seen['a:$id'];
      // Already on me last time round, so nothing has happened.
      if (before == _actionState(a)) continue;
      if (before != null &&
          before.split('|').first.split(',').contains(memberId)) {
        continue;
      }
      // Picking something up yourself is not news, and neither is a chore
      // planned from a template, which nobody chose to give you.
      if (a.payload.editedBy == memberId) continue;
      await _post(
        'a:$id',
        l10n.todoForYou,
        [a.title, ?_due(l10n, a.dueAt)].join(' · '),
        l10n,
      );
    }

    await _recognise(
      seen: seen,
      actions: actions,
      homework: homework,
      worlds: worlds,
      memberId: memberId,
      names: names,
      rewardsOn: rewardsOn,
      l10n: l10n,
    );

    for (final (id, p) in polls) {
      final before = seen['p:$id'];
      if (before == null &&
          p.state == PollState.open &&
          p.createdBy != memberId &&
          p.eligible.contains(memberId)) {
        await _post(
          'p:$id',
          l10n.pollOpened(p.title),
          pollOpenedBody(l10n, p),
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

  /// A parent noticing what this member did: news only when it is new
  /// since last time, and theirs. A key this device has never recorded
  /// (a phone that has just started keeping track) counts as seen, so
  /// nothing old is announced.
  Future<void> _recognise({
    required Map<String, String> seen,
    required List<(String, ActionPayload)> actions,
    required List<(String, HomeworkPayload)> homework,
    required List<(String, WorldPayload)> worlds,
    required String memberId,
    required Map<String, String> names,
    required bool rewardsOn,
    required AppLocalizations l10n,
  }) async {
    // Older records predate recognition: take stock without announcing.
    if (!seen.containsKey('_ok')) return;
    String body(int grows) =>
        rewardsOn ? l10n.recognisedGrows(grows) : l10n.recognisedWellDone;
    for (final (id, a) in actions) {
      final mine = a.completedBy == memberId || (a.shared && a.isFor(memberId));
      if (!mine) continue;
      final key = 'ok:a:$id';
      final state = '${a.state.name}|${a.seenBy ?? ''}';
      final before = seen[key];
      if (before == state) continue;
      final wasApproved = before?.startsWith('${ActionState.approved.name}|');
      if (a.state == ActionState.approved && wasApproved != true) {
        await _post(
          key,
          l10n.recognisedApproved(
            names[a.history
                    .where((s) => s.what == 'approved')
                    .lastOrNull
                    ?.by] ??
                l10n.someone,
            a.title,
          ),
          body(a.worth),
          l10n,
        );
      } else if (a.seenBy != null && before == null) {
        await _post(
          key,
          l10n.recognisedSeen(names[a.seenBy] ?? l10n.someone, a.title),
          body(a.worth),
          l10n,
        );
      }
    }
    for (final (id, h) in homework) {
      if (h.memberId != memberId || h.seenBy == null) continue;
      final key = 'ok:h:$id';
      if (seen.containsKey(key)) continue;
      await _post(
        key,
        l10n.recognisedHomework(names[h.seenBy] ?? l10n.someone, h.title),
        body(1),
        l10n,
      );
    }
    for (final (_, w) in worlds) {
      for (final p in w.presents) {
        if (p.to != memberId) continue;
        final key = 'ok:g:${p.key}';
        if (seen.containsKey(key)) continue;
        await _post(
          key,
          '🎁 ${l10n.presentFrom(names[p.from] ?? l10n.someone, [if (p.coins > 0) '${p.coins} 🪙', if (p.good != null && p.count > 0) '${p.count} ${goodEmoji(p.good!)}'].join(' + '))}',
          p.note ?? l10n.recognisedWellDone,
          l10n,
        );
      }
    }
  }

  /// What a new poll's notification says under its question.
  ///
  /// It said "tick every dinner you'd happily eat" for every poll, because
  /// polls were only ever about dinner when it was written. A question
  /// about cycling to school arrived telling people to choose a meal. A
  /// meal poll still says that; anything else says the one thing worth
  /// knowing from a lock screen, which is how long there is to answer.
  static String pollOpenedBody(AppLocalizations l10n, MealPollPayload poll) =>
      switch ((poll.topic, poll.closesAt)) {
        (PollTopic.meal, _) => l10n.pollOpenedBody,
        (_, final closes?) => l10n.pollAnswerBy(
          DateFormat('EEE d MMM HH:mm')
              .format(wallClock(closes, familyTimeZone)),
        ),
        _ => l10n.pollAnswerSoon,
      };

  static String? _due(AppLocalizations l10n, DateTime? at) =>
      at == null ? null : l10n.todoDueBy(DateFormat('EEE d MMM').format(at));

  /// Who it is on and where it has got to. Both matter: a chore handed
  /// from one person to another is news to the person receiving it, and a
  /// chore that has since been done is not news at all.
  static String _actionState(ActionPayload a) =>
      '${a.assignees.join(',')}|${a.state.name}';

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
