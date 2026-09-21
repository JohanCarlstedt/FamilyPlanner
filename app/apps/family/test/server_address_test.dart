import 'package:family/src/api/server_address.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading an address someone typed', () {
    test('assumes https and keeps only the origin', () {
      // The path would be dropped anyway: every call resolves an absolute
      // /v1/... against this. Better it visibly disappears in the field.
      expect(
        normaliseServerAddress('family.example.com'),
        Uri.parse('https://family.example.com'),
      );
      expect(
        normaliseServerAddress('  https://family.example.com/some/path  '),
        Uri.parse('https://family.example.com'),
      );
      expect(
        normaliseServerAddress('https://family.example.com:8443'),
        Uri.parse('https://family.example.com:8443'),
      );
    });

    test('refuses plain http anywhere it could be overheard', () {
      expect(normaliseServerAddress('http://family.example.com'), isNull);
      // ...but allows it where the development backend lives, and where
      // iOS permits it too.
      for (final host in const [
        'http://localhost:5080',
        'http://10.0.2.2:5080',
        'http://192.168.15.39:5080',
        'http://172.16.4.1',
        'http://127.0.0.1:5080',
        'http://mac.local:5080',
      ]) {
        expect(normaliseServerAddress(host), isNotNull, reason: host);
      }
    });

    test('refuses what cannot be a server', () {
      for (final junk in const [
        '',
        '   ',
        'not a host',
        'ftp://family.example.com',
        // Credentials in an address are a phishing shape, not a server.
        'https://someone:secret@family.example.com',
      ]) {
        expect(normaliseServerAddress(junk), isNull, reason: '"$junk"');
      }
    });

    test('172.32 is public even though 172.16 is not', () {
      expect(isLocalHost('172.31.255.1'), isTrue);
      expect(isLocalHost('172.32.0.1'), isFalse);
      expect(isLocalHost('10.0.0.1'), isTrue);
      expect(isLocalHost('8.8.8.8'), isFalse);
    });
  });

  group('pinning', () {
    late ProviderContainer container;
    late MemorySecretStore secrets;

    ProviderContainer make({Uri? pinned}) {
      secrets = MemorySecretStore();
      return ProviderContainer(
        overrides: [
          secretStoreProvider.overrideWithValue(secrets),
          pinnedServerProvider.overrideWithValue(pinned),
        ],
      );
    }

    tearDown(() => container.dispose());

    test('an install that has never paired uses the compiled default', () {
      container = make();
      expect(container.read(serverProvider), defaultServer);
      expect(container.read(serverProvider.notifier).isCustom, isFalse);
    });

    test('an install that has paired uses what it pinned', () {
      final ours = Uri.parse('https://family.example.com');
      container = make(pinned: ours);
      expect(container.read(serverProvider), ours);
      expect(container.read(serverProvider.notifier).isCustom, isTrue);
    });

    test('saving a membership binds this install to its server', () async {
      container = make();
      final server = container.read(serverProvider.notifier);
      await server.choose(Uri.parse('https://family.example.com'));
      expect(await server.isPinned, isFalse, reason: 'chosen, not yet pinned');

      await server.pinToCurrent();

      expect(
        await ServerAddressStore(secrets).load(),
        Uri.parse('https://family.example.com'),
      );
    });

    test('a second membership does not move a pinned install', () async {
      container = make();
      final server = container.read(serverProvider.notifier);
      await server.pinToCurrent();
      // Whatever happens later, the device's identity is registered on the
      // server it first paired with and nowhere else.
      expect(
        () => server.choose(Uri.parse('https://elsewhere.example.com')),
        throwsStateError,
      );
      await server.pinToCurrent();
      expect(await ServerAddressStore(secrets).load(), defaultServer);
    });

    test('unbinding releases the address for the next setup', () async {
      container = make();
      final server = container.read(serverProvider.notifier);
      await server.choose(Uri.parse('https://family.example.com'));
      await server.pinToCurrent();

      await server.forget();

      expect(await server.isPinned, isFalse);
      expect(container.read(serverProvider), defaultServer);
      // And choosing works again, which is the whole point of releasing it.
      await server.choose(Uri.parse('https://another.example.com'));
      expect(container.read(serverProvider).host, 'another.example.com');
    });
  });
}
