import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../events/occurrence_editing.dart' show wallClock;
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
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
List<HomeworkPayload> homeworkFor(WidgetRef ref) =>
    [for (final (_, h) in homeworkWithIdsFor(ref)) h];

/// The same, with ids.
List<(String, HomeworkPayload)> homeworkWithIdsFor(WidgetRef ref) {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const [];
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final mine = !membership.isParent;
  final childIds = {
    for (final m in members)
      if (m.isChild && m.isActive) m.id,
  };
  return [
    for (final (id, h)
        in ref.watch(homeworkProvider).value ??
            const <(String, HomeworkPayload)>[])
      if (mine ? h.memberId == membership.memberId : childIds.contains(h.memberId))
        (id, h),
  ];
}

/// Whatever of it is due on [date], a wall-clock day in the family's zone.
List<HomeworkPayload> homeworkDueOn(WidgetRef ref, DateTime date) =>
    [for (final (_, h) in homeworkDueOnWithIds(ref, date)) h];

/// The same, with the ids needed to change any of it.
List<(String, HomeworkPayload)> homeworkDueOnWithIds(
  WidgetRef ref,
  DateTime date,
) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return [
    for (final (id, h) in homeworkWithIdsFor(ref))
      if (h.dueAt case final at? when !h.finished)
        if (_dayOf(at) == day) (id, h),
  ]..sort((a, b) => a.$2.dueAt!.compareTo(b.$2.dueAt!));
}

/// Who is seeing to a piece of homework: the adult who will sit down
/// with it, chosen in one tap from wherever it is seen.
///
/// Parents and the child themselves, and "nobody" as a real choice —
/// unsaying it has to be as easy as saying it, or the list fills up with
/// people who once tapped by mistake.
Future<void> pickResponsible(
  BuildContext context,
  WidgetRef ref,
  String id,
  HomeworkPayload homework,
) async {
  final l10n = context.l10n;
  final members = ref.read(membersProvider).value ?? const <Member>[];
  final choices = [
    for (final m in members)
      if (m.isActive && m.role != MemberRole.helper) m,
  ];
  final picked = await showModalBottomSheet<String?>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.hwSetResponsible,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final m in choices)
            ListTile(
              title: Text(m.displayName),
              trailing: m.id == homework.responsibleMemberId
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(sheet, m.id),
            ),
          ListTile(
            title: Text(l10n.hwNobodyResponsible),
            trailing: homework.responsibleMemberId == null
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(sheet, _nobody),
          ),
        ],
      ),
    ),
  );
  if (picked == null) return;
  final store = await ref.read(familyStoreProvider.future);
  await store.setHomeworkResponsible(id, picked == _nobody ? null : picked);
  ref.read(syncControllerProvider.notifier).syncNow();
}

/// Told apart from "the sheet was dismissed", which is also null.
const _nobody = '\u0000nobody';

DateTime _dayOf(DateTime instant) {
  final local = wallClock(instant, familyTimeZone);
  return DateTime.utc(local.year, local.month, local.day);
}

/// One line of homework, worded like the away band beside it.
///
/// "{title} · {who}", the same shape an absence uses, because on a day's
/// line they are the same kind of thing: a small description of something
/// true about that day which is not an appointment.
String describeHomeworkDue(
  AppLocalizations l10n,
  HomeworkPayload homework,
  Map<String, String> names,
) => l10n.awayBand(homework.title, names[homework.memberId] ?? '—');

/// A day's homework on the week's line for that day.
///
/// The week showed the day's events and said nothing about the test on
/// it, so the one screen anybody plans a week on was the one screen that
/// did not know homework existed. Drawn exactly as an absence is — a
/// small icon and a short description, not a card — because it is the
/// same kind of fact about the day. Tappable, though, because "there is
/// homework" is not the useful part: which homework is.
class HomeworkDueLine extends ConsumerWidget {
  const HomeworkDueLine({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = homeworkDueOn(ref, date);
    if (due.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    // Nobody on it is the one thing here worth marking: it is a question
    // rather than information, exactly as an unassigned event is.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final h in due)
          InkWell(
            onTap: () => showHomeworkDue(context, ref, date),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Icon(
                    homeworkIcon(h),
                    size: 16,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      describeHomeworkDue(l10n, h, names),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  if (h.responsibleMemberId == null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.person_off_outlined,
                      size: 14,
                      color: theme.colorScheme.error,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
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
  final dueWithIds = homeworkDueOnWithIds(ref, date);
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
          for (final (id, h) in dueWithIds)
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
                  // Said here rather than only on the homework screen:
                  // the whole use of seeing Thursday's test on Tuesday is
                  // noticing that nobody is on it yet.
                  if (names[h.responsibleMemberId] case final who?)
                    l10n.hwResponsible(who)
                  else
                    l10n.hwNobodyResponsible,
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: l10n.hwSetResponsible,
                icon: Icon(
                  h.responsibleMemberId == null
                      ? Icons.person_add_alt
                      : Icons.person,
                  color: h.responsibleMemberId == null
                      ? Theme.of(sheet).colorScheme.error
                      : null,
                ),
                onPressed: () => pickResponsible(sheet, ref, id, h),
              ),
              // Straight to it, which is the point of seeing it here.
              onTap: () {
                Navigator.pop(sheet);
                context.go('${MoreScreen.path}/${HomeworkScreen.segment}');
              },
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
