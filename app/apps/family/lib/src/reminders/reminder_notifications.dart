import 'dart:ui';

import 'package:domain/domain.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../common/l10n.dart';
import '../features/events/occurrence_editing.dart';
import 'reminder_scheduler.dart';

/// Shows what a wake stood for. The text is written here, from the decrypted
/// events: the push that woke the device carried none.
class ReminderNotifications {
  ReminderNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static var _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Asked for when there's a reason to, not at launch (spec §9).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for permission to notify (Android 13+, iOS). True if allowed.
  static Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  /// Whether notifications can be shown at all. Without it Android 13+ and
  /// iOS drop every reminder silently.
  static Future<bool> allowed() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null)
      return await android.areNotificationsEnabled() ?? false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  static Future<void> show(
    WakeContent content,
    String timeZone, {
    Map<String, String> names = const {},
  }) async {
    await _init();
    // Runs without a widget tree when a push wakes the app, so the language
    // comes from the device the same way the app picks it.
    final locale = resolveAppLocale(
      PlatformDispatcher.instance.locale,
      appLocales,
    );
    Intl.defaultLocale = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);
    final time = DateFormat('HH:mm');
    String at(DateTime instant) => time.format(wallClock(instant, timeZone));

    switch (content) {
      case DueReminders(reminders: [final one]):
        await _post(
          one.key.hashCode,
          _title(l10n, one, names),
          _line(l10n, one, at, timeZone),
          l10n,
          silent: one.silent,
        );
      case DueReminders(:final reminders):
        final lines = [
          for (final r in reminders)
            '${at(r.start)}  ${_title(l10n, r, names)}',
        ];
        await _post(
          reminders.first.key.hashCode,
          l10n.remindersTogether(reminders.length),
          lines.join(' · '),
          l10n,
          lines: lines,
          silent: reminders.every((r) => r.silent),
        );
      case Digest(:final entries):
        final lines = [
          for (final e in entries) '${at(e.start)}  ${e.event.title}',
        ];
        await _post(
          'digest'.hashCode,
          l10n.digestTitle,
          l10n.digestSummary(entries.length),
          l10n,
          lines: lines,
        );
    }
  }

  /// A child's reminder routed to an adult names the child: "Maja:
  /// Swimming".
  static String _title(
    AppLocalizations l10n,
    DueReminder r,
    Map<String, String> names,
  ) => switch (names[r.forMember]) {
    final name? => l10n.reminderForChild(name, r.event.title),
    null => r.event.title,
  };

  /// A chat message, decrypted on this device.
  static Future<void> showChat({
    required String id,
    required String? sender,
    required String text,
  }) async {
    await _init();
    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );
    await _plugin.show(
      id.hashCode & 0x7fffffff,
      sender ?? l10n.someone,
      text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat',
          l10n.chatChannel,
          channelDescription: l10n.chatChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
        ),
      ),
    );
  }

  static String _line(
    AppLocalizations l10n,
    DueReminder r,
    String Function(DateTime) at,
    String timeZone,
  ) {
    final text = switch (r.kind) {
      ReminderKind.departure => l10n.reminderLeaveNow(at(r.start)),
      ReminderKind.dayBefore => l10n.reminderTomorrow(at(r.start)),
      ReminderKind.prep when !_sameDay(r.fireAt, r.start, timeZone) =>
        l10n.reminderTomorrow(at(r.start)),
      ReminderKind.unassigned => l10n.reminderUnassigned(
        DateFormat('EEEE').format(wallClock(r.start, timeZone)),
        at(r.start),
      ),
      ReminderKind.prep ||
      ReminderKind.custom => l10n.reminderStarts(at(r.start)),
    };
    return [text, ?r.event.location].join(' · ');
  }

  static bool _sameDay(DateTime a, DateTime b, String timeZone) {
    final x = wallClock(a, timeZone);
    final y = wallClock(b, timeZone);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static Future<void> _post(
    int id,
    String title,
    String body,
    AppLocalizations l10n, {
    List<String>? lines,
    bool silent = false,
  }) => _plugin.show(
    id & 0x7fffffff,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        // Channels can't change importance once made, so quiet hours get
        // their own: no sound, no heads-up.
        silent ? 'reminders_quiet' : 'reminders',
        silent ? l10n.quietChannel : l10n.remindersChannel,
        channelDescription: l10n.remindersChannelDescription,
        importance: silent ? Importance.low : Importance.high,
        priority: silent ? Priority.low : Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: lines == null || lines.length < 2
            ? null
            : InboxStyleInformation(lines, contentTitle: title),
      ),
    ),
  );
}
