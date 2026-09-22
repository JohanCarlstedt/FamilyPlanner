import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

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
      // Badge too, or the number on the icon is set and silently ignored.
      // Asked for in the same breath as the alert, because a person
      // deciding about notifications is deciding about all of it.
      return await ios.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
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
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
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
    Map<String, List<KitItem>> equipment = const {},
    String? me,
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
          _line(l10n, one, at, timeZone, bring: _bring(one, equipment, me)),
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
      case TestReminder():
        await _post(
          'test'.hashCode,
          l10n.testReminderTitle,
          l10n.testReminderBody,
          l10n,
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
      case PollClosing(:final polls):
        if (polls.isEmpty) return;
        final lines = [
          for (final p in polls) '${at(p.closesAt)}  ${p.title}',
        ];
        await _post(
          'polls'.hashCode,
          l10n.pollClosingTitle(polls.length),
          polls.length == 1
              ? l10n.pollClosingBody(polls.first.title, at(polls.first.closesAt))
              : lines.join(' · '),
          l10n,
          lines: polls.length == 1 ? null : lines,
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

  /// iOS without push: schedules what the planner says this member is owed
  /// over the week ahead as local notifications, replacing the ones pending.
  /// The text is written now, so a change made on another phone reaches
  /// this one at its next sync, not at the moment of the reminder.
  static Future<void> scheduleLocal(
    ReminderContext context, {
    required DateTime now,
  }) async {
    await _init();
    final locale = resolveAppLocale(
      PlatformDispatcher.instance.locale,
      appLocales,
    );
    Intl.defaultLocale = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);
    final time = DateFormat('HH:mm');
    String at(DateTime instant) =>
        time.format(wallClock(instant, context.timeZone));
    final names = {for (final m in context.members) m.id: m.displayName};

    final due = const ReminderPlanner().plan(
      events: context.events,
      memberId: context.memberId,
      from: now,
      until: now.add(const Duration(days: 7)),
      members: context.members,
      settings: context.settings,
      places: context.places,
      withDevices: context.withDevices,
      absences: context.absences,
      custody: context.custody,
    );
    // Pending only: cancelling everything would also clear what's shown.
    // The weekly review nudge isn't a reminder; it stays.
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id != _reviewId) await _plugin.cancel(p.id);
    }
    debugPrint('reminders: ${due.length} scheduled on this device');
    // iOS keeps at most 64 pending; the soonest matter most.
    for (final r in due.take(60)) {
      await _plugin.zonedSchedule(
        r.key.hashCode & 0x7fffffff,
        _title(l10n, r, names),
        _line(
          l10n,
          r,
          at,
          context.timeZone,
          bring: _bring(r, context.equipment, context.memberId),
        ),
        tz.TZDateTime.from(r.fireAt, tz.UTC),
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentSound: !r.silent,
            interruptionLevel: r.silent
                ? InterruptionLevel.passive
                : InterruptionLevel.timeSensitive,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
    }
  }

  static const _reviewId = 0x52455657;

  /// Sunday 18:00, every week: time for the weekly review (spec §10, "a
  /// gentle weekly nudge, not a nag"). Scheduled on the device, so it says
  /// nothing the family didn't already know.
  static Future<void> scheduleWeeklyReview(String timeZone) async {
    await _init();
    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );
    final location = tz.getLocation(timeZone);
    final now = tz.TZDateTime.now(location);
    var at = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day + (DateTime.sunday - now.weekday),
      18,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 7));
    await _plugin.zonedSchedule(
      _reviewId,
      l10n.weeklyReview,
      l10n.reviewNudgeBody,
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'review',
          l10n.weeklyReview,
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// A chat message, decrypted on this device.
  ///
  /// [unread] is everything waiting across every conversation, which
  /// becomes the number on the app icon. The same count the chat tab
  /// carries, deliberately: two places showing different numbers for the
  /// same thing is worse than one of them not showing a number at all.
  static Future<void> showChat({
    required String id,
    required String? sender,
    required String text,
    int? unread,
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
          // Launchers that show a count on the icon read this one. Those
          // that only do a dot show a dot, which is the platform's call
          // and not ours to fight.
          number: unread,
        ),
        iOS: DarwinNotificationDetails(badgeNumber: unread),
      ),
    );
  }

  /// What the reminder's reader brings (spec §3: the driver hears their
  /// own items, not the child's kit recited back): the driver at departure,
  /// whoever's going when getting ready.
  static List<String> _bring(
    DueReminder r,
    Map<String, List<KitItem>> equipment,
    String? me,
  ) {
    final items = equipment[r.event.id] ?? const <KitItem>[];
    final reader = r.forMember ?? me;
    return switch (r.kind) {
      ReminderKind.departure => [
        for (final i in items)
          if (i.forMember == reader) i.name,
      ],
      ReminderKind.prep => [
        for (final i in items)
          if (i.forMember == null || i.forMember == reader) i.name,
      ],
      _ => const [],
    };
  }

  static String _line(
    AppLocalizations l10n,
    DueReminder r,
    String Function(DateTime) at,
    String timeZone, {
    List<String> bring = const [],
  }) {
    final text = switch (r.kind) {
      ReminderKind.departure => switch (r.event.meetMinutesBefore) {
        final meet? => l10n.reminderLeaveToMeet(
          at(r.start.subtract(Duration(minutes: meet))),
        ),
        null => l10n.reminderLeaveNow(at(r.start)),
      },
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
    return [
      text,
      ?r.event.location,
      if (bring.isNotEmpty) l10n.bring(bring.join(', ')),
    ].join(' · ');
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
