import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/clock.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';

/// The calendar's scope and member filter (spec §5). Per device and not
/// synced: two parents shouldn't fight over one view.
class CalendarView {
  const CalendarView({this.mine = false, this.members = const {}});

  /// `Mine` rather than `Family`.
  final bool mine;

  /// Members shown in the family scope; empty is everyone.
  final Set<String> members;

  CalendarFilter filterFor(String? memberId) => mine && memberId != null
      ? CalendarFilter.mine(memberId)
      : CalendarFilter.family(members: members);
}

final calendarViewProvider =
    NotifierProvider<CalendarViewController, CalendarView>(
      CalendarViewController.new,
    );

class CalendarViewController extends Notifier<CalendarView> {
  static const _preference = 'calendar.view';

  /// Set once the person changes the view, so a slow restore never
  /// overwrites what they just chose.
  var _changed = false;

  @override
  CalendarView build() {
    // Children open on Mine, parents on Family (spec §5), until this device
    // has a view of its own.
    final isParent = ref.watch(membershipProvider).value?.isParent ?? true;
    _restore();
    return CalendarView(mine: !isParent);
  }

  Future<void> _restore() async {
    final prefs = await ref.read(devicePreferencesProvider.future);
    final raw = await prefs.read(_preference);
    if (raw == null || _changed || !ref.mounted) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      state = CalendarView(
        mine: saved['mine'] == true,
        members: {...(saved['members'] as List? ?? const []).cast<String>()},
      );
    } on FormatException {
      // An unreadable preference is no preference: keep the default.
    } on TypeError {
      // Likewise one written by some other shape of this code.
    }
  }

  void _set(CalendarView view) {
    _changed = true;
    state = view;
    unawaited(() async {
      final prefs = await ref.read(devicePreferencesProvider.future);
      await prefs.write(
        _preference,
        jsonEncode({'mine': view.mine, 'members': view.members.toList()}),
      );
    }());
  }

  void setMine(bool mine) =>
      _set(CalendarView(mine: mine, members: state.members));

  /// Tap: show or hide one member.
  void toggle(String memberId) {
    final members = {...state.members};
    if (!members.remove(memberId)) members.add(memberId);
    _set(CalendarView(mine: state.mine, members: members));
  }

  /// Long press: only this member. Again: everyone.
  void only(String memberId) {
    final alreadyOnly =
        state.members.length == 1 && state.members.contains(memberId);
    _set(
      CalendarView(mine: state.mine, members: alreadyOnly ? {} : {memberId}),
    );
  }
}

/// Weeks from the current one: 0 is this week.
final weekOffsetProvider = NotifierProvider<WeekOffset, int>(WeekOffset.new);

class WeekOffset extends Notifier<int> {
  @override
  int build() => 0;

  void set(int offset) => state = offset;
}

class WeekState {
  const WeekState({
    required this.agenda,
    required this.members,
    required this.colors,
    required this.initials,
    required this.location,
    required this.now,
    required this.today,
  });

  final WeekAgenda agenda;
  final List<Member> members;
  final Map<String, Color> colors;
  final Map<String, String> initials;
  final tz.Location location;
  final DateTime now;

  /// Today's calendar date in the family's zone.
  final DateTime today;

  Map<String, Member> get byId => {for (final m in members) m.id: m};

  tz.TZDateTime local(DateTime utc) => tz.TZDateTime.from(utc, location);
}

final weekProvider = FutureProvider<WeekState>((ref) async {
  final repository = await ref.watch(familyRepositoryProvider.future);
  final now = await ref.watch(nowProvider.future);
  final members = await ref.watch(membersProvider.future);
  final events = await ref.watch(eventsProvider.future);
  final absences = await ref.watch(absencesProvider.future);
  final offset = ref.watch(weekOffsetProvider);
  final view = ref.watch(calendarViewProvider);
  final me = ref.watch(membershipProvider).value?.memberId;

  final location = tz.getLocation(repository.timeZone);
  final localNow = tz.TZDateTime.from(now, location);
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  return WeekState(
    agenda: const WeekAgendaBuilder().build(
      events: events,
      members: members,
      date: DateTime(today.year, today.month, today.day + 7 * offset),
      timeZone: repository.timeZone,
      now: now,
      filter: view.filterFor(me),
      absences: absences,
    ),
    members: members,
    colors: {
      for (final (i, m) in members.indexed) m.id: MemberStyle.colorOf(m, i),
    },
    initials: MemberStyle.initialsFor(members),
    location: location,
    now: now,
    today: today,
  );
});
