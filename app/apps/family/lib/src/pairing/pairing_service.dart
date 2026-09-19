import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_data/family_data.dart';

import '../api/family_api_provider.dart';
import '../membership/membership.dart';

/// Who a scanned device will belong to.
enum NewDeviceFor {
  /// Another device of the parent doing the scanning.
  myself,

  /// A new child member, e.g. a child's phone or tablet.
  newChild,

  /// A new parent member: the other parent's phone.
  otherParent,

  /// A member already in the family, such as a child entered on day one who
  /// now has a tablet: the device joins them, and their events and colour
  /// come along (spec §9 "Invitations claim an existing member row").
  existing,
}

final pairingServiceProvider = Provider<PairingService>(
  (ref) => PairingService(ref.watch(familyApiProvider)),
);

/// Creating a family, joining one by QR code, and adding devices to it: the
/// flows of crypto doc §7 over the backend relay.
class PairingService {
  PairingService(this._api, {String? platform})
    : _platform = platform ?? (kIsWeb ? 'web' : Platform.operatingSystem);

  final FamilyApi _api;
  final String _platform;

  /// Founds a family on this device, which becomes its first parent device
  /// and holds the `all` and `adults` keys.
  Future<(Membership, Keyring)> createFamily({
    required Device device,
    required String name,
    required String timeZone,
  }) async {
    final created = await _api.createFamily(
      name: name,
      timeZone: timeZone,
      signingPublicKey: device.signingPublicKey,
      kemPublicKey: device.kemPublicKey,
      platform: _platform,
    );
    final me = device.record(deviceId: created.deviceId);
    final keyring = Keyring()
      ..generate(group: allGroup, epoch: currentEpoch)
      ..generate(group: adultsGroup, epoch: currentEpoch);

    // Stored as grants to itself; the keyring is rebuilt from these.
    for (final group in [allGroup, adultsGroup]) {
      await _grant(keyring, device, created.familyId, me.deviceId, me, group);
    }

    return (
      Membership(
        familyId: created.familyId,
        memberId: created.memberId,
        deviceId: created.deviceId,
        isParent: true,
        trusted: [me],
      ),
      keyring,
    );
  }

  /// Checks the mailbox once for an admission to [session], returning this
  /// device's new membership if one has arrived and verifies.
  Future<Membership?> checkMailbox(
    PairingSession session,
    Device device,
  ) async {
    for (final pending in await _api.collectAdmissions(session.mailbox)) {
      final Admitted admitted;
      try {
        admitted = session.accept(admission: pending.admission);
      } on CryptoException {
        // Forged or damaged: the mailbox is public, so ignore rather than fail.
        continue;
      }

      await _api.acknowledgeAdmission(
        asDevice: admitted.deviceId,
        admissionId: pending.id,
      );
      final draft = Membership(
        familyId: admitted.familyId,
        memberId: admitted.memberId,
        deviceId: admitted.deviceId,
        isParent: false,
        trusted: [
          ...admitted.trusted,
          device.record(deviceId: admitted.deviceId),
        ],
      );
      // Parents are the ones the admitter granted the `adults` key to.
      final keyring = await loadKeyring(draft, device);
      return Membership(
        familyId: draft.familyId,
        memberId: draft.memberId,
        deviceId: draft.deviceId,
        isParent: keyring.contains(group: adultsGroup, epoch: currentEpoch),
        trusted: draft.trusted,
      );
    }
    return null;
  }

  /// Rebuilds this device's keyring from the grants the server holds for it,
  /// accepting only grants signed by trusted devices.
  Future<Keyring> loadKeyring(Membership membership, Device device) async {
    final keyring = Keyring();
    for (final grant in await _api.grants(asDevice: membership.deviceId)) {
      try {
        keyring.acceptGrant(
          grant: grant,
          familyId: membership.familyId,
          me: device,
          myDevice: membership.deviceId,
          trusted: membership.trustedSigners,
        );
      } on CryptoException catch (e) {
        // One bad grant must not cost the others.
        debugPrint('Skipping a grant: ${e.kind.name} ${e.message}');
      }
    }
    return keyring;
  }

  /// Accepts grants that arrived since [keyring] was built, e.g. after
  /// another device joined a group. Returns how many new keys it now holds.
  Future<int> acceptNewGrants(
    Membership membership,
    Device device,
    Keyring keyring,
  ) async {
    var added = 0;
    for (final grant in await _api.grants(asDevice: membership.deviceId)) {
      final GrantInfo info;
      try {
        info = inspectGrant(grant: grant);
      } on CryptoException {
        continue;
      }
      if (keyring.contains(group: info.group, epoch: info.epoch)) continue;
      try {
        keyring.acceptGrant(
          grant: grant,
          familyId: membership.familyId,
          me: device,
          myDevice: membership.deviceId,
          trusted: membership.trustedSigners,
        );
        added++;
      } on CryptoException catch (e) {
        debugPrint('Skipping a grant: ${e.kind.name} ${e.message}');
      }
    }
    return added;
  }

  /// Admits the device whose pairing [code] was just scanned (crypto doc §7).
  /// Returns this device's membership, now trusting the new device too, and
  /// the member the device was registered to.
  Future<(Membership, String memberId)> addDevice({
    required Membership membership,
    required Device device,
    required Keyring keyring,
    required String code,
    required NewDeviceFor forWhom,
    Member? existing,
  }) async {
    if (forWhom == NewDeviceFor.existing && existing == null) {
      throw ArgumentError('an existing member is needed');
    }
    if (!membership.isParent) {
      throw StateError('only a parent device can add devices');
    }
    final scanned = ScannedCode.parse(code: code);
    final me = membership.deviceId;

    final memberId = switch (forWhom) {
      NewDeviceFor.myself => membership.memberId,
      NewDeviceFor.newChild => await _api.createMember(
        asDevice: me,
        role: MemberRole.child,
      ),
      NewDeviceFor.otherParent => await _api.createMember(
        asDevice: me,
        role: MemberRole.parent,
      ),
      NewDeviceFor.existing => existing!.id,
    };
    // Registered with the keys read off the new device's screen, never with
    // any the server offers.
    final newDeviceId = await _api.registerDevice(
      asDevice: me,
      memberId: memberId,
      signingPublicKey: scanned.signingKey,
      kemPublicKey: scanned.kemKey,
      platform: 'unknown',
    );
    final newDevice = scanned.record(deviceId: newDeviceId);

    // Grants first, so they are waiting when the new device reads its admission.
    final child =
        forWhom == NewDeviceFor.newChild ||
        (forWhom == NewDeviceFor.existing && existing!.isChild);
    final groups = child ? [allGroup] : [allGroup, adultsGroup];
    for (final group in groups) {
      await _grant(keyring, device, membership.familyId, me, newDevice, group);
    }

    await _api.publishEndorsement(
      asDevice: me,
      subjectDevice: newDeviceId,
      endorsement: endorse(
        endorser: device,
        endorserId: me,
        familyId: membership.familyId,
        device: newDevice,
      ),
    );

    await _api.sendAdmission(
      asDevice: me,
      toDevice: newDeviceId,
      mailbox: scanned.mailbox,
      admission: scanned.admit(
        familyId: membership.familyId,
        memberId: memberId,
        deviceId: newDeviceId,
        fromDevice: me,
        familyDevices: membership.trusted,
      ),
    );

    return (membership.withTrusted([newDevice]), memberId);
  }

  /// Learns devices added elsewhere in the family from their endorsements,
  /// following chains: a device endorsed by one just learned counts too.
  Future<Membership> refreshTrust(Membership membership) async {
    final endorsements = await _api.endorsements(asDevice: membership.deviceId);
    var current = membership;
    var learnedAny = true;
    while (learnedAny) {
      learnedAny = false;
      for (final e in endorsements) {
        final DeviceRecord learned;
        try {
          learned = verifyEndorsement(
            endorsement: e,
            familyId: current.familyId,
            trusted: current.trustedSigners,
          );
        } on CryptoException {
          continue;
        }
        if (current.trusted.every((d) => d.deviceId != learned.deviceId)) {
          current = current.withTrusted([learned]);
          learnedAny = true;
        }
      }
    }
    return current;
  }

  Future<void> _grant(
    Keyring keyring,
    Device granter,
    String familyId,
    String fromDevice,
    DeviceRecord to,
    String group,
  ) {
    final Uint8List grant = keyring.grant(
      group: group,
      epoch: currentEpoch,
      familyId: familyId,
      granter: granter,
      fromDevice: fromDevice,
      toDevice: to.deviceId,
      toKemKey: to.kemKey,
    );
    return _api.publishGrants(
      asDevice: fromDevice,
      group: group,
      epoch: currentEpoch,
      grantsByDevice: {to.deviceId: grant},
    );
  }
}
