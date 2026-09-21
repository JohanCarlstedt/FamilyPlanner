import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'rust/api.dart';

/// Holds this install's device identity: crypto design doc §2.1.
///
/// The secret is stored encrypted under a hardware-backed key (Android Keystore,
/// iOS Keychain) and never leaves the device. Group keys are not stored here;
/// they persist as grants to this device, which are safe to keep anywhere.
class DeviceVault {
  DeviceVault({SecretStore? store}) : _store = store ?? PlatformSecretStore();

  static const _key = 'device_identity.v1';

  final SecretStore _store;
  Future<Device>? _pending;

  /// This install's identity, created on first use.
  ///
  /// Concurrent callers share one creation, so an install never ends up with
  /// two identities. A secret that exists but can't be read is an error, never
  /// a reason to create a new identity: that would silently orphan the device
  /// from its family.
  Future<Device> loadOrCreate() {
    return _pending ??= _loadOrCreate().catchError((Object e) {
      _pending = null;
      throw e;
    });
  }

  /// Forgets this install's identity, so the next start is a fresh device.
  ///
  /// For a phone leaving the family — given away, replaced, or revoked by a
  /// parent. What it has already read it has read; what this ends is its
  /// ability to read anything more, and its claim to be that device.
  /// Irreversible: the family's copy of the keys is the only one left.
  Future<void> forget() async {
    _pending = null;
    await _store.delete(_key);
  }

  Future<Device> _loadOrCreate() async {
    final existing = await load();
    if (existing != null) return existing;

    final device = Device.generate();
    final secret = device.exportSecret();
    try {
      await _store.write(_key, secret);
    } finally {
      secret.fillRange(0, secret.length, 0);
    }
    return device;
  }

  /// This install's identity, or null if none has been created.
  Future<Device?> load() async {
    final Uint8List? secret;
    try {
      secret = await _store.read(_key);
    } catch (e) {
      throw DeviceVaultException('the device secret could not be read', e);
    }
    if (secret == null) return null;
    try {
      return Device.restore(secret: secret);
    } on CryptoException catch (e) {
      throw DeviceVaultException('the stored device secret is damaged', e);
    } finally {
      secret.fillRange(0, secret.length, 0);
    }
  }

  /// Forgets this install's identity. The family must revoke the device too;
  /// this only stops it from reading anything further.
  Future<void> destroy() async {
    _pending = null;
    await _store.delete(_key);
  }
}

/// The device secret exists but can't be used. Needs a person to decide what
/// happens next (recover, or re-pair as a new device), so it's never handled
/// silently.
class DeviceVaultException implements Exception {
  DeviceVaultException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'DeviceVaultException: $message ($cause)';
}

/// Byte storage for secrets. Swappable so tests can run without a Keystore.
abstract interface class SecretStore {
  Future<Uint8List?> read(String key);

  Future<void> write(String key, Uint8List value);

  Future<void> delete(String key);
}

/// Android Keystore and iOS Keychain, via flutter_secure_storage.
class PlatformSecretStore implements SecretStore {
  PlatformSecretStore()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          // The plugin's default wipes every stored value on any error. For a
          // device identity that is silent, permanent data loss: surface it.
          resetOnError: false,
          // Keep a copy while migrating between cipher algorithms, so a crash
          // mid-migration can't lose the secret.
          migrateWithBackup: true,
        ),
        iOptions: IOSOptions(
          // Readable after the first unlock following a restart, so background
          // sync and the notification extension can use it; never migrates to
          // another device, never syncs to iCloud.
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: false,
        ),
      );

  final FlutterSecureStorage _storage;

  // The plugin stores strings. Base64 strings are immutable and can't be
  // wiped from memory the way the byte buffers around them are; a known,
  // accepted limit of storing the secret through Dart (crypto doc §2.1).
  @override
  Future<Uint8List?> read(String key) async {
    final value = await _storage.read(key: key);
    return value == null ? null : base64Decode(value);
  }

  @override
  Future<void> write(String key, Uint8List value) =>
      _storage.write(key: key, value: base64Encode(value));

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// A [SecretStore] in memory, for tests.
@visibleForTesting
class MemorySecretStore implements SecretStore {
  final Map<String, Uint8List> values = {};

  @override
  Future<Uint8List?> read(String key) async {
    final value = values[key];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> write(String key, Uint8List value) async =>
      values[key] = Uint8List.fromList(value);

  @override
  Future<void> delete(String key) async => values.remove(key);
}
