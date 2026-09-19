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

  /// Whether a new event can be started at all (a kid's becomes a request).
  bool get createEvents =>
      _parent || _tier == MaturityTier.teen || _tier == MaturityTier.kid;

  /// A kid's new event waits for a parent to approve it.
  bool get createsRequests => _tier == MaturityTier.kid;

  /// Teens and kids create events for themselves only.
  bool get createForOthers => _parent;

  /// Parents edit anything; a teen, what they created.
  bool editEvent(CalendarEvent event, {required String? createdBy}) =>
      _parent || (_tier == MaturityTier.teen && createdBy == me?.id);

  /// Parents on any event, teens on their own.
  bool setReminders(CalendarEvent? event, {required String? createdBy}) =>
      _parent ||
      (_tier == MaturityTier.teen && (event == null || createdBy == me?.id));

  bool get approveRequests => _parent;

  /// How many days ahead the calendar shows: a little one sees today and
  /// tomorrow, everyone else the week and beyond. Null: no limit.
  int? get daysVisible => _tier == MaturityTier.little ? 2 : null;
}
