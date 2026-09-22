import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../events/occurrence_editing.dart' show wallClock;
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
import '../more/more_screen.dart';
import 'homework_screen.dart';

/// The homework icon, in one place.
///
/// A test used to be drawn with whatever each screen felt like, which is
/// how the same piece of homework ended up looking like two different
/// things on two screens. Every kind — a test, an assignment, reading —
/// is the same icon: what changes is the name under it, not the symbol.
IconData homeworkIcon(HomeworkPayload homework) =>
    homework.finished ? Icons.check_circle : Icons.menu_book;

/// The homework this device's member should be told about.
///
/// A child sees their own; a parent sees the children's, because the
/// person who might do something about Thursday's glosor should not be
/// the only one in the house not told about them.
List<HomeworkPayload> homeworkFor(WidgetRef ref) {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const [];
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final mine = !membership.isParent;
  final childIds = {
    for (final m in members)
      if (m.isChild && m.isActive) m.id,
  };
  return [
    for (final (_, h)
        in ref.watch(homeworkProvider).value ??
            const <(String, HomeworkPayload)>[])
      if (mine ? h.memberId == membership.memberId : childIds.contains(h.memberId))
        h,
  ];
}

/// Whatever of it is due on [date], a wall-clock day in the family's zone.
List<HomeworkPayload> homeworkDueOn(WidgetRef ref, DateTime date) {
  final due = [
    for (final h in homeworkFor(ref))
      if (h.dueAt case final at? when !h.finished)
        if (_dayOf(at) == DateTime.utc(date.year, date.month, date.day)) h,
  ]..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  return due;
}

DateTime _dayOf(DateTime instant) {
  final local = wallClock(instant, familyTimeZone);
  return DateTime.utc(local.year, local.month, local.day);
}

/// A day's homework on the week's line for that day.
///
/// The week showed the day's events and said nothing about the test on
/// it, so the one screen anybody plans a week on was the one screen that
/// did not know homework existed. Tappable, because "there is homework"
/// is not the useful part — which homework is.
class HomeworkDueLine extends ConsumerWidget {
  const HomeworkDueLine({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = homeworkDueOn(ref, date);
    if (due.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final parent = ref.watch(membershipProvider).value?.isParent ?? false;
    final labels = [
      for (final h in due)
        parent ? '${names[h.memberId] ?? ''}: ${h.title}' : h.title,
    ];

    return InkWell(
      onTap: () => showHomeworkDue(context, ref, date),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            Icon(
              homeworkIcon(due.first),
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                labels.join(' · '),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is due that day, in enough detail to decide whether tonight is
/// the night — without leaving the week to find out.
Future<void> showHomeworkDue(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) {
  final due = homeworkDueOn(ref, date);
  final l10n = context.l10n;
  final names = {
    for (final m in ref.read(membersProvider).value ?? const <Member>[])
      m.id: m.displayName,
  };
  final subjects = {
    for (final (id, s)
        in ref.read(subjectsProvider).value ??
            const <(String, SubjectPayload)>[])
      id: s.name,
  };

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.hwDueThatDay,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final h in due)
            ListTile(
              leading: Icon(homeworkIcon(h)),
              title: Text(
                [?subjects[h.subjectId], h.title].join(': '),
              ),
              subtitle: Text(
                [
                  ?names[h.memberId],
                  homeworkTypeName(l10n, h.type),
                  homeworkStateName(l10n, h.state),
                ].join(' · '),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                context.go('${MoreScreen.path}/${HomeworkScreen.segment}');
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.homework),
            ),
          ),
        ],
      ),
    ),
  );
}
