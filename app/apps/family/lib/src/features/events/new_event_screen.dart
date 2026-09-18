import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';

/// Writes a new event, or edits one, in the family's encrypted store. Saving
/// is local-first: the change shows at once and syncs in the background.
/// Editing starts from the stored payload, so fields this client doesn't know
/// about survive (crypto doc §5).
class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({super.key, this.eventId});

  static const segment = 'new-event';

  static const editPath = '/event/:id/edit';

  static String editPathFor(String id) => '/event/$id/edit';

  /// The event being edited, or null for a new one.
  final String? eventId;

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
  bool _saving = false;
  String? _error;

  /// The stored payload when editing: the base for the rewrite.
  Payload? _existing;
  bool _loading = false;

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
    final start = e.localStart;
    setState(() {
      _existing = payload;
      _title.text = e.title;
      _location.text = e.location ?? '';
      if (start != null) {
        _date = DateTime(start.year, start.month, start.day);
        _time = TimeOfDay(hour: start.hour, minute: start.minute);
      }
      _minutes = e.duration.inMinutes;
      _participants
        ..clear()
        ..addAll(e.participantIds);
      _responsible = e.responsibleMemberId;
      _weekly = e.rule != null;
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
      setState(() => _error = 'Give it a title.');
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
      await store.saveEvent(
        id: widget.eventId,
        EventPayload.write(
          existing: _existing,
          title: title,
          kind: _weekly ? EventKind.activity : EventKind.appointment,
          localStart: start,
          duration: Duration(minutes: _minutes),
          timeZone: familyTimeZone,
          visibility: _parentsOnly
              ? EventVisibility.parentsOnly
              : EventVisibility.family,
          rule: _weekly
              ? RecurrenceRule(
                  frequency: Frequency.weekly,
                  byWeekday: {Weekday.values[_date.weekday - 1]},
                )
              : null,
          participantIds: _participants.toList(),
          responsibleMemberId: _responsible,
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
        ),
      );
      // Background: the event is already on screen.
      ref.read(syncControllerProvider.notifier).syncNow();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save the event.\n$e";
        });
      }
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventId == null ? 'New event' : 'Edit event'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: const Text('Save'),
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
              labelText: 'Title',
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
            decoration: const InputDecoration(
              labelText: 'Length',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in NewEventScreen.durations)
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    m < 60 || m % 60 != 0 ? '$m min' : '${m ~/ 60} h',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _minutes = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Where (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text("Who's going", style: theme.textTheme.titleSmall),
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
              decoration: const InputDecoration(
                labelText: 'Responsible / driving',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('No one yet')),
                for (final p in parents)
                  DropdownMenuItem(value: p.id, child: Text(p.displayName)),
              ],
              onChanged: (v) => setState(() => _responsible = v),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeats every week'),
            subtitle: Text('On ${DateFormat('EEEE').format(_date)}s'),
            value: _weekly,
            onChanged: (v) => setState(() => _weekly = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Parents only'),
            subtitle: const Text("Children's devices get no readable copy."),
            value: _parentsOnly,
            onChanged: (v) => setState(() => _parentsOnly = v),
          ),
        ],
      ),
    );
  }
}
