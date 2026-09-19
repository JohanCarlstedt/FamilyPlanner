import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../reminders/push.dart';
import '../../reminders/reminder_notifications.dart';

/// Spec §4 `family_settings`, the parts the app uses: quiet hours, the
/// morning summary and the time it takes to get out of the door. Every
/// change saves at once and reaches every device.
class FamilySettingsScreen extends ConsumerWidget {
  const FamilySettingsScreen({super.key});

  static const segment = 'family-settings';

  static const _readyOptions = [0, 5, 10, 15, 20, 30];

  Future<void> _save(WidgetRef ref, FamilySettings settings) async {
    final store = await ref.read(familyStoreProvider.future);
    await store.saveSettings(settings);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  static String _clock(ClockMinutes m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Future<ClockMinutes?> _pick(
    BuildContext context,
    ClockMinutes initial,
    String help,
  ) async {
    final picked = await showTimePicker(
      context: context,
      helpText: help,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      builder: (context, child) => MediaQuery(
        // 24-hour clock (spec §5 "Swedish calendar realities").
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value;

    FamilySettings copy({
      ClockMinutes? quietStart,
      ClockMinutes? quietEnd,
      ClockMinutes? Function()? digestAt,
      int? prepBufferMinutes,
      MaturityTier? Function()? supervise,
    }) => FamilySettings(
      quietStart: quietStart ?? settings!.quietStart,
      quietEnd: quietEnd ?? settings!.quietEnd,
      digestAt: digestAt == null ? settings!.digestAt : digestAt(),
      prepBufferMinutes: prepBufferMinutes ?? settings!.prepBufferMinutes,
      superviseMessagesUpTo: supervise == null
          ? settings!.superviseMessagesUpTo
          : supervise(),
    );

    final supervisionLabels = <MaturityTier?, String>{
      null: l10n.supervisionOff,
      MaturityTier.little: l10n.supervisionLittle,
      MaturityTier.kid: l10n.supervisionKid,
      MaturityTier.teen: l10n.supervisionAll,
    };

    Widget help(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familySettings)),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text(l10n.quietHours),
                  subtitle: Text(
                    l10n.quietHoursRange(
                      _clock(settings.quietStart),
                      _clock(settings.quietEnd),
                    ),
                  ),
                  onTap: () async {
                    final start = await _pick(
                      context,
                      settings.quietStart,
                      l10n.quietFrom,
                    );
                    if (start == null || !context.mounted) return;
                    final end = await _pick(
                      context,
                      settings.quietEnd,
                      l10n.quietTo,
                    );
                    if (end == null) return;
                    await _save(ref, copy(quietStart: start, quietEnd: end));
                  },
                ),
                help(l10n.quietHoursHelp),
                SwitchListTile(
                  secondary: const Icon(Icons.wb_twilight_outlined),
                  title: Text(l10n.morningDigest),
                  subtitle: settings.digestAt == null
                      ? null
                      : Text(_clock(settings.digestAt!)),
                  value: settings.digestAt != null,
                  onChanged: (on) =>
                      _save(ref, copy(digestAt: () => on ? 7 * 60 : null)),
                ),
                if (settings.digestAt case final at?)
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(_clock(at)),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final picked = await _pick(
                        context,
                        at,
                        l10n.morningDigest,
                      );
                      if (picked != null) {
                        await _save(ref, copy(digestAt: () => picked));
                      }
                    },
                  ),
                help(l10n.morningDigestHelp),
                ListTile(
                  leading: const Icon(Icons.directions_run),
                  title: Text(l10n.gettingReady),
                  trailing: DropdownButton<int>(
                    value: _readyOptions.contains(settings.prepBufferMinutes)
                        ? settings.prepBufferMinutes
                        : 10,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final m in _readyOptions)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m == 0 ? l10n.parkingNone : l10n.durationMinutes(m),
                          ),
                        ),
                    ],
                    onChanged: (m) =>
                        _save(ref, copy(prepBufferMinutes: m ?? 10)),
                  ),
                ),
                help(l10n.gettingReadyHelp),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(l10n.messageSupervision),
                  subtitle: Text(
                    supervisionLabels[settings.superviseMessagesUpTo]!,
                  ),
                  onTap: () async {
                    final picked = await showDialog<(MaturityTier?,)>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(l10n.messageSupervision),
                        children: [
                          for (final MapEntry(key: tier, value: label)
                              in supervisionLabels.entries)
                            ListTile(
                              leading: Icon(
                                tier == settings.superviseMessagesUpTo
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(label),
                              onTap: () => Navigator.pop(context, (tier,)),
                            ),
                        ],
                      ),
                    );
                    if (picked == null ||
                        picked.$1 == settings.superviseMessagesUpTo ||
                        !context.mounted) {
                      return;
                    }
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(supervisionLabels[picked.$1]!),
                        content: Text(l10n.supervisionChange),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              MaterialLocalizations.of(context)
                                  .cancelButtonLabel,
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l10n.save),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) {
                      await _save(ref, copy(supervise: () => picked.$1));
                    }
                  },
                ),
                help(l10n.messageSupervisionHelp),
                if (pushSupported)
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.testReminder),
                    subtitle: Text(l10n.testReminderSubtitle),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ReminderNotifications.requestPermission();
                      final scheduler = await ref.read(
                        reminderSchedulerProvider.future,
                      );
                      await scheduler.scheduleTest(now: DateTime.now().toUtc());
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.testReminderSent)),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
