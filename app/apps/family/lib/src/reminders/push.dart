import 'dart:async';
import 'dart:io';

import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../api/family_api_provider.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../membership/membership.dart';
import 'change_announcer.dart';
import 'reminder_notifications.dart';
import 'reminder_scheduler.dart';

/// Push reaches Android through FCM. iOS needs APNs, which needs a paid Apple
/// developer account; until then an iPhone gets no wakes.
bool get pushSupported => !kIsWeb && Platform.isAndroid;

/// Call once from main, before runApp.
Future<void> initPush() async {
  if (!pushSupported) return;
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(onBackgroundWake);
}

/// A wake that arrives with the app in the background or closed: its own
/// isolate, so everything is set up again from nothing.
@pragma('vm:entry-point')
Future<void> onBackgroundWake(RemoteMessage message) async {
  tzdata.initializeTimeZones();
  await RustLib.init();
  final container = ProviderContainer();
  try {
    await handleWake(container.read, message.data['ref'] as String?);
  } finally {
    container.dispose();
  }
}

/// The reference the server's change wake carries (backend ChangeWakes.Ref).
const changeWakeRef = 'sync';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Everything the planner needs, read fresh.
Future<ReminderContext?> _context(Reader read) async {
  final membership = await read(membershipProvider.future);
  if (membership == null) return null;
  final repository = await read(familyRepositoryProvider.future);
  return ReminderContext(
    events: await read(eventsProvider.future),
    memberId: membership.memberId,
    timeZone: repository.timeZone,
    members: await read(membersProvider.future),
    settings: await read(settingsProvider.future),
    places: {for (final p in await read(placesProvider.future)) p.id: p},
  );
}

/// Syncs first, so a cancellation made on another phone since the wake was
/// registered is seen, then shows what's still owed and brings the wakes
/// ahead up to date.
Future<void> handleWake(Reader read, String? ref) async {
  if (await read(membershipProvider.future) == null) return;
  final store = await read(familyStoreProvider.future);
  try {
    await store.sync();
  } on Object catch (e) {
    // Offline: the local copy is the best there is. Better a reminder from it
    // than none.
    debugPrint('Sync before a reminder failed: $e');
  }
  final context = await _context(read);
  if (context == null) return;
  final scheduler = await read(reminderSchedulerProvider.future);
  final now = DateTime.now().toUtc();
  if (ref == changeWakeRef) {
    await ChangeAnnouncer(await read(devicePreferencesProvider.future))
        .announce(store: store, memberId: context.memberId, now: now);
  } else if (ref != null) {
    final content = await scheduler.resolve(ref, context, now: now);
    if (content != null) {
      await ReminderNotifications.show(content, context.timeZone);
    }
  }
  await scheduler.reconcile(context, now: now);
}

/// Wakes go to the server's scheduler for this device.
class _ServerWakes implements WakeChannel {
  _ServerWakes(this._api, this._deviceId);

  final FamilyApi _api;
  final String _deviceId;

  @override
  Future<void> schedule(Map<String, DateTime> wakes, List<String> cancel) =>
      _api.scheduleWakes(asDevice: _deviceId, wakes: wakes, cancel: cancel);
}

final reminderSchedulerProvider = FutureProvider<ReminderScheduler>((
  ref,
) async {
  final membership = await ref.watch(membershipProvider.future);
  return ReminderScheduler(
    preferences: await ref.watch(devicePreferencesProvider.future),
    channel: _ServerWakes(ref.watch(familyApiProvider), membership!.deviceId),
  );
});

/// While the app runs: registers this device's push token and keeps its wakes
/// in step with the calendar. Watched by the shell, so it starts once the
/// device belongs to a family.
final pushProvider = Provider<void>((ref) {
  if (!pushSupported) return;

  final subscriptions = <StreamSubscription<Object?>>[];
  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
  });

  unawaited(() async {
    final membership = await ref.read(membershipProvider.future);
    if (membership == null) return;
    final api = ref.read(familyApiProvider);
    final messaging = FirebaseMessaging.instance;
    Future<void> register(String token) =>
        api.registerPushToken(asDevice: membership.deviceId, token: token);
    try {
      if (await messaging.getToken() case final token?) await register(token);
    } on Object catch (e) {
      debugPrint('Push token registration failed: $e');
    }
    try {
      await ChangeAnnouncer(await ref.read(devicePreferencesProvider.future))
          .ensureSnapshot(
            await ref.read(familyStoreProvider.future),
            DateTime.now().toUtc(),
          );
    } on Object catch (e) {
      debugPrint('Taking stock of events failed: $e');
    }
    subscriptions
      ..add(messaging.onTokenRefresh.listen(register))
      ..add(
        FirebaseMessaging.onMessage.listen(
          (m) => handleWake(ref.read, m.data['ref'] as String?),
        ),
      );
  }());

  // Serialised, so two quick changes can't register the same wake twice.
  var pending = Future<void>.value();
  void replan() {
    pending = pending.then((_) async {
      try {
        final context = await _context(ref.read);
        if (context == null) return;
        final scheduler = await ref.read(reminderSchedulerProvider.future);
        await scheduler.reconcile(context, now: DateTime.now().toUtc());
      } on Object catch (e) {
        // Tried again on the next change or sync.
        debugPrint('Scheduling reminders failed: $e');
      }
    });
  }

  // Anything that moves a reminder: the events, who's who, where, and the
  // family's quiet hours and digest.
  ref
    ..listen(eventsProvider, (_, _) => replan(), fireImmediately: true)
    ..listen(membersProvider, (_, _) => replan())
    ..listen(placesProvider, (_, _) => replan())
    ..listen(settingsProvider, (_, _) => replan());
});
