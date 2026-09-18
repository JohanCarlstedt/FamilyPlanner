import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/clock.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';

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
  final repository = ref.watch(familyRepositoryProvider);
  final now = await ref.watch(nowProvider.future);

  final members = await repository.members();
  final events = await repository.events();
  final location = tz.getLocation(repository.timeZone);
  final localNow = tz.TZDateTime.from(now, location);

  final agenda = const DayAgendaBuilder().build(
    events: events,
    members: members,
    day: DateTime(localNow.year, localNow.month, localNow.day),
    timeZone: repository.timeZone,
    now: now,
  );

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
