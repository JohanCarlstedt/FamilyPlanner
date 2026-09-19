import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_data/family_data.dart';

import '../common/startup.dart';
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
    final grants = await _api.grants(asDevice: membership.deviceId);
    startupMilestone('grants (${grants.length})');
    for (final grant in grants) {
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
    final directory = await _api.directory(
      asDevice: membership.deviceId,
      familyId: membership.familyId,
    );
    final revoked = {
      for (final d in directory)
        if (d.revoked && d.deviceId != membership.deviceId) d.deviceId,
    };
    final recoveryKits = {
      for (final d in directory)
        if (d.platform == 'recovery') d.deviceId,
    };
    // A retired recovery kit still vouches for what it endorsed while it was
    // live: the phone recovered with its words (crypto doc §7.3). Whoever
    // held the words could do that anyway; once retired, the kit registers
    // nothing more. So it's a stepping stone, never trusted itself.
    final steppingStones = <DeviceRecord>[
      for (final d in membership.trusted)
        if (revoked.contains(d.deviceId) && recoveryKits.contains(d.deviceId))
          d,
    ];
    var current = revoked.isEmpty
        ? membership
        : membership.withoutTrusted(revoked);
    List<TrustedDevice> signers() => [
      ...current.trustedSigners,
      for (final d in steppingStones)
        TrustedDevice(deviceId: d.deviceId, signingKey: d.signingKey),
    ];
    var learnedAny = true;
    while (learnedAny) {
      learnedAny = false;
      for (final e in endorsements) {
        final DeviceRecord learned;
        try {
          learned = verifyEndorsement(
            endorsement: e,
            familyId: current.familyId,
            trusted: signers(),
          );
        } on CryptoException {
          continue;
        }
        final id = learned.deviceId;
        final known =
            current.trusted.any((d) => d.deviceId == id) ||
            steppingStones.any((d) => d.deviceId == id);
        if (known) continue;
        if (!revoked.contains(id)) {
          current = current.withTrusted([learned]);
          learnedAny = true;
        } else if (recoveryKits.contains(id)) {
          steppingStones.add(learned);
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

  // ---- recovery kit (crypto doc §7.3) ----------------------------------------

  /// Makes a recovery kit for this device's member from [words]: registers
  /// the words' device on the member, grants it the family's keys, endorses
  /// it, and stores the sealed note. Replaces any earlier kit. Returns the
  /// membership with the kit's device trusted.
  Future<Membership> createRecoveryKit({
    required Membership membership,
    required Device device,
    required Keyring keyring,
    required String words,
  }) async {
    if (!membership.isParent) {
      throw StateError('only a parent device makes a recovery kit');
    }
    final kit = await openRecovery(words: words);
    final kitDevice = kit.device();
    final me = membership.deviceId;
    final kitId = await _api.registerDevice(
      asDevice: me,
      memberId: membership.memberId,
      signingPublicKey: kitDevice.signingPublicKey,
      kemPublicKey: kitDevice.kemPublicKey,
      platform: 'recovery',
    );
    final record = kitDevice.record(deviceId: kitId);
    for (final group in [allGroup, adultsGroup]) {
      if (keyring.latestEpoch(group: group) == null) continue;
      await _grant(keyring, device, membership.familyId, me, record, group);
    }
    await _api.publishEndorsement(
      asDevice: me,
      subjectDevice: kitId,
      endorsement: endorse(
        endorser: device,
        endorserId: me,
        familyId: membership.familyId,
        device: record,
      ),
    );
    final trusted = membership.withTrusted([record]);
    await _api.saveRecoveryKit(
      asDevice: me,
      lookupId: kit.lookupId,
      deviceId: kitId,
      note: kit.sealNote(note: _note(trusted).encode()),
    );
    return trusted;
  }

  /// The note sealed in a kit: the family, the member, and every device to
  /// trust, with both public keys.
  static Payload _note(Membership m) => Payload.create(1)
    ..setText('family', m.familyId)
    ..setText('member', m.memberId)
    ..setNestedList('trusted', [
      for (final d in m.trusted)
        Payload.map()
          ..setText('id', d.deviceId)
          ..setText('sig', base64Encode(d.signingKey))
          ..setText('kem', base64Encode(d.kemKey)),
    ]);

  /// Recovers onto [phone] from [words] (crypto doc §7.3 steps 1–3). Acting
  /// as the kit's device through [kitApi] — a client that signs with the
  /// words' key — it registers the phone on the member, grants it the keys
  /// and endorses it. Returns the phone's membership. The caller then rotates
  /// every group without the kit's device (step 4) and makes a new kit.
  Future<(Membership, String kitDeviceId)> recover({
    required String words,
    required Device phone,
    required FamilyApi Function(Device kitDevice) kitApi,
  }) async {
    final kit = await openRecovery(words: words);
    final stored = await _api.recoveryKit(kit.lookupId);
    if (stored == null) throw const RecoveryNotFound();
    final note = Payload.decode(kit.openNote(sealed: stored.note));
    final kitDevice = kit.device();
    final api = kitApi(kitDevice);
    final asKit = PairingService(api, platform: _platform);

    var kitMembership = Membership(
      familyId: stored.familyId,
      memberId: stored.memberId,
      deviceId: stored.deviceId,
      isParent: true,
      trusted: [
        for (final d in note.nestedList('trusted') ?? const <Payload>[])
          DeviceRecord(
            deviceId: d.text('id')!,
            signingKey: base64Decode(d.text('sig')!),
            kemKey: base64Decode(d.text('kem')!),
          ),
        kitDevice.record(deviceId: stored.deviceId),
      ],
    );
    // Devices added after the kit was made are learned from endorsements.
    kitMembership = await asKit.refreshTrust(kitMembership);
    final kitKeys = await asKit.loadKeyring(kitMembership, kitDevice);

    final phoneId = await api.registerDevice(
      asDevice: stored.deviceId,
      memberId: stored.memberId,
      signingPublicKey: phone.signingPublicKey,
      kemPublicKey: phone.kemPublicKey,
      platform: _platform,
    );
    final phoneRecord = phone.record(deviceId: phoneId);
    for (final group in [allGroup, adultsGroup]) {
      if (kitKeys.latestEpoch(group: group) == null) continue;
      await asKit._grant(
        kitKeys,
        kitDevice,
        stored.familyId,
        stored.deviceId,
        phoneRecord,
        group,
      );
    }
    await api.publishEndorsement(
      asDevice: stored.deviceId,
      subjectDevice: phoneId,
      endorsement: endorse(
        endorser: kitDevice,
        endorserId: stored.deviceId,
        familyId: stored.familyId,
        device: phoneRecord,
      ),
    );
    return (
      Membership(
        familyId: stored.familyId,
        memberId: stored.memberId,
        deviceId: phoneId,
        isParent: true,
        trusted: [...kitMembership.trusted, phoneRecord],
      ),
      stored.deviceId,
    );
  }
}

/// No kit answers to these words: mistyped words would have failed their
/// checksum, so these belong to a kit that was replaced, or never saved.
class RecoveryNotFound implements Exception {
  const RecoveryNotFound();
}
