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
      ..setInteger('prepBuffer', settings.prepBufferMinutes)
      ..setText(
        'dmSupervision',
        settings.superviseMessagesUpTo?.name ?? 'none',
      )
      ..setBoolean('rewards', settings.rewardsOn)
      ..setInteger('jarSize', settings.jarSize)
      ..setText('jarFor', settings.jarFor)
      ..setText('priceArea', settings.priceArea?.name)
      ..setTexts('lunch', [
        for (final MapEntry(key: who, value: school)
            in settings.lunchSchools.entries)
          '$who=$school',
      ]);
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
      superviseMessagesUpTo: switch (payload.text('dmSupervision')) {
        'none' => null,
        final t? =>
          MaturityTier.values.asNameMap()[t] ?? d.superviseMessagesUpTo,
        null => d.superviseMessagesUpTo,
      },
      // A jar needs room for at least one thing, or it is full before
      // anyone has done anything.
      jarSize: switch (payload.integer('jarSize')) {
        final n? when n > 0 => n,
        _ => d.jarSize,
      },
      jarFor: payload.text('jarFor'),
      // Absent, or an area a later version added: no price shown.
      priceArea: PriceArea.values.asNameMap()[payload.text('priceArea')],
      // Absent means a family that has never been asked, which is off.
      rewardsOn: payload.boolean('rewards') ?? false,
      lunchSchools: {
        for (final entry in payload.texts('lunch') ?? const <String>[])
          if (entry.split('=') case [final who, final school]
              when who.isNotEmpty && school.isNotEmpty)
            who: school,
      },
    );
  }
}
