import 'package:domain/domain.dart';

import 'homework_due.dart' show homeworkIcon;
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/l10n.dart';
import '../../common/repeat_span.dart';
import 'week_letter_screen.dart';
import '../../common/photos.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../events/occurrence_editing.dart';

final homeworkProvider = StreamProvider<List<(String, HomeworkPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchHomework();
});

/// The school week plans this family has saved, one per child at most.
final weekPlanLinksProvider =
    StreamProvider<List<(String, WeekPlanLinkPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchWeekPlanLinks();
    });

final subjectsProvider = StreamProvider<List<(String, SubjectPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchSubjects();
});

/// The subjects a homework dialog offers, and which of them is chosen.
///
/// Both halves exist because of one crash. Saving a subject and selecting
/// it in the same breath handed the dropdown an id that was not yet among
/// its items — the list comes from the store's stream, which had not
/// caught up — and Flutter asserts that a dropdown's value matches
/// exactly one item. It is not enough to fix the moment of creation:
/// anything that can empty the list under a selection does the same
/// damage, so the chosen value is filtered through what is actually
/// there, every build.
({List<(String, String)> choices, String? chosen}) subjectChoice({
  required List<(String, String)> stored,
  required (String, String)? justMade,
  required String? wanted,
}) {
  final choices = [
    ...stored,
    // Until it arrives through the store, so a subject just typed is
    // selected rather than silently dropped.
    if (justMade case final made? when !stored.any((s) => s.$1 == made.$1))
      made,
  ];
  return (
    choices: choices,
    chosen: choices.any((s) => s.$1 == wanted) ? wanted : null,
  );
}

String homeworkTypeName(AppLocalizations l10n, HomeworkType t) => switch (t) {
  HomeworkType.assignment => l10n.hwAssignment,
  HomeworkType.reading => l10n.hwReading,
  HomeworkType.test => l10n.hwTest,
  HomeworkType.project => l10n.hwProject,
  HomeworkType.handIn => l10n.hwHandIn,
};

String homeworkStateName(AppLocalizations l10n, HomeworkState s) => switch (s) {
  HomeworkState.notStarted => l10n.hwNotStarted,
  HomeworkState.inProgress => l10n.hwStarted,
  HomeworkState.done => l10n.hwDone,
  HomeworkState.handedIn => l10n.hwHandedIn,
};

/// Spec §3 "Homework": a child's due dates, and time set aside to do them.
/// Parents see every child's; a child sees their own. No grades.
class HomeworkScreen extends ConsumerWidget {
  const HomeworkScreen({super.key});

  static const segment = 'homework';

  static const path = '/more/homework';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final membership = ref.watch(membershipProvider).value;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final children = [
      for (final m in members)
        if (m.isChild &&
            ((membership?.isParent ?? false) || m.id == membership?.memberId))
          m,
    ];
    final subjects = {
      for (final (id, s)
          in ref.watch(subjectsProvider).value ??
              const <(String, SubjectPayload)>[])
        id: s.name,
    };
    final now = DateTime.now().toUtc();
    final all = [
      for (final h
          in ref.watch(homeworkProvider).value ??
              const <(String, HomeworkPayload)>[])
        if (!h.$2.finished ||
            (h.$2.dueAt?.isAfter(now.subtract(const Duration(days: 7))) ??
                false))
          h,
    ]..sort((a, b) => (a.$2.dueAt ?? now).compareTo(b.$2.dueAt ?? now));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homework),
        actions: [
          // The way homework actually arrives: the school's week plan,
          // shared, pasted or photographed. A saved one opens straight
          // into this week's; without one, the screen says what to do.
          IconButton(
            tooltip: l10n.weekLetter,
            icon: const Icon(Icons.description_outlined),
            onPressed: () {
              final saved = ref.read(weekPlanLinksProvider).value ?? const [];
              // A sibling's school is not this child's: pick the one whose
              // child is on screen, and fall back to the only one there is.
              final me = membership?.memberId;
              final mine =
                  saved
                      .where((l) => children.any((c) => c.id == l.$2.memberId))
                      .map((l) => l.$2)
                      .firstOrNull ??
                  saved
                      .where((l) => l.$2.memberId == me)
                      .map((l) => l.$2)
                      .firstOrNull;
              context.go(
                Uri(
                  path: '${HomeworkScreen.path}/${WeekLetterScreen.segment}',
                  queryParameters: mine == null ? null : {'link': mine.url},
                ).toString(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: children.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _HomeworkDialog(ref: ref, children: children),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.addHomework),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final child in children) ...[
            if (children.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  child.displayName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            if (!all.any((h) => h.$2.memberId == child.id))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.homeworkEmpty),
              ),
            for (final (id, h) in all)
              if (h.memberId == child.id)
                ListTile(
                  leading: h.payload.photos.isNotEmpty
                      ? EncryptedPhoto(h.payload.photos.first, size: 48)
                      : Icon(
                          homeworkIcon(h),
                          color: h.overdueAt(now)
                              ? theme.colorScheme.error
                              : null,
                        ),
                  title: Text(
                    [?subjects[h.subjectId], h.title].join(': '),
                    style: h.finished
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    [
                      homeworkTypeName(l10n, h.type),
                      if (h.overdueAt(now))
                        l10n.hwOverdue
                      else if (h.dueAt case final due?)
                        l10n.hwDue(
                          DateFormat('EEE d/M')
                              .format(wallClock(due, familyTimeZone)),
                        ),
                      homeworkStateName(l10n, h.state),
                      if (h.sessions.isNotEmpty)
                        l10n.hwSessions(h.sessions.length),
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<Object>(
                    onSelected: (v) async {
                      final store = await ref.read(familyStoreProvider.future);
                      if (v is HomeworkState) {
                        await store.setHomeworkState(id, v);
                      } else if (v == 'photo' && context.mounted) {
                        // Spec §3: a photo of the whiteboard is how homework
                        // actually gets entered.
                        final photo = await pickPhoto(
                          context,
                          ref,
                          groups: const [allGroup],
                        );
                        if (photo != null) {
                          await store.saveHomework(
                            HomeworkPayload.read(
                              h.payload.withPhotos([
                                ...h.payload.photos,
                                photo,
                              ]),
                            ),
                            id: id,
                          );
                        }
                      } else if (v == 'plan' && context.mounted) {
                        await planSession(context, ref, id, h);
                      } else if (v == 'delete') {
                        await store.delete(ObjectKind.homework, id);
                      }
                      ref.read(syncControllerProvider.notifier).syncNow();
                    },
                    itemBuilder: (_) => [
                      for (final s in HomeworkState.values)
                        if (s != h.state)
                          PopupMenuItem(
                            value: s,
                            child: Text(homeworkStateName(l10n, s)),
                          ),
                      if (!h.finished)
                        PopupMenuItem(value: 'plan', child: Text(l10n.hwPlan)),
                      PopupMenuItem(value: 'photo', child: Text(l10n.addPhoto)),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.removeItem),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// Offers free times before [homework] is due (spec §3: assistance, not
/// automation) and plans the one picked.
Future<void> planSession(
  BuildContext context,
  WidgetRef ref,
  String id,
  HomeworkPayload homework,
) async {
  final l10n = context.l10n;
  final due = homework.dueAt;
  if (due == null) return;
  final minutes = homework.estimatedMinutes ?? 30;
  final slots = HomeworkPlanner.freeSlots(
    events: await ref.read(eventsProvider.future),
    memberId: homework.memberId,
    now: DateTime.now().toUtc(),
    due: due,
    minutes: minutes,
    timeZone: familyTimeZone,
  );
  if (!context.mounted) return;
  final picked = await showDialog<HomeworkSlot>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.hwPlan),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slots.isEmpty ? l10n.hwNoSlots : l10n.hwPlanHint),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in slots)
                ActionChip(
                  label: Text(
                    DateFormat('EEE HH:mm')
                        .format(wallClock(s.start, familyTimeZone)),
                  ),
                  onPressed: () => Navigator.pop(context, s),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.hwSkip),
        ),
      ],
    ),
  );
  if (picked == null) return;
  final store = await ref.read(familyStoreProvider.future);
  await store.planHomeworkSession(
    id,
    localStart: wallClock(picked.start, familyTimeZone),
    minutes: minutes,
    timeZone: familyTimeZone,
  );
  ref.read(syncControllerProvider.notifier).syncNow();
}

class _HomeworkDialog extends StatefulWidget {
  const _HomeworkDialog({required this.ref, required this.children});

  final WidgetRef ref;
  final List<Member> children;

  @override
  State<_HomeworkDialog> createState() => _HomeworkDialogState();
}

class _HomeworkDialogState extends State<_HomeworkDialog> {
  final _title = TextEditingController();
  late String _child = widget.children.first.id;
  String? _subject;

  /// A subject just created, until the store's stream catches up with it.
  ///
  /// Saving one and selecting it in the same breath used to crash the
  /// dialog: the dropdown was handed an id that was not yet among its
  /// items, and Flutter asserts that a value has exactly one. It is held
  /// here so the new subject is selected the moment it is made, which is
  /// the whole point of having just typed it.
  (String, String)? _justMade;
  var _type = HomeworkType.assignment;
  var _minutes = 30;
  /// Glosor every Friday, a reading log every Monday: a standing
  /// arrangement rather than one assignment.
  var _everyWeek = false;

  /// Only asked about once [_everyWeek] is on: a single deadline has a
  /// date already, and a standing arrangement needs to know whether it
  /// ever stops. A term's glosor used to run into the summer holiday.
  RepeatSpan? _span;
  late DateTime _due = () {
    // The next school morning, 08:00.
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    var day = DateTime.utc(now.year, now.month, now.day + 1);
    while (day.weekday > DateTime.friday) {
      day = day.add(const Duration(days: 1));
    }
    return day.add(const Duration(hours: 8));
  }();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _newSubject() async {
    final l10n = context.l10n;
    final name = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.hwSubjectName),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final store = await widget.ref.read(familyStoreProvider.future);
    final name_ = text.trim();
    final id = await store.saveSubject(
      SubjectPayload.write(memberId: _child, name: name_),
    );
    setState(() {
      _justMade = (id, name_);
      _subject = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stored = [
      for (final s
          in widget.ref.watch(subjectsProvider).value ??
              const <(String, SubjectPayload)>[])
        if (s.$2.memberId == _child) (s.$1, s.$2.name),
    ];
    final (choices: subjects, chosen: selected) = subjectChoice(
      stored: stored,
      justMade: _justMade,
      wanted: _subject,
    );
    return AlertDialog(
      title: Text(l10n.addHomework),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.children.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _child,
                decoration: InputDecoration(labelText: l10n.hwWho),
                items: [
                  for (final c in widget.children)
                    DropdownMenuItem(value: c.id, child: Text(c.displayName)),
                ],
                onChanged: (c) => setState(() {
                  _child = c ?? _child;
                  _subject = null;
                }),
              ),
            DropdownButtonFormField<String?>(
              key: ValueKey('$_child/$selected/${subjects.length}'),
              initialValue: selected,
              decoration: InputDecoration(labelText: l10n.hwSubject),
              items: [
                for (final (id, name) in subjects)
                  DropdownMenuItem(value: id, child: Text(name)),
                DropdownMenuItem(value: '', child: Text(l10n.hwNewSubject)),
              ],
              onChanged: (s) {
                if (s == '') {
                  _newSubject();
                } else {
                  setState(() => _subject = s);
                }
              },
            ),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.hwTitle,
                hintText: l10n.hwTitleHint,
              ),
            ),
            DropdownButtonFormField<HomeworkType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.hwType),
              items: [
                for (final t in HomeworkType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(homeworkTypeName(l10n, t)),
                  ),
              ],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l10n.hwDue(DateFormat('EEEE d/M').format(_due))),
              onTap: () async {
                final now = DateTime.now();
                final day = await showDatePicker(
                  context: context,
                  initialDate: DateTime(_due.year, _due.month, _due.day),
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 180)),
                );
                if (day != null) {
                  setState(
                    () => _due = DateTime.utc(day.year, day.month, day.day, 8),
                  );
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.repeat),
              title: Text(l10n.hwEveryWeek),
              subtitle: Text(
                _everyWeek
                    ? l10n.hwEveryWeekOn(DateFormat('EEEE').format(_due))
                    : l10n.hwEveryWeekHelp,
              ),
              value: _everyWeek,
              onChanged: (v) => setState(() => _everyWeek = v),
            ),
            if (_everyWeek)
              RepeatSpanField(
                span: _span ??= RepeatSpan(
                  startsOn: DateTime.utc(_due.year, _due.month, _due.day),
                ),
                onChanged: (v) => setState(() => _span = v),
              ),
            DropdownButtonFormField<int>(
              initialValue: _minutes,
              decoration: InputDecoration(labelText: l10n.hwEstimate),
              items: [
                for (final m in const [15, 30, 45, 60, 90, 120])
                  DropdownMenuItem(value: m, child: Text(l10n.hwMinutes(m))),
              ],
              onChanged: (m) => setState(() => _minutes = m ?? _minutes),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            final ref = widget.ref;
            final navigator = Navigator.of(context);
            final store = await ref.read(familyStoreProvider.future);
            final me = ref.read(membershipProvider).value?.memberId;
            if (_everyWeek) {
              final span = _span;
              // An end before the start is a span with no days in it:
              // the planner would produce nothing and the person who set
              // it would see an arrangement that simply never happened.
              if (span != null && !span.isUsable) return;
              // The arrangement is saved, not the homework: it plans one
              // piece a week, each done or not on its own (domain's
              // HomeworkTemplate). Planning immediately is what makes the
              // first weeks appear in the list right away.
              await store.saveHomeworkTemplate(
                HomeworkTemplatePayload.write(
                  memberId: _child,
                  title: title,
                  subjectId: _subject,
                  type: _type,
                  estimatedMinutes: _minutes,
                  schedule: EventPayload.write(
                    title: title,
                    kind: EventKind.homework,
                    localStart: span == null
                        ? _due
                        : DateTime.utc(
                            span.startsOn.year,
                            span.startsOn.month,
                            span.startsOn.day,
                            _due.hour,
                            _due.minute,
                          ),
                    duration: Duration.zero,
                    timeZone: familyTimeZone,
                    rule: RecurrenceRule(
                      frequency: Frequency.weekly,
                      byWeekday: {Weekday.values[_due.weekday - 1]},
                      // For ever, or until a day. Never "ends, but we
                      // never said when".
                      until: span?.until,
                    ),
                  ),
                ),
              );
              await store.planHomeworkAhead();
              ref.read(syncControllerProvider.notifier).syncNow();
              navigator.pop();
              // No session picker: it asks about one deadline, and this is
              // a standing arrangement with many.
              return;
            }
            final homework = HomeworkPayload.write(
              memberId: _child,
              title: title,
              subjectId: _subject,
              type: _type,
              dueAt: instantOf(_due, familyTimeZone),
              estimatedMinutes: _minutes,
              source: me == _child ? 'child' : 'parent',
            );
            final id = await store.saveHomework(homework);
            ref.read(syncControllerProvider.notifier).syncNow();
            navigator.pop();
            // Straight on to finding a time, which can be skipped. The
            // navigator outlives this dialog; its context is the one to use.
            final host = navigator.context;
            if (host.mounted) await planSession(host, ref, id, homework);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
