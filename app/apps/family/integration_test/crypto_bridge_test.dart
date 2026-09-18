// Runs on a device: proves the Rust crypto core loads through the FFI bridge
// and behaves the same there as in its own cargo tests.
//
//   flutter test integration_test --flavor dev -d <device>

import 'dart:convert';
import 'dart:typed_data';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'crypto_vectors.dart' as vectors;

Uint8List _unhex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

const _family = 'fam-1';
const _event = ObjectSlot(objectType: 'event', id: 'e1', familyId: _family);
const _all = Audience(group: 'all', epoch: 0);
const _adults = Audience(group: 'adults', epoch: 0);

Matcher _throwsKind(CryptoErrorKind kind) =>
    throwsA(isA<CryptoException>().having((e) => e.kind, 'kind', kind));

/// A device with its id and the group keys it holds.
class _Member {
  _Member(this.id) : device = Device.generate(), keyring = Keyring();

  final String id;
  final Device device;
  final Keyring keyring;

  TrustedDevice get trusted =>
      TrustedDevice(deviceId: id, signingKey: device.signingPublicKey);

  /// Grants a key this member holds to [to].
  Uint8List grantTo(_Member to, Audience audience) => keyring.grant(
    group: audience.group,
    epoch: audience.epoch,
    familyId: _family,
    granter: device,
    fromDevice: id,
    toDevice: to.id,
    toKemKey: to.device.kemPublicKey,
  );

  Audience accept(Uint8List grant, List<_Member> trusted) =>
      keyring.acceptGrant(
        grant: grant,
        familyId: _family,
        me: device,
        myDevice: id,
        trusted: [for (final m in trusted) m.trusted],
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => RustLib.init());

  group('envelopes', () {
    test('seal and open through the bridge', () {
      final parent = _Member('parent')
        ..keyring.generate(group: 'all', epoch: 0);

      final sealed = seal(
        payload: utf8.encode('Football, Tuesdays 17:30'),
        object: _event,
        audiences: const [_all],
        keyring: parent.keyring,
      );
      final opened = open(envelope: sealed, keyring: parent.keyring);

      expect(utf8.decode(opened.payload), 'Football, Tuesdays 17:30');
      expect(opened.header.object.id, 'e1');
    });

    test('rewrap narrows visibility without re-encrypting', () {
      final parent = _Member('parent')
        ..keyring.generate(group: 'all', epoch: 0)
        ..keyring.generate(group: 'adults', epoch: 0);
      final sealed = seal(
        payload: utf8.encode('surprise party'),
        object: _event,
        audiences: const [_all],
        keyring: parent.keyring,
      );

      final narrowed = rewrap(
        envelope: sealed,
        audiences: const [_adults],
        keyring: parent.keyring,
      );

      expect(inspect(envelope: narrowed).audiences, const [_adults]);
    });

    test('a flipped byte is reported as tampering', () {
      final parent = _Member('parent')
        ..keyring.generate(group: 'all', epoch: 0);
      final sealed = seal(
        payload: utf8.encode('x'),
        object: _event,
        audiences: const [_all],
        keyring: parent.keyring,
      );
      final damaged = Uint8List.fromList(sealed)..last ^= 0x01;

      expect(
        () => open(envelope: damaged, keyring: parent.keyring),
        _throwsKind(CryptoErrorKind.tampered),
      );
    });
  });

  group('grants', () {
    test('a child receives `all` but can still not read parents-only', () {
      final parent = _Member('parent')
        ..keyring.generate(group: 'all', epoch: 0)
        ..keyring.generate(group: 'adults', epoch: 0);
      final child = _Member('child');

      final received = child.accept(parent.grantTo(child, _all), [parent]);
      expect(received, _all);

      final family = seal(
        payload: utf8.encode('Dinner at 18:00'),
        object: _event,
        audiences: const [_all],
        keyring: parent.keyring,
      );
      final parentsOnly = seal(
        payload: utf8.encode('gift ideas'),
        object: const ObjectSlot(
          objectType: 'event',
          id: 'e2',
          familyId: _family,
        ),
        audiences: const [_adults],
        keyring: parent.keyring,
      );

      expect(
        utf8.decode(open(envelope: family, keyring: child.keyring).payload),
        'Dinner at 18:00',
      );
      expect(
        () => open(envelope: parentsOnly, keyring: child.keyring),
        _throwsKind(CryptoErrorKind.noAccess),
      );
    });

    test('a key planted by an untrusted device is refused', () {
      final serverMade = _Member('server-made')
        ..keyring.generate(group: 'all', epoch: 0);
      final parent = _Member('parent');
      final child = _Member('child');

      expect(
        () => child.accept(serverMade.grantTo(child, _all), [parent]),
        _throwsKind(CryptoErrorKind.untrustedSender),
      );
    });

    test('a keyring rebuilds from grants to itself after a restart', () {
      final phone = _Member('phone')
        ..keyring.generate(group: 'adults', epoch: 0);
      final stored = phone.grantTo(phone, _adults);
      final sealed = seal(
        payload: utf8.encode('kept'),
        object: _event,
        audiences: const [_adults],
        keyring: phone.keyring,
      );

      // Simulate a restart: the identity comes back from its stored secret,
      // the keyring from the stored self-grant.
      final restored = Device.restore(secret: phone.device.exportSecret());
      final rebuilt = Keyring()
        ..acceptGrant(
          grant: stored,
          familyId: _family,
          me: restored,
          myDevice: 'phone',
          trusted: [phone.trusted],
        );

      expect(
        utf8.decode(open(envelope: sealed, keyring: rebuilt).payload),
        'kept',
      );
    });
  });

  group('pairing', () {
    test('a tablet joins by QR code and receives the family key', () {
      final parent = _Member('parent')
        ..keyring.generate(group: 'all', epoch: 0);
      final tabletDevice = Device.generate();

      // The tablet belongs to nothing yet: its code holds only keys and a secret.
      final session = PairingSession.start(device: tabletDevice);
      final scanned = ScannedCode.parse(code: session.code);
      expect(scanned.signingKey, tabletDevice.signingPublicKey);
      expect(scanned.kemKey, tabletDevice.kemPublicKey);
      expect(scanned.mailbox, session.mailbox);

      // The parent registers it (the server assigns this id) and admits it.
      const tabletId = 'dev-tablet';
      final admission = scanned.admit(
        familyId: _family,
        memberId: 'member-maja',
        deviceId: tabletId,
        fromDevice: parent.id,
        familyDevices: [parent.device.record(deviceId: parent.id)],
      );
      final grant = parent.keyring.grant(
        group: 'all',
        epoch: 0,
        familyId: _family,
        granter: parent.device,
        fromDevice: parent.id,
        toDevice: tabletId,
        toKemKey: scanned.kemKey,
      );

      final admitted = session.accept(admission: admission);
      expect(admitted.familyId, _family);
      expect(admitted.memberId, 'member-maja');
      expect(admitted.deviceId, tabletId);
      expect(admitted.trusted.single.deviceId, parent.id);

      final tabletKeys = Keyring()
        ..acceptGrant(
          grant: grant,
          familyId: admitted.familyId,
          me: tabletDevice,
          myDevice: admitted.deviceId,
          trusted: [
            for (final d in admitted.trusted)
              TrustedDevice(deviceId: d.deviceId, signingKey: d.signingKey),
          ],
        );

      final sealed = seal(
        payload: utf8.encode('Dinner 18:00'),
        object: _event,
        audiences: const [_all],
        keyring: parent.keyring,
      );
      expect(
        utf8.decode(open(envelope: sealed, keyring: tabletKeys).payload),
        'Dinner 18:00',
      );
    });

    test('an admission from someone who never saw the code is refused', () {
      final session = PairingSession.start(device: Device.generate());
      // The server knows the tablet's public keys, but any code it makes up
      // carries a different secret.
      final serverMade = _Member('server-made');
      final forged =
          ScannedCode.parse(
            code: PairingSession.start(device: Device.generate()).code,
          ).admit(
            familyId: 'its-family',
            memberId: 'm',
            deviceId: 'dev-tablet',
            fromDevice: serverMade.id,
            familyDevices: [serverMade.device.record(deviceId: serverMade.id)],
          );

      expect(
        () => session.accept(admission: forged),
        _throwsKind(CryptoErrorKind.tampered),
      );
    });
  });

  test('the worked examples of crypto doc §2.1, §3.1, §4.1 and §7.1', () {
    // Same bytes as rust/test-vectors, chained: the tablet's pinned pairing
    // code carries its real keys, the parent's endorsement of it verifies, the
    // tablet restored from its pinned secret accepts the pinned grant, and the
    // key that grant delivers opens the pinned envelope.
    final recipient = Device.restore(secret: _unhex(vectors.recipientSecret));
    final parentKey = TrustedDevice(
      deviceId: vectors.grantFrom,
      signingKey: _unhex(vectors.granterSigningPublic),
    );

    final scanned = ScannedCode.parse(code: vectors.pairingCode);
    expect(scanned.signingKey, recipient.signingPublicKey);
    expect(scanned.kemKey, recipient.kemPublicKey);
    expect(scanned.mailbox, vectors.pairingMailbox);
    final endorsed = verifyEndorsement(
      endorsement: _unhex(vectors.endorsement),
      familyId: vectors.grantFamily,
      trusted: [parentKey],
    );
    expect(endorsed.deviceId, vectors.grantTo);

    final keyring = Keyring();

    final received = keyring.acceptGrant(
      grant: _unhex(vectors.grant),
      familyId: vectors.grantFamily,
      me: recipient,
      myDevice: vectors.grantTo,
      trusted: [parentKey],
    );
    expect(received, _all);

    final opened = open(envelope: _unhex(vectors.envelope), keyring: keyring);
    expect(opened.payload, _unhex(vectors.envelopePayload));
  });
}
