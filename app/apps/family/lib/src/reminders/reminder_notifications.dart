import 'dart:ui';

import 'package:domain/domain.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../common/l10n.dart';
import '../features/events/occurrence_editing.dart';

/// Shows a reminder the device has decided it owes. The text is written here,
/// from the decrypted event: the push that woke the device carried none.
class ReminderNotifications {
  ReminderNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static var _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Asks Android 13+ for permission to notify. True if allowed.
  static Future<bool> requestPermission() async {
    await _init();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  static Future<void> show(DueReminder due) async {
    await _init();
    // Runs without a widget tree when a push wakes the app, so the language
    // comes from the device the same way the app picks it.
    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );
    final time = DateFormat('HH:mm')
        .format(wallClock(due.start, due.event.series.timeZone));
    final body = [l10n.reminderStarts(time), ?due.event.location].join(' · ');

    await _plugin.show(
      due.key.hashCode & 0x7fffffff,
      due.event.title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          l10n.remindersChannel,
          channelDescription: l10n.remindersChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
    );
  }
}
