/// What a family pays for, and what it keeps when it stops
/// (docs/going-public.md "The line between them").
///
/// The list exists so that the boundary between free and premium is one
/// enum rather than a hundred scattered conditions, and so that grepping
/// for a value answers "what does premium actually cover" honestly.
///
/// Three things are deliberately absent and must never be added: export,
/// erasure, and anything protecting the family — removing a device,
/// rotating keys, the recovery kit. Charging for the ability to leave, or
/// for safety, is not a business model.
enum PaidFeature {
  /// School week plans, calendar feeds, the phone's own calendars,
  /// homework read off a letter or a photograph of the board. The hour a
  /// week this saves is the thing someone is actually buying.
  integrations,

  /// Location sharing and the family map.
  map,

  /// Recipes, the weekly menu, dinner polls, dietary conflicts.
  food,

  /// Saved passwords, family-wide or a member's own.
  passwords,

  /// The wall tablet.
  kitchenDisplay,

  /// A co-parent's limited account, custody schedules, a helper's
  /// temporary access.
  twoHomes,

  /// Photos above what the free tier holds.
  photoStorage,
}

/// Whether this family has premium, as last heard from the server.
///
/// The server is the only thing that may decide this — a client that can
/// declare itself paid is not a paywall — but the answer is cached,
/// because a phone in a tunnel must not lose the family calendar, and a
/// family that has paid must not be told otherwise by a dead network.
class Entitlement {
  const Entitlement({
    required this.until,
    required this.checkedAt,
    this.source = EntitlementSource.none,
  });

  /// Nothing, for an install that has not asked yet. Not premium, and
  /// says so through [known] so that a screen can wait rather than
  /// flashing a paywall at someone who has paid.
  const Entitlement.unknown() : until = null, checkedAt = null, source = EntitlementSource.none;

  /// When premium runs out, as the server last said. Null when this family
  /// has never had it — or, from a server that reports an open-ended
  /// grant, a date far enough away to mean the same thing.
  final DateTime? until;

  /// The server's clock at the last successful answer, not this device's.
  /// Null before any answer has arrived.
  final DateTime? checkedAt;

  final EntitlementSource source;

  /// Whether anything has been heard at all.
  bool get known => checkedAt != null;

  /// How long premium survives a server we cannot reach.
  ///
  /// A subscription renews on the day it expires. A phone that is offline
  /// across that day — a week in a cabin, a long flight, a server outage
  /// — would otherwise drop a paying family to free for no reason of
  /// theirs. Seven days is longer than any of those and far shorter than
  /// a billing cycle, so it cannot become a way to use premium for free.
  static const graceWhenOffline = Duration(days: 7);

  /// Whether premium is in force at [now].
  ///
  /// Grace applies only when we have not managed to ask since it ran out.
  /// Having asked *after* expiry and been told it is over is an answer,
  /// not silence, and gets no grace at all.
  bool isPremiumAt(DateTime now) {
    final end = until;
    if (end == null) return false;
    if (now.isBefore(end)) return true;

    final asked = checkedAt;
    if (asked == null) return false;
    if (asked.isAfter(end)) return false; // Told, not merely unheard.
    return now.isBefore(end.add(graceWhenOffline));
  }

  /// Whether [feature] may be used at [now].
  ///
  /// Every paid feature asks this, naming what it needs, so the gate is
  /// one list and the call sites read as documentation.
  bool allows(PaidFeature feature, DateTime now) => isPremiumAt(now);

  Map<String, Object?> toJson() => {
    'until': until?.toIso8601String(),
    'checkedAt': checkedAt?.toIso8601String(),
    'source': source.name,
  };

  static Entitlement fromJson(Map<String, dynamic> json) => Entitlement(
    until: DateTime.tryParse(json['until'] as String? ?? ''),
    checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
    source: EntitlementSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => EntitlementSource.none,
    ),
  );
}

/// Where premium came from. For support questions, and nothing else: no
/// feature depends on which store sold it.
enum EntitlementSource { none, appStore, playStore, granted }
