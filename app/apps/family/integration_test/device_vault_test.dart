// Runs on a device: the device secret in the real Android Keystore / iOS
// Keychain (crypto doc §2.1), and the vault's refusal to paper over damage.
//
//   flutter test integration_test --flavor dev -d <device>

import 'dart:typed_data';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => RustLib.init());

  group('platform storage', () {
    // Start and end clean: the dev app on a real phone shares this storage.
    setUp(() => DeviceVault().destroy());
    tearDown(() => DeviceVault().destroy());

    test('an identity survives a restart', () async {
      final created = await DeviceVault().loadOrCreate();

      // A new vault reads the platform store afresh, as after a restart.
      final restored = await DeviceVault().load();

      expect(restored, isNotNull);
      expect(restored!.signingPublicKey, created.signingPublicKey);
      expect(restored.kemPublicKey, created.kemPublicKey);
    });

    test('the restored identity still opens what it was granted', () async {
      final device = await DeviceVault().loadOrCreate();
      final keyring = Keyring()..generate(group: 'all', epoch: 0);
      final selfGrant = keyring.grant(
        group: 'all',
        epoch: 0,
        familyId: 'fam-1',
        granter: device,
        fromDevice: 'phone',
        toDevice: 'phone',
        toKemKey: device.kemPublicKey,
      );

      final restored = (await DeviceVault().load())!;
      final rebuilt = Keyring()
        ..acceptGrant(
          grant: selfGrant,
          familyId: 'fam-1',
          me: restored,
          myDevice: 'phone',
          trusted: [
            TrustedDevice(
              deviceId: 'phone',
              signingKey: device.signingPublicKey,
            ),
          ],
        );
      expect(rebuilt.contains(group: 'all', epoch: 0), isTrue);
    });

    test('destroy forgets the identity', () async {
      await DeviceVault().loadOrCreate();
      await DeviceVault().destroy();
      expect(await DeviceVault().load(), isNull);
    });
  });

  group('failure handling', () {
    test('concurrent first calls create one identity, not two', () async {
      final store = MemorySecretStore();
      final vault = DeviceVault(store: store);

      final both = await Future.wait([
        vault.loadOrCreate(),
        vault.loadOrCreate(),
      ]);

      expect(both[0].signingPublicKey, both[1].signingPublicKey);
      expect(store.values, hasLength(1));
    });

    test('a damaged secret is an error, never a new identity', () async {
      final store = MemorySecretStore();
      final vault = DeviceVault(store: store);
      await vault.loadOrCreate();
      final key = store.values.keys.single;
      store.values[key] = Uint8List.fromList([0xde, 0xad]);

      await expectLater(
        DeviceVault(store: store).loadOrCreate(),
        throwsA(isA<DeviceVaultException>()),
      );
      // And the damaged value is left for a person to deal with.
      expect(store.values[key], [0xde, 0xad]);
    });

    test('a storage failure is an error, never a new identity', () async {
      final vault = DeviceVault(store: _FailingStore());
      await expectLater(
        vault.loadOrCreate(),
        throwsA(isA<DeviceVaultException>()),
      );
    });
  });
}

class _FailingStore implements SecretStore {
  @override
  Future<Uint8List?> read(String key) =>
      throw StateError('Keystore unavailable');

  @override
  Future<void> write(String key, Uint8List value) =>
      throw StateError('should not write after a failed read');

  @override
  Future<void> delete(String key) async {}
}
