import 'package:domain/domain.dart';

import '../../membership/membership.dart';
import '../../membership/permissions_provider.dart';

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
import '../places/place_editor.dart';
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

  /// Where it happens as text: the chosen place's name, or what an older
  /// event typed before places existed.
  final _location = TextEditingController();

  /// The chosen place, if any.
  String? _placeId;
  late DateTime _date;
  late TimeOfDay _time;
  int _minutes = 60;
  final _participants = <String>{};
  String? _responsible;
  bool _weekly = false;
  bool _parentsOnly = false;

  /// A rule quick capture made that the form can't show (several weekdays,
  /// an end date); used as it is while "every week" stays on.
  RecurrenceRule? _quickRule;
  final _quick = TextEditingController();

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
      _placeId = e.placeId;
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
    _quick.dispose();
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
      if (_permissions.createsRequests && widget.eventId == null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.requestSent)));
      }
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
    participantIds: _forSelfOnly ? [?_me] : _participants.toList(),
    responsibleMemberId: _forSelfOnly ? null : _responsible,
    // A kid's new event is a request until a parent approves it (spec §2).
    status: _permissions.createsRequests && widget.eventId == null
        ? EventStatus.pendingApproval
        : _series?.status == EventStatus.pendingApproval &&
              !_permissions.approveRequests
        ? EventStatus.pendingApproval
        : EventStatus.confirmed,
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    placeId: _placeId,
  );

  /// The series' rule, following the start to its new weekday. A rule this
  /// form can't show (daily, monthly, several weekdays) is kept as it is
  /// rather than flattened into "every week".
  RecurrenceRule? _ruleFor(DateTime start) {
    if (!_weekly) return null;
    if (_quickRule case final quick?) return quick;
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

  Permissions get _permissions => ref.read(permissionsProvider);

  String? get _me => ref.read(membershipProvider).value?.memberId;

  /// Teens and kids plan for themselves only (spec §2).
  bool get _forSelfOnly => !_permissions.createForOthers;

  bool get _mayRemind =>
      _permissions.setReminders(null, createdBy: _existing?.createdBy ?? _me);

  /// Spec §10 "Quick capture": a line of text fills in the form, which
  /// can then be checked and adjusted before saving.
  Future<void> _applyQuick() async {
    final text = _quick.text.trim();
    if (text.isEmpty) return;
    final places = await ref.read(placesProvider.future);
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    final q = QuickCapture.parse(
      text,
      today: DateTime.utc(now.year, now.month, now.day),
      places: [for (final p in places) p.name],
    );
    if (!mounted) return;
    final known = places
        .where((p) => p.name.toLowerCase() == q.place?.toLowerCase())
        .firstOrNull;
    setState(() {
      _title.text = q.title;
      _date = DateTime(q.localStart.year, q.localStart.month, q.localStart.day);
      if (!q.allDay) {
        _time = TimeOfDay(hour: q.localStart.hour, minute: q.localStart.minute);
      }
      if (q.duration case final d? when d.inMinutes > 0) _minutes = d.inMinutes;
      _weekly = q.rule != null;
      _quickRule = q.rule;
      if (known != null) {
        _placeId = known.id;
        _location.text = known.name;
      } else if (q.place case final place?) {
        _placeId = null;
        _location.text = place;
      }
      _quick.clear();
    });
  }

  Future<void> _choosePlace() async {
    final chosen = await pickPlace(context, ref);
    if (chosen == null || !mounted) return;
    if (chosen.isEmpty) {
      setState(() {
        _placeId = null;
        _location.clear();
      });
      return;
    }
    // A place made in the picker may not have reached the list yet.
    final places = await ref.read(placesProvider.future);
    final store = await ref.read(familyStoreProvider.future);
    final name =
        places.where((p) => p.id == chosen).firstOrNull?.name ??
        switch (await store.payloadOf(chosen)) {
          final payload? => PlacePayload.read(payload).name,
          null => '',
        };
    if (!mounted) return;
    setState(() {
      _placeId = chosen;
      _location.text = name;
    });
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
    // Spec §2: parents and helpers for anyone, a teen for a younger
    // sibling, and a child for something only theirs — "who is taking Maja
    // to football" has an honest answer when Maja walks there herself.
    final responsible = whoCanBeResponsible(
      members,
      _forSelfOnly ? [?_me] : _participants.toList(),
    );
    final theme = Theme.of(context);
    final two = NumberFormat('00');
    final l10n = context.l10n;
    // Redraw if who this member is, and so what they may do, changes.
    ref.watch(permissionsProvider);

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
          if (widget.eventId == null) ...[
            TextField(
              controller: _quick,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _applyQuick(),
              decoration: InputDecoration(
                hintText: l10n.quickCaptureHint,
                prefixIcon: const Icon(Icons.bolt),
                suffixIcon: TextButton(
                  onPressed: _applyQuick,
                  child: Text(l10n.quickCaptureFill),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _title,
            autofocus: false,
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
            initialValue: _minutes,
            decoration: InputDecoration(
              labelText: l10n.fieldLength,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in {
                ...NewEventScreen.durations,
                _minutes,
              }.toList()..sort())
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
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _choosePlace,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.fieldPlace,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                isEmpty: _location.text.isEmpty,
                child: Text(_location.text),
              ),
            ),
          if (!_occurrenceOnly && _mayRemind) ...[
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
          if (members.isNotEmpty && !_occurrenceOnly && !_forSelfOnly) ...[
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
          if (responsible.isNotEmpty && !_forSelfOnly) ...[
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
                for (final p in responsible)
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
              subtitle: Text(switch (_quickRule ?? _series?.rule) {
                final rule? when !_isSimple(rule) || rule.until != null =>
                  describeRule(l10n, rule),
                _ => l10n.everyWeekday(DateFormat('EEEE').format(_date)),
              }),
              value: _weekly,
              onChanged: (v) => setState(() => _weekly = v),
            ),
            if (!_forSelfOnly)
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
