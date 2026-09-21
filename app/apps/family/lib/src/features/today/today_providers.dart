import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/startup.dart';

import '../../common/clock.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
import '../week/week_providers.dart';

/// Everything the Today screen renders, resolved for one instant.
class TodayState {
  const TodayState({
    required this.agenda,
    required this.members,
    required this.colors,
    required this.initials,
    required this.location,
    required this.now,
  });

  final DayAgenda agenda;
  final Map<String, Member> members;
  final Map<String, Color> colors;
  final Map<String, String> initials;

  /// The family's zone. Times are shown in it, not the device's.
  final tz.Location location;
  final DateTime now;

  tz.TZDateTime local(DateTime utc) => tz.TZDateTime.from(utc, location);

  List<Member> membersOf(Iterable<String> ids) => [
    for (final id in ids) ?members[id],
  ];
}

final todayProvider = FutureProvider<TodayState>((ref) async {
  final repository = await ref.watch(familyRepositoryProvider.future);
  final now = await ref.watch(nowProvider.future);

  final members = await ref.watch(membersProvider.future);
  final events = await ref.watch(eventsProvider.future);
  final absences = await ref.watch(absencesProvider.future);
  final location = tz.getLocation(repository.timeZone);
  final localNow = tz.TZDateTime.from(now, location);

  // The same scope the week uses (spec §5): a child's device opens on
  // their own day, a parent's on the family's. Without this, Today built
  // the whole family's day on every device — so a child's phone showed
  // their sibling's afternoon, which is not their business and is not what
  // the week screen does.
  final me = ref.watch(membershipProvider).value?.memberId;
  final filter = ref.watch(calendarViewProvider).filterFor(me);

  final agenda = const DayAgendaBuilder().build(
    events: [
      for (final e in events)
        if (filter.matches(e)) e,
    ],
    members: members,
    day: DateTime(localNow.year, localNow.month, localNow.day),
    timeZone: repository.timeZone,
    now: now,
    absences: absences,
  );

  startupMilestone('today');
  return TodayState(
    agenda: agenda,
    members: {for (final m in members) m.id: m},
    colors: {
      for (final (i, m) in members.indexed) m.id: MemberStyle.colorOf(m, i),
    },
    initials: MemberStyle.initialsFor(members),
    location: location,
    now: now,
  );
});
