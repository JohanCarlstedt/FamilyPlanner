// Runs on a device: proves the Rust crypto core loads through the FFI bridge
// and behaves the same there as in its own cargo tests.
//
//   flutter test integration_test --flavor dev -d <device>

import 'dart:convert';
import 'dart:typed_data';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Uint8List _unhex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

const _event = ObjectSlot(objectType: 'event', id: 'e1', familyId: 'fam-1');

Matcher _throwsKind(EnvelopeErrorKind kind) => throwsA(
  isA<EnvelopeError>().having((e) => e.kind, 'kind', kind),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => RustLib.init());

  test('seals and opens through the bridge', () {
    final keyring = Keyring()..generate(group: 'all', epoch: 0);
    final payload = utf8.encode('Football, Tuesdays 17:30');

    final envelope = seal(
      payload: payload,
      object: _event,
      audiences: const [Audience(group: 'all', epoch: 0)],
      keyring: keyring,
    );
    final opened = open(envelope: envelope, keyring: keyring);

    expect(utf8.decode(opened.payload), 'Football, Tuesdays 17:30');
    expect(opened.header.object.id, 'e1');
  });

  test('a parents-only object is closed to a child device', () {
    final parent = Keyring()
      ..generate(group: 'all', epoch: 0)
      ..generate(group: 'adults', epoch: 0);
    final child = Keyring()
      ..importKey(
        group: 'all',
        epoch: 0,
        key: parent.exportKey(group: 'all', epoch: 0),
      );

    final envelope = seal(
      payload: utf8.encode('gift ideas'),
      object: _event,
      audiences: const [Audience(group: 'adults', epoch: 0)],
      keyring: parent,
    );

    expect(
      () => open(envelope: envelope, keyring: child),
      _throwsKind(EnvelopeErrorKind.noAccess),
    );
  });

  test('rewrap narrows visibility without re-encrypting', () {
    final parent = Keyring()
      ..generate(group: 'all', epoch: 0)
      ..generate(group: 'adults', epoch: 0);
    final envelope = seal(
      payload: utf8.encode('surprise party'),
      object: _event,
      audiences: const [Audience(group: 'all', epoch: 0)],
      keyring: parent,
    );

    final narrowed = rewrap(
      envelope: envelope,
      audiences: const [Audience(group: 'adults', epoch: 0)],
      keyring: parent,
    );

    expect(inspect(envelope: narrowed).audiences, const [
      Audience(group: 'adults', epoch: 0),
    ]);
    expect(
      utf8.decode(open(envelope: narrowed, keyring: parent).payload),
      'surprise party',
    );
  });

  test('a flipped byte is reported as tampering', () {
    final keyring = Keyring()..generate(group: 'all', epoch: 0);
    final envelope = seal(
      payload: utf8.encode('x'),
      object: _event,
      audiences: const [Audience(group: 'all', epoch: 0)],
      keyring: keyring,
    );
    final damaged = Uint8List.fromList(envelope)..last ^= 0x01;

    expect(
      () => open(envelope: damaged, keyring: keyring),
      _throwsKind(EnvelopeErrorKind.tampered),
    );
  });

  test('sealing to a key the keyring lacks is refused', () {
    expect(
      () => seal(
        payload: utf8.encode('x'),
        object: _event,
        audiences: const [Audience(group: 'adults', epoch: 0)],
        keyring: Keyring(),
      ),
      _throwsKind(EnvelopeErrorKind.missingKey),
    );
  });

  test('opens the worked example from crypto design doc §4.1', () {
    // Same bytes as rust/test-vectors/envelope-v1.json: proves the format is
    // identical on this device's architecture.
    final keyring = Keyring()
      ..importKey(
        group: 'all',
        epoch: 0,
        key: _unhex(
          'a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebf',
        ),
      );
    final envelope = _unhex(
      'a6616e5818202122232425262728292a2b2c2d2e2f303132333435363761760162'
      '6374582dbf3b3dbd7a5260e24cd235cc0e286ea55f34bd50ffe774d4880f354768'
      '1e34c7fdd13f3d78f0e12d2e7af35a6b63616164a36174656576656e7462696468'
      '6576742d303030316366616d6866616d2d3030303163616c67016364656b81a361'
      '6500616763616c6c6177584838393a3b3c3d3e3f404142434445464748494a4b4c'
      '4d4e4fd5844cb082680421d80ada8874b4ed110fc2459c35e8cba0dcdbf1350508'
      '8b6067abb222486939988c9b43f45981649a',
    );

    final opened = open(envelope: envelope, keyring: keyring);

    expect(
      opened.payload,
      _unhex('a262707601657469746c6571466f6f7462616c6c20747261696e696e67'),
    );
  });
}
