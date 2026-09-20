import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import '../../integrations/phone_calendars.dart';

/// Which of this phone's own calendars the family sees.
///
/// Per device on purpose: these are the accounts signed in on this phone,
/// and another family member's phone has its own. Nothing here is synced —
/// only the events the choice brings in.
class PhoneCalendarsScreen extends ConsumerStatefulWidget {
  const PhoneCalendarsScreen({super.key});

  static const segment = 'phone-calendars';

  @override
  ConsumerState<PhoneCalendarsScreen> createState() =>
      _PhoneCalendarsScreenState();
}

class _PhoneCalendarsScreenState extends ConsumerState<PhoneCalendarsScreen> {
  List<PhoneCalendar>? _calendars;
  Map<String, CalendarDetail> _chosen = const {};
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final calendars = ref.read(phoneCalendarsProvider);
    final allowed = await calendars.ask();
    final prefs = await ref.read(devicePreferencesProvider.future);
    final chosen = await calendars.chosen(prefs);
    final found = allowed ? await calendars.available() : <PhoneCalendar>[];
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _chosen = chosen;
      _calendars = found;
    });
  }

  Future<void> _save(Map<String, CalendarDetail> chosen) async {
    setState(() => _chosen = chosen);
    final prefs = await ref.read(devicePreferencesProvider.future);
    await ref.read(phoneCalendarsProvider).choose(prefs, chosen);
    // Straight away, so the family calendar shows what was just chosen
    // rather than after the next half hour.
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final calendars = _calendars;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.phoneCalendars)),
      body: switch ((_allowed, calendars)) {
        (false, _) => _Message(text: l10n.phoneCalendarsDenied),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final found) when found!.isEmpty => _Message(
          text: l10n.phoneCalendarsNone,
        ),
        (_, final found) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.phoneCalendarsHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final c in found!)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: Text(c.name),
                    subtitle: c.account == null ? null : Text(c.account!),
                    value: _chosen.containsKey(c.id),
                    onChanged: (on) => _save({
                      for (final e in _chosen.entries)
                        if (e.key != c.id) e.key: e.value,
                      // Busy by default: the safer of the two, and the one
                      // most people want for a work calendar.
                      if (on) c.id: CalendarDetail.busy,
                    }),
                  ),
                  if (_chosen[c.id] case final detail?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SegmentedButton<CalendarDetail>(
                        segments: [
                          ButtonSegment(
                            value: CalendarDetail.busy,
                            label: Text(l10n.phoneCalendarBusy),
                          ),
                          ButtonSegment(
                            value: CalendarDetail.full,
                            label: Text(l10n.phoneCalendarFull),
                          ),
                        ],
                        selected: {detail},
                        onSelectionChanged: (s) =>
                            _save({..._chosen, c.id: s.single}),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.phoneCalendarsPrivacy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
