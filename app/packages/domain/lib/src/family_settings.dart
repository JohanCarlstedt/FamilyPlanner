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

  const FamilySettings({
    this.superviseMessagesUpTo = MaturityTier.kid,
    this.quietStart = 21 * 60,
    this.quietEnd = 7 * 60,
    this.digestAt = 7 * 60,
    this.prepBufferMinutes = 10,
  });

  static const defaults = FamilySettings();

  /// Whether [minutes] after midnight falls in quiet hours, which may run
  /// past midnight.
  bool isQuiet(ClockMinutes minutes) => quietStart <= quietEnd
      ? minutes >= quietStart && minutes < quietEnd
      : minutes >= quietStart || minutes < quietEnd;
}
