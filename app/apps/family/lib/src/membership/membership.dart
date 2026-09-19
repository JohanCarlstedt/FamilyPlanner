import 'dart:convert';
import 'dart:typed_data';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/startup.dart';

/// Where this device belongs, and whom it trusts: the devices it pinned by
/// scanning or from its admission, plus those they endorsed (crypto doc §7.1).
///
/// Not secret, but stored beside the device secret, out of backup, because it
/// is meaningless without it. Group keys are not kept here: they are rebuilt
/// from the grants the server holds for this device.
class Membership {
  const Membership({
    required this.familyId,
    required this.memberId,
    required this.deviceId,
    required this.isParent,
    required this.trusted,
  });

  final String familyId;
  final String memberId;
  final String deviceId;

  /// Parents hold the `adults` key and may add devices and members.
  final bool isParent;

  /// Every device this one trusts, itself included.
  final List<DeviceRecord> trusted;

  List<TrustedDevice> get trustedSigners => [
    for (final d in trusted)
      TrustedDevice(deviceId: d.deviceId, signingKey: d.signingKey),
  ];

  Membership withTrusted(Iterable<DeviceRecord> more) {
    final byId = {for (final d in trusted) d.deviceId: d};
    for (final d in more) {
      byId.putIfAbsent(d.deviceId, () => d);
    }
    return Membership(
      familyId: familyId,
      memberId: memberId,
      deviceId: deviceId,
      isParent: isParent,
      trusted: byId.values.toList(),
    );
  }

  /// This membership without [removed] devices. Never drops this device.
  Membership withoutTrusted(Set<String> removed) => Membership(
    familyId: familyId,
    memberId: memberId,
    deviceId: deviceId,
    isParent: isParent,
    trusted: [
      for (final d in trusted)
        if (d.deviceId == deviceId || !removed.contains(d.deviceId)) d,
    ],
  );

  Map<String, Object> toJson() => {
    'v': 1,
    'familyId': familyId,
    'memberId': memberId,
    'deviceId': deviceId,
    'isParent': isParent,
    'trusted': [
      for (final d in trusted)
        {
          'deviceId': d.deviceId,
          'signingKey': base64Encode(d.signingKey),
          'kemKey': base64Encode(d.kemKey),
        },
    ],
  };

  static Membership fromJson(Map<String, dynamic> json) {
    if (json['v'] != 1) {
      throw FormatException('unknown membership version ${json['v']}');
    }
    return Membership(
      familyId: json['familyId'] as String,
      memberId: json['memberId'] as String,
      deviceId: json['deviceId'] as String,
      isParent: json['isParent'] as bool,
      trusted: [
        for (final d in json['trusted'] as List<dynamic>)
          DeviceRecord(
            deviceId: (d as Map<String, dynamic>)['deviceId'] as String,
            signingKey: base64Decode(d['signingKey'] as String),
            kemKey: base64Decode(d['kemKey'] as String),
          ),
      ],
    );
  }
}

/// Persists [Membership] in the same store as the device secret.
class MembershipStore {
  MembershipStore(this._store);

  static const _key = 'membership.v1';

  final SecretStore _store;

  Future<Membership?> load() async {
    final bytes = await _store.read(_key);
    if (bytes == null) return null;
    return Membership.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }

  Future<void> save(Membership membership) => _store.write(
    _key,
    Uint8List.fromList(utf8.encode(jsonEncode(membership.toJson()))),
  );

  Future<void> clear() => _store.delete(_key);
}

final secretStoreProvider = Provider<SecretStore>(
  (ref) => PlatformSecretStore(),
);

final deviceVaultProvider = Provider<DeviceVault>(
  (ref) => DeviceVault(store: ref.watch(secretStoreProvider)),
);

final membershipStoreProvider = Provider<MembershipStore>(
  (ref) => MembershipStore(ref.watch(secretStoreProvider)),
);

/// This device's membership, or null before it has created or joined a family.
final membershipProvider =
    AsyncNotifierProvider<MembershipController, Membership?>(
      MembershipController.new,
    );

class MembershipController extends AsyncNotifier<Membership?> {
  @override
  Future<Membership?> build() async {
    final membership = await ref.watch(membershipStoreProvider).load();
    startupMilestone('membership');
    return membership;
  }

  Future<void> save(Membership membership) async {
    await ref.read(membershipStoreProvider).save(membership);
    state = AsyncData(membership);
  }
}
