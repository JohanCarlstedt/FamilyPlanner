import 'calendar_event.dart';
import 'family.dart';

/// Spec §2's permission matrix, for what the app has so far: calendar and
/// family management. UI-enforced, not cryptographic (crypto doc §6 "Where
/// cryptography is the wrong tool"): a kid-tier device holds the same keys
/// as a teen's, and what differs is what the app offers.
class Permissions {
  const Permissions(this.me);

  /// The member using this device. Null while unknown: nothing is allowed.
  final Member? me;

  bool get _parent => me?.role == MemberRole.parent;
  MaturityTier? get _tier =>
      me?.role == MemberRole.child ? me?.tier ?? MaturityTier.kid : null;

  /// Parents only: members, devices, settings, places, recovery words.
  bool get manageFamily => _parent;

  Set<String> get _coParentOf => me?.coParentOf ?? const {};

  /// Whether a new event can be started at all (a kid's becomes a request).
  /// A co-parent starts events for the children they share.
  bool get createEvents =>
      _parent ||
      _tier == MaturityTier.teen ||
      _tier == MaturityTier.kid ||
      _coParentOf.isNotEmpty;

  /// A kid's new event waits for a parent to approve it.
  bool get createsRequests => _tier == MaturityTier.kid;

  /// Teens and kids create events for themselves only.
  bool get createForOthers => _parent;

  /// Parents edit anything; a teen, what they created.
  bool editEvent(CalendarEvent event, {required String? createdBy}) =>
      _parent ||
      (_tier == MaturityTier.teen && createdBy == me?.id) ||
      _concernsSharedChildrenOnly(event);

  /// An event only about the children a co-parent shares with this family.
  bool _concernsSharedChildrenOnly(CalendarEvent event) =>
      _coParentOf.isNotEmpty &&
      event.participantIds.isNotEmpty &&
      event.participantIds.every(_coParentOf.contains);

  /// Parents on any event, teens on their own.
  bool setReminders(CalendarEvent? event, {required String? createdBy}) =>
      _parent ||
      (_tier == MaturityTier.teen && (event == null || createdBy == me?.id));

  bool get approveRequests => _parent;

  /// Parents and teens put dinners on the menu (spec §4).
  bool get planMenu => _parent || _tier == MaturityTier.teen;

  /// Everyone in the family adds to and ticks off the shopping list.
  bool get shop => _parent || _tier != null;

  /// Spec §4 "Child dinner picks": a kid or teen chooses one dinner a week
  /// that's theirs outright; a little one's is entered by a parent.
  bool pickDinner({required Iterable<String?> chosenThisWeek}) =>
      (_tier == MaturityTier.kid || _tier == MaturityTier.teen) &&
      !chosenThisWeek.contains(me?.id);

  /// How many days ahead the calendar shows: a little one sees today and
  /// tomorrow, everyone else the week and beyond. Null: no limit.
  int? get daysVisible => _tier == MaturityTier.little ? 2 : null;
}

/// The children who haven't had their dinner pick this week.
List<Member> dinnerPicksLeft(
  List<Member> members, {
  required Iterable<String?> chosenThisWeek,
}) =>
    [
      for (final m in members)
        if (m.isChild && !chosenThisWeek.contains(m.id)) m,
    ];
