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

  /// A helper (spec §2): a babysitter or grandparent who sees the children
  /// they cover, for a time. Their device holds only their own group's key.
  helper,

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
        isParent: keyring.latestEpoch(group: adultsGroup) != null,
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
    List<Member> members = const [],
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
      NewDeviceFor.helper => await _api.createMember(
        asDevice: me,
        role: MemberRole.helper,
      ),
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
    final isHelper =
        forWhom == NewDeviceFor.helper ||
        (forWhom == NewDeviceFor.existing &&
            existing!.role == MemberRole.helper);
    if (isHelper) {
      // Their own group: the parents and them (crypto doc §3). The family's
      // keys never reach a helper. A second device of theirs gets the key
      // they already have; only a new helper gets a new one.
      final group = helperGroup(memberId);
      final fresh = keyring.latestEpoch(group: group) == null;
      if (fresh) keyring.generate(group: group, epoch: currentEpoch);
      final directory = await _api.directory(
        asDevice: me,
        familyId: membership.familyId,
      );
      final parents = {
        membership.memberId,
        for (final m in members)
          if (m.role == MemberRole.parent) m.id,
      };
      final memberOf = {for (final d in directory) d.deviceId: d.memberId};
      for (final to in [
        if (fresh)
          for (final d in membership.trusted)
            if (parents.contains(memberOf[d.deviceId]) || d.deviceId == me) d,
        newDevice,
      ]) {
        await _grant(keyring, device, membership.familyId, me, to, group);
      }
    } else {
      final child =
          forWhom == NewDeviceFor.newChild ||
          (forWhom == NewDeviceFor.existing && !existing!.canHoldAdults);
      final groups = child ? [allGroup] : [allGroup, adultsGroup];
      for (final group in groups) {
        await _grant(
          keyring,
          device,
          membership.familyId,
          me,
          newDevice,
          group,
        );
      }
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
  /// Devices the directory lists as removed are dropped: the server can only
  /// take trust away this way, never add it.
  Future<Membership> refreshTrust(Membership membership) async {
    final endorsements = await _api.endorsements(asDevice: membership.deviceId);
    final revoked = {
      for (final d in await _api.directory(
        asDevice: membership.deviceId,
        familyId: membership.familyId,
      ))
        if (d.revoked && d.deviceId != membership.deviceId) d.deviceId,
    };
    var current = revoked.isEmpty
        ? membership
        : membership.withoutTrusted(revoked);
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
        if (!revoked.contains(learned.deviceId) &&
            current.trusted.every((d) => d.deviceId != learned.deviceId)) {
          current = current.withTrusted([learned]);
          learnedAny = true;
        }
      }
    }
    return current;
  }

  /// Removes [deviceId] from the family and rotates every group it could
  /// read (crypto doc §7, §9): the next epoch of `all`, and of `adults` if
  /// it was a parent's, granted to every remaining trusted device in the
  /// group. Revocation is forward-only: what the device already holds stays
  /// on it. The caller then rewraps recent objects to the new epochs.
  Future<Membership> removeDevice({
    required Membership membership,
    required Device device,
    required Keyring keyring,
    required String deviceId,
    required List<Member> members,
  }) => removeDevices(
    membership: membership,
    device: device,
    keyring: keyring,
    deviceIds: {deviceId},
    members: members,
  );

  /// Removes every device of [memberId] with one rotation (spec §9 "Leaving
  /// and removal"). The member's profile is the caller's to mark as ended.
  Future<Membership> removeMember({
    required Membership membership,
    required Device device,
    required Keyring keyring,
    required String memberId,
    required List<Member> members,
  }) async {
    if (memberId == membership.memberId) {
      throw StateError('a member cannot remove themselves here');
    }
    final directory = await _api.directory(
      asDevice: membership.deviceId,
      familyId: membership.familyId,
    );
    return removeDevices(
      membership: membership,
      device: device,
      keyring: keyring,
      deviceIds: {
        for (final d in directory)
          if (d.memberId == memberId && !d.revoked) d.deviceId,
      },
      members: members,
    );
  }

  Future<Membership> removeDevices({
    required Membership membership,
    required Device device,
    required Keyring keyring,
    required Set<String> deviceIds,
    required List<Member> members,
  }) async {
    if (!membership.isParent) {
      throw StateError('only a parent device can remove devices');
    }
    final me = membership.deviceId;
    final directory = await _api.directory(
      asDevice: me,
      familyId: membership.familyId,
    );
    final memberOf = {for (final d in directory) d.deviceId: d.memberId};
    final parents = {
      for (final m in members)
        if (m.role == MemberRole.parent) m.id,
    };
    final anyParent = deviceIds.any((id) => parents.contains(memberOf[id]));

    for (final id in deviceIds) {
      await _api.revokeDevice(asDevice: me, deviceId: id);
    }
    final remaining = membership.withoutTrusted({
      ...deviceIds,
      for (final d in directory)
        if (d.revoked) d.deviceId,
    });
    // A member without a device leaves nothing to rotate away from.
    if (deviceIds.isEmpty) return remaining;

    for (final group in [allGroup, if (anyParent) adultsGroup]) {
      final epoch = (keyring.latestEpoch(group: group) ?? currentEpoch) + 1;
      keyring.generate(group: group, epoch: epoch);
      final grants = <String, Uint8List>{};
      for (final to in remaining.trusted) {
        final inGroup =
            group == allGroup ||
            to.deviceId == me ||
            parents.contains(memberOf[to.deviceId]);
        if (!inGroup) continue;
        grants[to.deviceId] = keyring.grant(
          group: group,
          epoch: epoch,
          familyId: membership.familyId,
          granter: device,
          fromDevice: me,
          toDevice: to.deviceId,
          toKemKey: to.kemKey,
        );
      }
      await _api.publishGrants(
        asDevice: me,
        group: group,
        epoch: epoch,
        grantsByDevice: grants,
      );
    }
    return remaining;
  }

  Future<void> _grant(
    Keyring keyring,
    Device granter,
    String familyId,
    String fromDevice,
    DeviceRecord to,
    String group,
  ) {
    // A new device gets the current epoch only: backward secrecy (crypto doc
    // §3). Older content reaches it as it's rewrapped.
    final epoch = keyring.latestEpoch(group: group) ?? currentEpoch;
    final Uint8List grant = keyring.grant(
      group: group,
      epoch: epoch,
      familyId: familyId,
      granter: granter,
      fromDevice: fromDevice,
      toDevice: to.deviceId,
      toKemKey: to.kemKey,
    );
    return _api.publishGrants(
      asDevice: fromDevice,
      group: group,
      epoch: epoch,
      grantsByDevice: {to.deviceId: grant},
    );
  }

  /// Winds up every helper whose time is up (spec §2: a babysitter granted
  /// Saturday evening loses it on Sunday without anyone remembering to
  /// revoke it): their devices are revoked, the grant is marked ended, and
  /// nothing new is wrapped for them. Any parent device may do it; doing it
  /// twice does no harm. Returns how many it wound up.
  Future<int> expireHelpers({
    required Membership membership,
    required FamilyStore store,
  }) async {
    if (!membership.isParent) return 0;
    final now = DateTime.now().toUtc();
    final due = [
      for (final (id, g) in await store.watchHelperGrants().first)
        if (g.endedAt == null && !(g.until?.isAfter(now) ?? true)) (id, g),
    ];
    if (due.isEmpty) return 0;
    final directory = await _api.directory(
      asDevice: membership.deviceId,
      familyId: membership.familyId,
    );
    for (final (id, g) in due) {
      for (final d in directory) {
        if (d.memberId == g.helperMemberId && !d.revoked) {
          await _api.revokeDevice(
            asDevice: membership.deviceId,
            deviceId: d.deviceId,
          );
        }
      }
      await store.saveHelperGrant(
        HelperGrantPayload.write(
          existing: g.payload,
          helperMemberId: g.helperMemberId,
          childIds: g.childIds,
          until: g.until!,
          endedAt: now,
        ),
        id: id,
      );
    }
    return due.length;
  }
}
