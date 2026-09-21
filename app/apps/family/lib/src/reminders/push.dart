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
import '../chat/chat_providers.dart';
import 'change_announcer.dart';
import 'request_announcer.dart';
import 'reminder_notifications.dart';
import 'reminder_scheduler.dart';

/// Whether this build can be woken by the server: Firebase started, which
/// on iOS also means the account behind it has APNs. Without it an iPhone
/// falls back to reminders it schedules itself.
bool get pushSupported => _pushReady;
var _pushReady = false;

/// Call once from main, before runApp.
Future<void> initPush() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    _pushReady = true;
    FirebaseMessaging.onBackgroundMessage(onBackgroundWake);
  } on Object catch (e) {
    // No config file on this platform yet: the app runs, and reminders
    // stay local (spec §8 — a phone that can't be woken still reminds).
    debugPrint('Push not configured: $e');
  }
}

/// Whether this isolate has set up the Rust core.
var _rustReady = false;

/// A wake that arrives with the app in the background or closed: its own
/// isolate, so everything is set up again from nothing.
@pragma('vm:entry-point')
Future<void> onBackgroundWake(RemoteMessage message) async {
  // Nothing sees an error thrown here, so every step says how it went.
  debugPrint('wake: background, ref=${message.data['ref']}');
  final container = ProviderContainer();
  // Nothing on screen listens in the background, and a provider nobody
  // listens to is paused: its stream never delivers. Listen to each one read.
  T keepAlive<T>(ProviderListenable<T> provider) =>
      container.listen<T>(provider, (_, _) {}).read();
  try {
    tzdata.initializeTimeZones();
    // Android reuses the background engine for the next push: the Rust core
    // is set up once per isolate, or every wake after the first fails.
    if (!_rustReady) {
      await RustLib.init();
      _rustReady = true;
    }
    await handleWake(keepAlive, message.data['ref'] as String?);
  } catch (e, stack) {
    debugPrint('wake: failed: $e\n$stack');
  } finally {
    container.dispose();
  }
}

/// The reference the server's change wake carries (backend ChangeWakes.Ref).
const changeWakeRef = 'sync';

/// The reference a new chat message's wake carries (backend MlsEndpoints).
const chatWakeRef = 'chat';

/// New messages from the family, shown with the sender's name: decrypted
/// here, never in the push.
Future<void> _announceChat(Reader read, ReminderContext context) async {
  final fresh = await syncChat(read);
  if (fresh.isEmpty) return;
  final owners = await read(deviceMembersProvider.future);
  final names = {for (final m in context.members) m.id: m.displayName};
  final chat = await read(familyChatProvider.future);
  final conversations = await chat.conversations();
  final titles = {
    for (final c in conversations)
      if (c.scope == ConversationScope.group) c.group: c.title,
  };
  // Everything waiting, not just what arrived in this wake: the number on
  // the icon answers "how much have I missed", and a count of one batch
  // would undercount anyone who left two unread yesterday.
  final unread = conversations.fold<int>(0, (sum, c) => sum + c.unread);
  for (final m in fresh) {
    if (m.kind != ChatMessageKind.text) continue;
    final sender = names[owners[m.sender]];
    await ReminderNotifications.showChat(
      id: m.id,
      sender: switch (titles[m.group]) {
        final title? when sender != null => '$sender · $title',
        _ => sender,
      },
      text: m.text,
      unread: unread,
    );
  }
}

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
    withDevices: await read(membersWithDevicesProvider.future),
    absences: await read(absencesProvider.future),
    equipment: await _equipment(read),
    custody: [
      for (final (_, c) in await read(custodyPayloadsProvider.future))
        ?c.toDomain(),
    ],
  );
}

/// Each event's kit, from the sets it carries.
Future<Map<String, List<KitItem>>> _equipment(Reader read) async {
  final store = await read(familyStoreProvider.future);
  final sets = {
    for (final (id, s) in await store.watchEquipmentSets().first) id: s.items,
  };
  if (sets.isEmpty) return const {};
  return {
    for (final (id, e) in await store.watchEvents().first)
      if (e.equipmentSets.isNotEmpty)
        id: [for (final s in e.equipmentSets) ...?sets[s]],
  };
}

/// Syncs first, so a cancellation made on another phone since the wake was
/// registered is seen, then shows what's still owed and brings the wakes
/// ahead up to date.
Future<void> handleWake(Reader read, String? ref) async {
  if (await read(membershipProvider.future) == null) {
    debugPrint('wake: no family on this device');
    return;
  }
  final store = await read(familyStoreProvider.future);
  debugPrint('wake: store open');
  try {
    await store.sync();
  } on Object catch (e) {
    // Offline: the local copy is the best there is. Better a reminder from it
    // than none.
    debugPrint('Sync before a reminder failed: $e');
  }
  final context = await _context(read);
  if (context == null) return;
  debugPrint('wake: ${context.events.length} events');
  final scheduler = await read(reminderSchedulerProvider.future);
  final now = DateTime.now().toUtc();
  if (ref == chatWakeRef) {
    await _announceChat(read, context);
  } else if (ref == changeWakeRef) {
    final prefs = await read(devicePreferencesProvider.future);
    await ChangeAnnouncer(prefs)
        .announce(store: store, memberId: context.memberId, now: now);
    await RequestAnnouncer(prefs).announce(
      store: store,
      memberId: context.memberId,
      isParent: (await read(membershipProvider.future))?.isParent ?? false,
      names: {for (final m in context.members) m.id: m.displayName},
    );
  } else if (ref != null) {
    final content = await scheduler.resolve(ref, context, now: now);
    debugPrint('wake: $ref is ${content?.runtimeType ?? 'nothing owed'}');
    if (content != null) {
      await ReminderNotifications.show(
        content,
        context.timeZone,
        names: {for (final m in context.members) m.id: m.displayName},
        equipment: context.equipment,
        me: context.memberId,
      );
    }
  }
  await scheduler.reconcile(context, now: now);
  debugPrint('wake: done');
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

/// Members with an active device, from the server's directory. Refetched when
/// the family's members change; empty when offline, which routes nothing
/// rather than doubling reminders.
final membersWithDevicesProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(membersProvider);
  final membership = await ref.watch(membershipProvider.future);
  if (membership == null) return const {};
  try {
    final devices = await ref
        .read(familyApiProvider)
        .directory(
          asDevice: membership.deviceId,
          familyId: membership.familyId,
        );
    return {
      for (final d in devices)
        if (!d.revoked) d.memberId,
    };
  } on Object catch (e) {
    debugPrint('Device directory unavailable: $e');
    return const {};
  }
});

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
/// iOS has no push until there's a paid Apple account: reminders are
/// scheduled on the device instead, re-planned on every change and sync.
/// An iPhone with no wakes behind it schedules its own reminders instead,
/// so the same plan arrives either way — and never twice.
bool get localRemindersOnly => !kIsWeb && Platform.isIOS && !_pushReady;

final pushProvider = Provider<void>((ref) {
  unawaited(() async {
    if ((await ref.read(membershipProvider.future))?.isParent ?? false) {
      try {
        await ReminderNotifications.scheduleWeeklyReview(familyTimeZone);
      } on Object catch (e) {
        debugPrint('Weekly review nudge failed: $e');
      }
    }
  }());
  if (!pushSupported && !localRemindersOnly) return;

  final subscriptions = <StreamSubscription<Object?>>[];
  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
  });

  if (pushSupported) {
    unawaited(() async {
      final membership = await ref.read(membershipProvider.future);
      if (membership == null) return;
      final api = ref.read(familyApiProvider);
      final messaging = FirebaseMessaging.instance;
      Future<void> register(String token) =>
          api.registerPushToken(asDevice: membership.deviceId, token: token);
      if (!kIsWeb && Platform.isIOS) {
        // iOS asks before it will carry a wake, and hands out its token
        // only once APNs has answered.
        try {
          await messaging.requestPermission();
          await messaging.setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
        } on Object catch (e) {
          debugPrint('Push permission not granted: $e');
        }
      }
      try {
        if (await messaging.getToken() case final token?) await register(token);
      } on Object catch (e) {
        debugPrint('Push token registration failed: $e');
      }
      try {
        final prefs = await ref.read(devicePreferencesProvider.future);
        final store = await ref.read(familyStoreProvider.future);
        await ChangeAnnouncer(prefs)
            .ensureSnapshot(store, DateTime.now().toUtc());
        await RequestAnnouncer(prefs).ensureSeen(store);
      } on Object catch (e) {
        debugPrint('Taking stock of events failed: $e');
      }
      subscriptions
        ..add(messaging.onTokenRefresh.listen(register))
        ..add(
          FirebaseMessaging.onMessage.listen((m) async {
            debugPrint('wake: foreground, ref=${m.data['ref']}');
            try {
              await handleWake(ref.read, m.data['ref'] as String?);
            } catch (e, stack) {
              debugPrint('wake: failed: $e\n$stack');
            }
          }),
        );
    }());
  }

  // One plan at a time, so two quick changes can't register the same wake
  // twice; changes arriving meanwhile (a feed import writes dozens) fold
  // into a single run after it.
  Future<void> planOnce() async {
    try {
      final context = await _context(ref.read);
      if (context == null) return;
      if (localRemindersOnly) {
        // Without permission iOS refuses every one; the Today banner asks,
        // and a change of heart replans on the next change or sync.
        if (!await ReminderNotifications.allowed()) return;
        await ReminderNotifications.scheduleLocal(
          context,
          now: DateTime.now().toUtc(),
        );
        return;
      }
      final scheduler = await ref.read(reminderSchedulerProvider.future);
      await scheduler.reconcile(context, now: DateTime.now().toUtc());
    } on Object catch (e) {
      // Tried again on the next change or sync.
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  var planning = false;
  var changedSince = false;
  void replan() {
    changedSince = true;
    if (planning) return;
    planning = true;
    unawaited(() async {
      while (changedSince) {
        changedSince = false;
        // Let a burst of writes land first.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await planOnce();
      }
      planning = false;
    }());
  }

  // Anything that moves a reminder: the events, who's who, where, and the
  // family's quiet hours and digest.
  ref
    ..listen(eventsProvider, (_, _) => replan(), fireImmediately: true)
    ..listen(absencesProvider, (_, _) => replan())
    ..listen(membersProvider, (_, _) => replan())
    ..listen(placesProvider, (_, _) => replan())
    ..listen(settingsProvider, (_, _) => replan())
    ..listen(membersWithDevicesProvider, (_, _) => replan());
});
