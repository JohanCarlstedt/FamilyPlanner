import 'package:domain/domain.dart';

import 'payload.dart';

/// Schema of the family's settings (spec §4 `family_settings`): one object
/// per family, keyed by the family's id.
class SettingsPayload {
  SettingsPayload._(this.payload);

  static const version = 1;

  factory SettingsPayload.read(Payload payload) => SettingsPayload._(payload);

  factory SettingsPayload.write({
    Payload? existing,
    required FamilySettings settings,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setInteger('quietStart', settings.quietStart)
      ..setInteger('quietEnd', settings.quietEnd)
      ..setInteger('digestAt', settings.digestAt)
      ..setBoolean('digest', settings.digestAt != null)
      ..setInteger('prepBuffer', settings.prepBufferMinutes);
    return SettingsPayload._(p);
  }

  final Payload payload;

  FamilySettings toDomain() {
    const d = FamilySettings.defaults;
    int? clock(String key) => switch (payload.integer(key)) {
      final m? when m >= 0 && m < 24 * 60 => m,
      _ => null,
    };
    return FamilySettings(
      quietStart: clock('quietStart') ?? d.quietStart,
      quietEnd: clock('quietEnd') ?? d.quietEnd,
      digestAt: payload.boolean('digest') == false
          ? null
          : clock('digestAt') ?? d.digestAt,
      prepBufferMinutes: payload.integer('prepBuffer') ?? d.prepBufferMinutes,
    );
  }
}
