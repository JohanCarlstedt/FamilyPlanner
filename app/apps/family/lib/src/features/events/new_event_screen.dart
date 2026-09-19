import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../reminders/reminder_notifications.dart';
import 'occurrence_editing.dart';

/// Writes a new event, or edits one, in the family's encrypted store. Saving
/// is local-first: the change shows at once and syncs in the background.
/// Editing starts from the stored payload, so fields this client doesn't know
/// about survive (crypto doc §5).
///
/// A repeating event is edited in one of three [scope]s: one occurrence (an
/// exception: time, length, title and who's responsible), this occurrence and
/// all after it (the series is split in two), or the whole series.
class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({
    super.key,
    this.eventId,
    this.at,
    this.scope = EditScope.series,
  });

  static const segment = 'new-event';

  static const editPath = '/event/:id/edit';

  static String editPathFor(
    String id, {
    EditScope scope = EditScope.series,
    DateTime? at,
  }) => Uri(
    path: '/event/$id/edit',
    queryParameters: {
      if (scope != EditScope.series) 'scope': scope.name,
      if (at != null) 'at': at.toUtc().toIso8601String(),
    },
  ).toString();

  /// The event being edited, or null for a new one.
  final String? eventId;

  /// The occurrence being edited, by its original start (a UTC instant).
  final DateTime? at;

  final EditScope scope;

  static const durations = [30, 45, 60, 75, 90, 120];

  @override
  ConsumerState<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends ConsumerState<NewEventScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  int _minutes = 60;
  final _participants = <String>{};
  String? _responsible;
  bool _weekly = false;
  bool _parentsOnly = false;

  /// Minutes before; null for no reminder.
  int? _reminder;
  bool _saving = false;
  String? _error;

  /// The stored payload when editing: the base for the rewrite.
  Payload? _existing;

  /// The series as stored, for comparing an occurrence's edits against.
  EventPayload? _series;

  /// The occurrence's stored exception, if it has one already.
  Payload? _existingException;
  bool _loading = false;

  bool get _occurrenceOnly =>
      widget.scope == EditScope.occurrence && widget.at != null;

  @override
  void initState() {
    super.initState();
    // Default to the next whole hour, in the family's zone.
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    final next = now.add(const Duration(hours: 1));
    _date = DateTime(next.year, next.month, next.day);
    _time = TimeOfDay(hour: next.hour, minute: 0);
    if (widget.eventId != null) _load(widget.eventId!);
  }

  Future<void> _load(String id) async {
    setState(() => _loading = true);
    final store = await ref.read(familyStoreProvider.future);
    final payload = await store.payloadOf(id);
    if (!mounted || payload == null) return;
    final e = EventPayload.read(payload);
    final at = widget.at;
    var start = e.localStart;
    var minutes = e.duration.inMinutes;
    var title = e.title;
    var responsible = e.responsibleMemberId;
    // Editing from one occurrence on starts at that occurrence.
    if (at != null && widget.scope != EditScope.series) {
      start = wallClock(at, e.timeZone);
    }
    Payload? exception;
    if (_occurrenceOnly) {
      exception = await store.payloadOf(EventExceptionPayload.idFor(id, at!));
      if (exception != null) {
        final x = EventExceptionPayload.read(exception);
        if (x.overrideStart case final s?) start = wallClock(s, e.timeZone);
        minutes = x.overrideDuration?.inMinutes ?? minutes;
        title = x.overrideTitle ?? title;
        responsible = x.overrideResponsibleMemberId ?? responsible;
      }
    }
    if (!mounted) return;
    setState(() {
      _existing = payload;
      _series = EventPayload.read(Payload.decode(payload.encode()));
      _existingException = exception;
      _title.text = title;
      _location.text = e.location ?? '';
      if (start != null) {
        _date = DateTime(start.year, start.month, start.day);
        _time = TimeOfDay(hour: start.hour, minute: start.minute);
      }
      _minutes = minutes;
      _participants
        ..clear()
        ..addAll(e.participantIds);
      _responsible = responsible;
      _weekly = e.rule != null;
      _reminder = e.reminders.firstOrNull?.minutesBefore;
      _parentsOnly = e.visibility == EventVisibility.parentsOnly;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = context.l10n.titleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Wall-clock, as UTC fields: never through this device's own zone.
      final start = DateTime.utc(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      final store = await ref.read(familyStoreProvider.future);
      switch (widget.scope) {
        case EditScope.occurrence when _occurrenceOnly:
          await _saveOccurrence(store, title, start);
        case EditScope.thisAndAfter when widget.at != null:
          await _saveThisAndAfter(store, title, start);
        case _:
          await store.saveEvent(
            id: widget.eventId,
            _write(existing: _existing, title: title, start: start),
          );
      }
      if (_reminder != null && !_occurrenceOnly) {
        await ReminderNotifications.requestPermission();
      }
      // Background: the event is already on screen.
      ref.read(syncControllerProvider.notifier).syncNow();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.saveEventFailed('$e');
        });
      }
    }
  }

  EventPayload _write({
    required Payload? existing,
    required String title,
    required DateTime start,
  }) => EventPayload.write(
    existing: existing,
    title: title,
    kind: _weekly ? EventKind.activity : EventKind.appointment,
    localStart: start,
    duration: Duration(minutes: _minutes),
    timeZone: _series?.timeZone ?? familyTimeZone,
    visibility: _parentsOnly
        ? EventVisibility.parentsOnly
        : EventVisibility.family,
    rule: _ruleFor(start),
    // The form edits the first reminder; any others set elsewhere are kept.
    reminders: [
      if (_reminder case final minutes?) EventReminder(minutesBefore: minutes),
      ...?_series?.reminders.skip(1),
    ],
    participantIds: _participants.toList(),
    responsibleMemberId: _responsible,
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
  );

  /// The series' rule, following the start to its new weekday. A rule this
  /// form can't show (daily, monthly, several weekdays) is kept as it is
  /// rather than flattened into "every week".
  RecurrenceRule? _ruleFor(DateTime start) {
    if (!_weekly) return null;
    final day = {Weekday.values[start.weekday - 1]};
    final rule = _series?.rule;
    if (rule == null) {
      return RecurrenceRule(frequency: Frequency.weekly, byWeekday: day);
    }
    if (!_isSimple(rule)) return rule;
    return RecurrenceRule(
      frequency: Frequency.weekly,
      interval: rule.interval,
      byWeekday: day,
      until: rule.until,
      count: rule.count,
      skip: rule.skip,
    );
  }

  static bool _isSimple(RecurrenceRule rule) =>
      rule.frequency == Frequency.weekly && rule.byWeekday.length <= 1;

  /// One occurrence: stored as an exception holding only what differs from
  /// the series.
  Future<void> _saveOccurrence(
    FamilyStore store,
    String title,
    DateTime start,
  ) async {
    final series = _series!;
    final at = widget.at!;
    final newStart = instantOf(start, series.timeZone);
    final moved = newStart != at;
    final longer = _minutes != series.duration.inMinutes;
    final retitled = title != series.title;
    final redriver = _responsible != series.responsibleMemberId;
    if (!moved &&
        !longer &&
        !retitled &&
        !redriver &&
        _existingException == null) {
      return;
    }
    await store.saveException(
      EventExceptionPayload.write(
        existing: _existingException,
        eventId: widget.eventId!,
        originalStart: at,
        type: moved ? ExceptionType.moved : ExceptionType.modified,
        overrideStart: moved ? newStart : null,
        overrideDuration: longer ? Duration(minutes: _minutes) : null,
        overrideTitle: retitled ? title : null,
        overrideResponsibleMemberId: redriver ? _responsible : null,
      ),
      visibility: series.visibility,
    );
  }

  /// This occurrence and all after it: the series ends before it and a new
  /// one starts from it, carrying the stored fields this client doesn't know.
  Future<void> _saveThisAndAfter(
    FamilyStore store,
    String title,
    DateTime start,
  ) async {
    final id = widget.eventId!;
    final at = widget.at!;
    final events = await ref.read(eventsProvider.future);
    final event = events.where((e) => e.id == id).firstOrNull;
    if (event == null || !hasOccurrenceBefore(event.series, at)) {
      // From the first occurrence on is the whole series.
      await store.saveEvent(
        id: id,
        _write(existing: _existing, title: title, start: start),
      );
      return;
    }
    final copy = Payload.decode(_existing!.encode());
    await endSeriesBefore(store, id, _existing!, at);
    await store.saveEvent(_write(existing: copy, title: title, start: start));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        // 24-hour clock (spec §5 "Swedish calendar realities").
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final parents = [
      for (final m in members)
        if (!m.isChild) m,
    ];
    final theme = Theme.of(context);
    final two = NumberFormat('00');
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventId == null
              ? l10n.newEvent
              : _occurrenceOnly
              ? l10n.editOccurrence
              : l10n.editEvent,
        ),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.eventId == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.fieldTitle,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('EEE d MMM').format(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    '${two.format(_time.hour)}:${two.format(_time.minute)}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(_minutes),
            initialValue: NewEventScreen.durations.contains(_minutes)
                ? _minutes
                : 60,
            decoration: InputDecoration(
              labelText: l10n.fieldLength,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in NewEventScreen.durations)
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    m < 60 || m % 60 != 0
                        ? l10n.durationMinutes(m)
                        : l10n.durationHours(m ~/ 60),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _minutes = v!),
          ),
          const SizedBox(height: 12),
          if (!_occurrenceOnly)
            TextField(
              controller: _location,
              decoration: InputDecoration(
                labelText: l10n.fieldWhere,
                border: OutlineInputBorder(),
              ),
            ),
          if (!_occurrenceOnly) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey('reminder-$_reminder'),
              initialValue: reminderLeads.contains(_reminder)
                  ? _reminder
                  : null,
              decoration: InputDecoration(
                labelText: l10n.fieldReminder,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final minutes in [null, ...reminderLeads])
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(describeLead(l10n, minutes)),
                  ),
              ],
              onChanged: (v) => setState(() => _reminder = v),
            ),
          ],
          if (members.isNotEmpty && !_occurrenceOnly) ...[
            const SizedBox(height: 20),
            Text(l10n.whosGoing, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, m) in members.indexed)
                  FilterChip(
                    avatar: CircleAvatar(
                      backgroundColor: MemberStyle.colorOf(m, i),
                    ),
                    label: Text(m.displayName),
                    selected: _participants.contains(m.id),
                    onSelected: (on) => setState(
                      () => on
                          ? _participants.add(m.id)
                          : _participants.remove(m.id),
                    ),
                  ),
              ],
            ),
          ],
          if (parents.isNotEmpty) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              key: ValueKey(_responsible),
              initialValue: _responsible,
              decoration: InputDecoration(
                labelText: l10n.fieldResponsible,
                border: OutlineInputBorder(),
              ),
              items: [
                // One occurrence can hand the driving to someone else, not
                // to no one: an exception only overrides.
                if (!_occurrenceOnly || _series?.responsibleMemberId == null)
                  DropdownMenuItem(value: null, child: Text(l10n.noOneYet)),
                for (final p in parents)
                  DropdownMenuItem(value: p.id, child: Text(p.displayName)),
              ],
              onChanged: (v) => setState(() => _responsible = v),
            ),
          ],
          const SizedBox(height: 12),
          if (_occurrenceOnly)
            Text(
              l10n.onlyThisOccurrence(
                DateFormat('EEEE d MMMM').format(
                  wallClock(widget.at!, _series?.timeZone ?? familyTimeZone),
                ),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.repeatsEveryWeek),
              subtitle: Text(switch (_series?.rule) {
                final rule? when !_isSimple(rule) => describeRule(l10n, rule),
                _ => l10n.everyWeekday(DateFormat('EEEE').format(_date)),
              }),
              value: _weekly,
              onChanged: (v) => setState(() => _weekly = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.parentsOnly),
              subtitle: Text(l10n.parentsOnlySubtitle),
              value: _parentsOnly,
              onChanged: (v) => setState(() => _parentsOnly = v),
            ),
          ],
        ],
      ),
    );
  }
}
