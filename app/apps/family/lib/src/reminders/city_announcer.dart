import 'dart:convert';
import 'dart:ui';

import 'package:domain/domain.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/misc.dart';

import '../common/l10n.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../features/actions/actions_providers.dart';
import '../features/homework/homework_screen.dart' show homeworkProvider;
import '../features/rewards/city_words.dart';
import '../features/rewards/rewards_providers.dart';

/// Runs with the change wake, for a child: what is new in their city.
/// Something ready to grow, a fire or a thief, today's happening. Each
/// once; the city is only interesting if the child hears about it.
class CityAnnouncer {
  CityAnnouncer(this._prefs);

  final DevicePreferences _prefs;

  static const _seenPref = 'city.announced';
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> announce(
    T Function<T>(ProviderListenable<T> provider) read, {
    required String memberId,
    required DateTime now,
  }) async {
    // Everything the city is counted from, loaded first: a provider read
    // before its stream has delivered would count an empty town.
    final settings = await read(settingsProvider.future);
    if (!settings.rewardsOn) return;
    final members = await read(membersProvider.future);
    if (!members.any((m) => m.id == memberId && m.isChild)) return;
    await read(worldsProvider.future);
    await read(actionsProvider.future);
    await read(homeworkProvider.future);

    final city = read(cityProvider(memberId));
    final today = familyDay(now);
    final happening = read(happeningTodayProvider(memberId));
    final trouble = read(troubleNowProvider(memberId));
    final ready = [
      for (final l in city.lots)
        if (city.canUpgrade(l.x, l.y)) '${l.x},${l.y},${city.sizeOf(l.x, l.y)}',
    ];
    final current = {
      for (final r in ready) 'ready:$r',
      if (trouble != null) 'trouble:${trouble.day.toIso8601String()}',
      if (happening != null) 'happening:${today.toIso8601String()}',
    };
    final raw = await _prefs.read(_seenPref);
    final seen = raw == null
        ? <String>{}
        : (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    await _prefs.write(_seenPref, jsonEncode(current.union(seen).toList()));

    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );
    if (ready.any((r) => !seen.contains('ready:$r'))) {
      await _post(
        'city:ready',
        l10n.cityNotifyReady,
        l10n.cityNotifyReadyBody,
        l10n,
      );
    }
    if (trouble != null &&
        !seen.contains('trouble:${trouble.day.toIso8601String()}')) {
      final fire = trouble.kind == TroubleKind.fire;
      await _post(
        'city:trouble',
        '${fire ? '🔥' : '🦹'} '
            '${fire ? l10n.troubleFire : l10n.troubleThiefLooking}',
        fire ? l10n.troubleFireBody : l10n.troubleThiefBody,
        l10n,
      );
    }
    if (happening != null &&
        !seen.contains('happening:${today.toIso8601String()}')) {
      await _post(
        'city:happening',
        '${happeningEmoji(happening)} ${happeningName(l10n, happening)}',
        happeningBody(l10n, happening),
        l10n,
      );
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
