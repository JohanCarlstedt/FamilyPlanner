import 'dart:math' as math;

import 'family.dart';
import 'family_settings.dart';
import 'place.dart';

/// A point on the earth, in degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Great-circle distance in metres.
double distanceMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Spec §7 `location_share_setting.mode`.
///
/// [always] keeps sharing when the app is closed. It needs the operating
/// system's most gated permission, and it changes what this app is: the
/// purpose strings used to promise "it never follows you in the
/// background", and that promise had to be rewritten rather than quietly
/// dropped.
///
/// What does not change is the shape of what is kept — the latest position
/// and nothing before it, cut to [SharePrecision] on the sharer's own
/// phone. "All the time" here means *where are they now*, never a history
/// of where they have been. There is nowhere for a trail to accumulate,
/// and there must never be.
enum ShareMode {
  off,
  whileUsing,
  always;

  bool get isBackground => this == ShareMode.always;
}

/// Spec §7 `visible_to`.
enum ShareAudience { parents, family }

/// Spec §7 `precision`: `placeOnly` answers "is she where she should be"
/// without a dot on a street.
enum SharePrecision { exact, approximate, placeOnly }

/// Spec §7 `location_share_setting`: one per member, chosen by the member,
/// with a floor a parent may set for a supervised child.
class LocationShare {
  const LocationShare({
    required this.memberId,
    this.mode = ShareMode.off,
    this.audience = ShareAudience.parents,
    this.precision = SharePrecision.exact,
    this.floor,
    this.pausedUntil,
  });

  final String memberId;
  final ShareMode mode;
  final ShareAudience audience;
  final SharePrecision precision;

  /// The least a parent asks of a supervised child.
  final ShareMode? floor;

  /// A visible pause (spec §7): the map says "paused", never nothing.
  final DateTime? pausedUntil;

  bool isPaused(DateTime now) => pausedUntil?.isAfter(now) ?? false;

  LocationShare copyWith({
    ShareMode? mode,
    ShareAudience? audience,
    SharePrecision? precision,
    ShareMode? Function()? floor,
    DateTime? Function()? pausedUntil,
  }) =>
      LocationShare(
        memberId: memberId,
        mode: mode ?? this.mode,
        audience: audience ?? this.audience,
        precision: precision ?? this.precision,
        floor: floor == null ? this.floor : floor(),
        pausedUntil: pausedUntil == null ? this.pausedUntil : pausedUntil(),
      );
}

/// Open question 9, answered as for messages: a child at or below the
/// family's supervised tier is under the parents' floor; above it, they
/// decide alone.
bool _supervised(Member m, FamilySettings settings) {
  final upTo = settings.superviseMessagesUpTo;
  return m.isChild &&
      upTo != null &&
      (m.tier ?? MaturityTier.little).index <= upTo.index;
}

ShareMode effectiveMode(
  Member member,
  LocationShare share,
  FamilySettings settings,
) {
  final floor = share.floor;
  if (floor == null || !_supervised(member, settings)) return share.mode;
  return share.mode.index >= floor.index ? share.mode : floor;
}

/// What a member's own screen has to be able to tell them: whether they
/// are being followed in the background, whether they chose it, and
/// whether they may turn it down.
///
/// Background sharing is never silent, for anyone, including a child who
/// cannot switch it off. Both operating systems show an indicator anyway,
/// so concealment was never really on offer — an app that looked like it
/// was trying would only teach a child to distrust it. A floor a parent
/// sets is stated as a floor a parent set.
class SharingNotice {
  const SharingNotice({
    required this.mode,
    required this.imposed,
    required this.mayChange,
  });

  final ShareMode mode;

  /// Set by a parent's floor rather than by this member.
  final bool imposed;

  /// Whether this member may lower it themselves.
  final bool mayChange;

  /// Whether the person must be told, plainly and on their own screen.
  /// True whenever anything is being shared while the app is closed.
  bool get mustBeTold => mode.isBackground;
}

SharingNotice sharingNotice(
  Member member,
  LocationShare share,
  FamilySettings settings,
) {
  final effective = effectiveMode(member, share, settings);
  final floor = share.floor;
  final under = floor != null && _supervised(member, settings);
  return SharingNotice(
    mode: effective,
    // Imposed only where the floor is actually doing the work: a child who
    // chose the same thing themselves was not made to.
    imposed: under && floor.index > share.mode.index,
    mayChange: !under || floor == ShareMode.off,
  );
}

/// A floor also means no pausing it away.
bool mayPause(Member member, LocationShare share, FamilySettings settings) =>
    share.floor == null || !_supervised(member, settings);

bool maySetFloor(Member actor, Member child, FamilySettings settings) =>
    actor.isParent && _supervised(child, settings);

/// Who sees [member] on the map: the key audience, so also who the member is
/// shown as seeing them. Helpers never.
Set<String> viewersOf(
  Member member,
  LocationShare share,
  List<Member> members, {
  FamilySettings settings = FamilySettings.defaults,
}) {
  if (effectiveMode(member, share, settings) == ShareMode.off) return {};
  return {
    for (final m in members)
      if (m.id != member.id &&
          m.isActive &&
          m.role != MemberRole.helper &&
          !m.isCoParent &&
          (share.audience == ShareAudience.family || m.isParent))
        m.id,
  };
}

/// A position as it leaves the sharer's phone: reduced to its precision
/// there, so what's encrypted is already only what viewers may know.
class SharedPosition {
  const SharedPosition({
    required this.capturedAt,
    required this.since,
    this.point,
    this.accuracyMeters,
    this.placeId,
    this.battery,
  });

  /// Null for place only.
  final GeoPoint? point;
  final double? accuracyMeters;

  /// The named place it's in, if any.
  final String? placeId;

  /// When it arrived there (or left the last place): spec §7 `place_event`,
  /// latest only, without a trail.
  final DateTime since;
  final DateTime capturedAt;

  /// Percent; "phone died" answers most "why can't I see them".
  final int? battery;
}

/// Cells about a kilometre across at Swedish latitudes.
const _latCell = 0.01;
const _lngCell = 0.02;

double _snap(double v, double cell) => ((v / cell).floor() + 0.5) * cell;

/// The place [at] is in, the nearest if several.
Place? placeAt(GeoPoint at, List<Place> places) {
  Place? best;
  var bestDistance = double.infinity;
  for (final p in places) {
    final centre = p.location;
    if (centre == null) continue;
    final d = distanceMeters(at, centre);
    if (d <= p.radiusMeters && d < bestDistance) {
      best = p;
      bestDistance = d;
    }
  }
  return best;
}

SharedPosition reducePosition({
  required GeoPoint at,
  required double accuracyMeters,
  required DateTime capturedAt,
  required SharePrecision precision,
  required List<Place> places,
  SharedPosition? previous,
  int? battery,
}) {
  final place = placeAt(at, places)?.id;
  final since = previous != null && previous.placeId == place
      ? previous.since
      : capturedAt;
  return switch (precision) {
    SharePrecision.exact => SharedPosition(
        point: at,
        accuracyMeters: accuracyMeters,
        placeId: place,
        since: since,
        capturedAt: capturedAt,
        battery: battery,
      ),
    SharePrecision.approximate => SharedPosition(
        point: GeoPoint(_snap(at.lat, _latCell), _snap(at.lng, _lngCell)),
        accuracyMeters: math.max(accuracyMeters, 1000),
        placeId: place,
        since: since,
        capturedAt: capturedAt,
        battery: battery,
      ),
    SharePrecision.placeOnly => SharedPosition(
        placeId: place,
        since: since,
        capturedAt: capturedAt,
        battery: battery,
      ),
  };
}

/// Recent enough to show as "now"; older positions show their age.
bool isFresh(DateTime capturedAt, DateTime now) =>
    now.difference(capturedAt) < const Duration(minutes: 10);
