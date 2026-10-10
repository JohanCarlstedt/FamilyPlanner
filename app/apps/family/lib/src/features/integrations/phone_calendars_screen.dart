import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  Set<String> _family = const {};
  Map<String, PhoneCalendarStatus> _status = const {};
  bool? _allowed;
  var _reading = false;

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
    final family = await calendars.forFamily(prefs);
    final status = await calendars.status(prefs);
    // Calendars the phone syncs first; the rest after, marked.
    final found = allowed
        ? ((await calendars.available())
            ..sort((a, b) => (a.synced ? 0 : 1).compareTo(b.synced ? 0 : 1)))
        : <PhoneCalendar>[];
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _chosen = chosen;
      _family = family;
      _status = status;
      _calendars = found;
    });
  }

  /// Reads the chosen calendars now and says what came of it.
  Future<void> _readNow() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reading = true);
    final changed = await ref
        .read(syncControllerProvider.notifier)
        .readPhoneCalendarsNow();
    final prefs = await ref.read(devicePreferencesProvider.future);
    final status = await ref.read(phoneCalendarsProvider).status(prefs);
    if (!mounted) return;
    setState(() {
      _reading = false;
      _status = status;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.phoneCalendarsReadDone(changed))),
    );
  }

  /// Turns a family calendar on as the whole family's, in full.
  Future<void> _addForFamily(PhoneCalendar c) async {
    await _saveFamily({..._family, c.id});
    await _save({..._chosen, c.id: CalendarDetail.full});
  }

  Future<void> _howToSync() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.phoneCalendarHowToSyncTitle),
      content: Text(context.l10n.phoneCalendarHowToSync),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  );

  /// How a chosen calendar's last reading went, in a line.
  String _statusLine(AppLocalizations l10n, String id) {
    final status = _status[id];
    if (status == null) return l10n.phoneCalendarNotRead;
    final time = DateFormat('d MMM HH:mm').format(status.at.toLocal());
    if (status.error case final error?) {
      return l10n.phoneCalendarReadFailed(error);
    }
    return status.found == 0
        ? l10n.phoneCalendarReadEmpty(time)
        : l10n.phoneCalendarRead(time, status.found);
  }

  Future<void> _save(Map<String, CalendarDetail> chosen) async {
    setState(() => _chosen = chosen);
    final prefs = await ref.read(devicePreferencesProvider.future);
    final store = await ref.read(familyStoreProvider.future);
    await ref.read(phoneCalendarsProvider).choose(prefs, chosen, store: store);
    // Straight away, so the family calendar shows what was just chosen
    // rather than after the next half hour.
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  /// Whether a calendar is this phone's owner's or the whole family's,
  /// like a shared family calendar. Its events move over on the import
  /// this starts.
  Future<void> _saveFamily(Set<String> family) async {
    setState(() => _family = family);
    final prefs = await ref.read(devicePreferencesProvider.future);
    await ref.read(phoneCalendarsProvider).chooseFamily(prefs, family);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final calendars = _calendars;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.phoneCalendars),
        actions: [
          if (_chosen.isNotEmpty)
            TextButton.icon(
              onPressed: _reading ? null : _readNow,
              icon: _reading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(l10n.phoneCalendarsReadNow),
            ),
        ],
      ),
      body: switch ((_allowed, calendars)) {
        (false, _) => _Message(text: l10n.phoneCalendarsDenied),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final found) when found!.isEmpty => _Message(
          text: l10n.phoneCalendarsNone,
        ),
        (_, final found) => ListView(
          children: [
            // A family's shared calendar not yet on: said first, one tap.
            for (final c in found!)
              if (c.isFamily && !_chosen.containsKey(c.id))
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📅 ${l10n.phoneCalendarFamilyFound(c.name)}',
                          style: theme.textTheme.titleSmall,
                        ),
                        if (c.account != null)
                          Text(c.account!, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _addForFamily(c),
                          icon: const Icon(Icons.groups_outlined),
                          label: Text(l10n.phoneCalendarFamilyAdd),
                        ),
                      ],
                    ),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.phoneCalendarsHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final c in found)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: Text(c.name),
                    subtitle: c.synced
                        ? (c.account == null ? null : Text(c.account!))
                        : InkWell(
                            onTap: _howToSync,
                            child: Text(
                              [
                                ?c.account,
                                l10n.phoneCalendarNotSynced,
                              ].join('\n'),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                    value: _chosen.containsKey(c.id),
                    onChanged: (on) async {
                      // A family calendar is everyone's from the start.
                      if (on && c.isFamily) {
                        await _saveFamily({..._family, c.id});
                      }
                      await _save({
                        for (final e in _chosen.entries)
                          if (e.key != c.id) e.key: e.value,
                        // In full by default. Busy was the safer default and
                        // the wrong one: switching a calendar on and finding
                        // every entry called "Busy", with no place on it,
                        // reads as the import being broken rather than as a
                        // choice nobody was offered. Someone turning their
                        // own calendar on wants to see what is in it; the
                        // work calendar is the exception, and busy is one
                        // tap below. Changing it re-imports either way, so
                        // nothing is stuck at whatever it first arrived as.
                        if (on) c.id: CalendarDetail.full,
                      });
                    },
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
                  if (_chosen.containsKey(c.id))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _statusLine(l10n, c.id),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              _status[c.id]?.error != null ||
                                  _status[c.id]?.found == 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_chosen.containsKey(c.id))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.person_outline),
                            label: Text(l10n.phoneCalendarMine),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.groups_outlined),
                            label: Text(l10n.wholeFamily),
                          ),
                        ],
                        selected: {_family.contains(c.id)},
                        onSelectionChanged: (s) => _saveFamily(
                          s.single
                              ? {..._family, c.id}
                              : ({..._family}..remove(c.id)),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                l10n.phoneCalendarsOnePhone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
