import 'electricity.dart';
import 'family.dart';

/// A time of day as minutes after midnight, in the family's zone.
typedef ClockMinutes = int;

/// Spec §4 `family_settings`: one per family. Only what the app uses so far;
/// the payload keeps whatever else a newer client writes.
class FamilySettings {
  /// When phones stay quiet: prep reminders move before it, departures
  /// arrive silently inside it (spec §8 "Quiet hours interaction").
  final ClockMinutes quietStart;
  final ClockMinutes quietEnd;

  /// The morning digest's time, or null when it's off.
  final ClockMinutes? digestAt;

  /// Coat, shoes, finding the other shoe: added before a departure.
  final int prepBufferMinutes;

  /// Spec §2 and §6 `dm_supervision_tier`: children at or below this tier
  /// have their direct and group conversations readable by the parents,
  /// and see that they are. Null: nobody's are.
  final MaturityTier? superviseMessagesUpTo;

  /// Whether the family jar and the children's worlds are switched on at
  /// all (spec section 3, "Contributions"). Off unless a parent turns it
  /// on: rewards change how a family talks about chores, and that is the
  /// family's decision to make, not a default to discover.
  final bool rewardsOn;

  /// How many finished things fill the family's jar in a week (spec
  /// section 3, "Contributions").
  final int jarSize;

  /// What a full jar means — "pizza night", "we pick the film" — in the
  /// family's own words. Null until someone says; the jar still fills.
  final String? jarFor;

  /// Where the day's electricity price in the calendar is for, or null
  /// for no price shown. Off until a parent picks: not every family pays
  /// by the hour, and a number nobody asked for is clutter.
  final PriceArea? priceArea;

  const FamilySettings({
    this.superviseMessagesUpTo = MaturityTier.kid,
    this.quietStart = 21 * 60,
    this.quietEnd = 7 * 60,
    this.digestAt = 7 * 60,
    this.prepBufferMinutes = 10,
    this.rewardsOn = false,
    this.jarSize = 10,
    this.jarFor,
    this.priceArea,
  });

  /// Everything as it is, apart from what is named.
  ///
  /// The settings screen used to build a new FamilySettings field by field,
  /// so any setting it did not know about was reset to its default on every
  /// save. Changing one thing through this keeps the rest, including
  /// settings added after the screen was written.
  FamilySettings copyWith({
    ClockMinutes? quietStart,
    ClockMinutes? quietEnd,
    ClockMinutes? Function()? digestAt,
    int? prepBufferMinutes,
    MaturityTier? Function()? superviseMessagesUpTo,
    bool? rewardsOn,
    int? jarSize,
    String? Function()? jarFor,
    PriceArea? Function()? priceArea,
  }) =>
      FamilySettings(
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        digestAt: digestAt == null ? this.digestAt : digestAt(),
        prepBufferMinutes: prepBufferMinutes ?? this.prepBufferMinutes,
        superviseMessagesUpTo: superviseMessagesUpTo == null
            ? this.superviseMessagesUpTo
            : superviseMessagesUpTo(),
        rewardsOn: rewardsOn ?? this.rewardsOn,
        jarSize: jarSize ?? this.jarSize,
        jarFor: jarFor == null ? this.jarFor : jarFor(),
        priceArea: priceArea == null ? this.priceArea : priceArea(),
      );

  static const defaults = FamilySettings();

  /// Whether [minutes] after midnight falls in quiet hours, which may run
  /// past midnight.
  bool isQuiet(ClockMinutes minutes) => quietStart <= quietEnd
      ? minutes >= quietStart && minutes < quietEnd
      : minutes >= quietStart || minutes < quietEnd;
}
