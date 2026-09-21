import 'dart:convert';
import 'dart:typed_data';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../membership/membership.dart';

/// Where this install's server is, decided once and then kept.
///
/// The address used to be nothing but a compile-time constant, which made
/// two things impossible. A family could not run its own server without
/// building the app themselves. And a device that had already paired was
/// one shipped default away from disaster: its identity is registered on
/// one particular server, so a build pointing somewhere else would have
/// every request refused by a server that has never heard of it — which
/// on screen looks exactly like a wiped install.
///
/// So the compiled value is now only a *default*, used until a family is
/// created or joined. At that moment the address is pinned beside the
/// membership, and from then on this install talks to that server however
/// often the default changes underneath it. `Unbind` clears it again: a
/// device leaving the family may next be set up somewhere else entirely.
///
/// **This is not what lets the server move.** Pinning holds a device to
/// the address it paired with, which is the opposite. Moving the server
/// without breaking every phone needs a hostname you own and a DNS record
/// you can repoint — see docs/hosting.md. What pinning buys is
/// self-hosting, a staging install that prod builds leave alone, and never
/// re-homing a paired device by accident.
const defaultServerAddress = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5080',
);

/// The compiled default, as a [Uri].
Uri get defaultServer => Uri.parse(defaultServerAddress);

/// Reads what someone typed, or returns null if it cannot be a server.
///
/// Reduced to an origin — scheme, host, port — because that is all that is
/// ever used: every call resolves an absolute `/v1/...` path against it, so
/// a path here would be silently dropped. Better it visibly disappears
/// while the person can still see the field.
///
/// A scheme may be left off; https is assumed, since that is the only thing
/// a real server should answer on. Plain http is allowed only on the local
/// network, where the development backend lives and where iOS permits it.
Uri? normaliseServerAddress(String typed) {
  final text = typed.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  // `Uri` will percent-encode anything into a host, so "not a host" parses
  // as one. A name or an address, or it is prose.
  if (!_hostShaped.hasMatch(uri.host)) return null;
  if (uri.scheme == 'http' && !isLocalHost(uri.host)) return null;
  // Credentials in an address are a phishing shape, not a server.
  if (uri.userInfo.isNotEmpty) return null;

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}

/// A hostname, an IPv4 address, or an IPv6 one (`Uri.host` drops the
/// brackets, leaving hex and colons).
final _hostShaped = RegExp(r'^([a-zA-Z0-9][a-zA-Z0-9.\-]*|[0-9a-fA-F:]+)$');

/// Hosts that may be reached without TLS: the machine itself, and the
/// private ranges a home network uses. Everything else on plain http is
/// a mistake, and iOS refuses it regardless.
bool isLocalHost(String host) {
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final v4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
      .firstMatch(host);
  if (v4 == null) return host == '::1';
  final a = int.parse(v4.group(1)!);
  final b = int.parse(v4.group(2)!);
  return a == 127 ||
      a == 10 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 169 && b == 254);
}

/// Persists the pinned address in the same store as the device secret.
///
/// Not secret, and not encrypted — but it belongs to the identity kept
/// there, is meaningless without it, and must be cleared at the same
/// moment, so it lives in the same place rather than somewhere with its
/// own lifetime.
class ServerAddressStore {
  ServerAddressStore(this._store);

  static const _key = 'server.v1';

  final SecretStore _store;

  Future<Uri?> load() async {
    final bytes = await _store.read(_key);
    if (bytes == null) return null;
    return Uri.tryParse(utf8.decode(bytes));
  }

  Future<void> save(Uri address) =>
      _store.write(_key, Uint8List.fromList(utf8.encode(address.toString())));

  Future<void> clear() => _store.delete(_key);
}

final serverAddressStoreProvider = Provider<ServerAddressStore>(
  (ref) => ServerAddressStore(ref.watch(secretStoreProvider)),
);

/// What `main` found pinned, or null on an install that has never paired.
///
/// Overridden there rather than read here so that everything downstream of
/// it — the API client above all — stays synchronous. Tests and the
/// integration suite leave it alone and get the compiled default.
final pinnedServerProvider = Provider<Uri?>((ref) => null);

/// The server this install talks to now.
final serverProvider = NotifierProvider<ServerController, Uri>(
  ServerController.new,
);

class ServerController extends Notifier<Uri> {
  @override
  Uri build() => ref.watch(pinnedServerProvider) ?? defaultServer;

  /// Whether this install is talking to somewhere other than the default.
  bool get isCustom => state != defaultServer;

  /// Whether the address is settled and may no longer be changed. Pinning
  /// happens when a family is created or joined; after that the device has
  /// an identity on that server and nowhere else.
  Future<bool> get isPinned async =>
      await ref.read(serverAddressStoreProvider).load() != null;

  /// Points this install at [address]. Only before pairing: afterwards the
  /// device's identity lives on the pinned server, and moving would strand
  /// it. Refused rather than warned about.
  Future<void> choose(Uri address) async {
    if (await isPinned) {
      throw StateError('the server is pinned; unbind this device first');
    }
    state = address;
  }

  /// Binds this install to the server it just paired against. Called when
  /// a membership is first saved, whichever route made it — created,
  /// joined, recovered or set up as a kitchen display.
  Future<void> pinToCurrent() async {
    final store = ref.read(serverAddressStoreProvider);
    if (await store.load() != null) return;
    await store.save(state);
  }

  /// Forgets the pinned address, so the next setup may choose again.
  /// Part of unbinding, never on its own.
  Future<void> forget() async {
    await ref.read(serverAddressStoreProvider).clear();
    state = defaultServer;
  }
}
