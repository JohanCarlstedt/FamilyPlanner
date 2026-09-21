import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../membership/membership.dart';

/// Signing in to ICA, without ever holding the password.
///
/// ICA has no published API (docs/ica.md). What their own app talks to is
/// a Curity identity server in front of an API gateway, and the flow it
/// uses is an ordinary OAuth authorization code with PKCE — which means
/// the login page can be **ICA's own**. The person types their
/// personnummer and password into a page served by icagruppen.se; this
/// app sees an authorization code come back and nothing else. There is no
/// password here to store, leak or be asked for.
///
/// What is stored is a refresh token and the per-install client this
/// device registered, in the same place as the device secret: on the
/// phone, out of backup, **never synced**. A family's ICA account is one
/// person's account, and pushing a token for it to every device in the
/// house would be a worse idea than the feature is good.
///
/// Three things to know before relying on it:
///
/// - It is nobody's published contract, so it can break without notice.
///   Everything here fails quietly back to "Send the list".
/// - The gateway answers 451 to addresses outside Sweden, so it stops
///   working on holiday. That is their rule, not a bug here.
/// - It is very likely against ICA's terms of use. It is the family's own
///   account and their own data, which is why this exists at all, but the
///   realistic downside is ICA closing the door.
class IcaAuth {
  IcaAuth(this._ref, {http.Client? client})
    : _http = client ?? http.Client();

  final Ref _ref;
  final http.Client _http;

  static const _ims = 'https://ims.icagruppen.se';
  static const tokenEndpoint = '$_ims/oauth/v2/token';
  static const authorizeEndpoint = '$_ims/oauth/v2/authorize';
  static const registerEndpoint = '$_ims/register';

  /// The redirect the identity server hands the code back on. Fixed by
  /// the registration template — we are told it, not asked. Never
  /// followed: the login view watches for a navigation to it and reads
  /// the code out of the address, which is why nothing has to claim this
  /// scheme with the operating system. Claiming it would collide with
  /// ICA's own app on a phone that has both.
  static const redirectUri = 'icacurity://app';

  static const _acr = 'urn:se:curity:authentication:html-form:IcaCustomers';
  static const _softwareId = 'dcr-ica-app-template';

  /// The bootstrap client every copy of ICA's app uses to register itself.
  /// Public by construction — a PKCE client has no secret worth keeping —
  /// and it identifies the software, never a person.
  static const _dcrClientId = String.fromEnvironment(
    'ICA_DCR_CLIENT_ID',
    defaultValue: '',
  );
  static const _dcrClientSecret = String.fromEnvironment(
    'ICA_DCR_CLIENT_SECRET',
    defaultValue: '',
  );

  /// Whether this build can talk to ICA at all. Without the bootstrap
  /// identifiers it cannot, and the screen says so rather than failing
  /// halfway through a login.
  static bool get available =>
      _dcrClientId.isNotEmpty && _dcrClientSecret.isNotEmpty;

  static const _key = 'ica.v1';

  /// Registers this install as its own client and starts a login.
  ///
  /// Returns the address to open, and the verifier that must come back
  /// with the code. Nothing is stored until a code is exchanged: an
  /// abandoned login leaves no trace.
  Future<IcaLogin?> begin() async {
    if (!available) return null;
    try {
      final bootstrap = await _post(tokenEndpoint, {
        'client_id': _dcrClientId,
        'client_secret': _dcrClientSecret,
        'grant_type': 'client_credentials',
        'scope': 'dcr',
        'response_type': 'token',
      });
      final registration = await _postJson(
        registerEndpoint,
        {'software_id': _softwareId},
        bearer: bootstrap['access_token'] as String,
      );

      final verifier = _randomUrlSafe(32);
      final state = _randomUrlSafe(12);
      final challenge = base64Url
          .encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');

      return IcaLogin(
        clientId: registration['client_id'] as String,
        clientSecret: registration['client_secret'] as String,
        scope: registration['scope'] as String,
        verifier: verifier,
        state: state,
        authorizeUrl: Uri.parse(authorizeEndpoint).replace(
          queryParameters: {
            'client_id': registration['client_id'] as String,
            'scope': registration['scope'] as String,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            // The same value the login view checks the reply against: a
            // code arriving under a state we did not send belongs to
            // someone else's login, not ours.
            'state': state,
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
            'acr': _acr,
          },
        ),
      );
    } on Object catch (e) {
      debugPrint('ICA login could not be started: $e');
      return null;
    }
  }

  /// Swaps the code the login view caught for tokens, and keeps them.
  Future<bool> finish(IcaLogin login, String code) async {
    try {
      final token = await _post(tokenEndpoint, {
        'code': code,
        'client_id': login.clientId,
        'client_secret': login.clientSecret,
        'grant_type': 'authorization_code',
        'scope': login.scope,
        'response_type': 'token',
        'code_verifier': login.verifier,
        'redirect_uri': redirectUri,
      });
      await _save(
        IcaSession(
          clientId: login.clientId,
          clientSecret: login.clientSecret,
          refreshToken: token['refresh_token'] as String,
          accessToken: token['access_token'] as String,
          expiresAt: DateTime.now().toUtc().add(
            Duration(seconds: (token['expires_in'] as num?)?.toInt() ?? 900),
          ),
        ),
      );
      return true;
    } on Object catch (e) {
      debugPrint('ICA login could not be finished: $e');
      return false;
    }
  }

  /// A usable access token, refreshed if it has run out. Null when this
  /// device is not signed in, or the refresh token has been withdrawn —
  /// which is what happens when someone revokes access at ICA, and is
  /// meant to.
  Future<String?> accessToken() async {
    final session = await current();
    if (session == null) return null;
    // A minute's margin: a token that expires mid-request is a failure
    // with no explanation.
    if (session.expiresAt.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    )) {
      return session.accessToken;
    }

    try {
      final basic = base64.encode(
        utf8.encode('${session.clientId}:${session.clientSecret}'),
      );
      final token = await _post(tokenEndpoint, {
        'grant_type': 'refresh_token',
        'refresh_token': session.refreshToken,
      }, headers: {'Authorization': 'Basic $basic'});
      final refreshed = IcaSession(
        clientId: session.clientId,
        clientSecret: session.clientSecret,
        // A rolling refresh token: keep the new one when there is one.
        refreshToken:
            token['refresh_token'] as String? ?? session.refreshToken,
        accessToken: token['access_token'] as String,
        expiresAt: DateTime.now().toUtc().add(
          Duration(seconds: (token['expires_in'] as num?)?.toInt() ?? 900),
        ),
      );
      await _save(refreshed);
      return refreshed.accessToken;
    } on Object catch (e) {
      debugPrint('ICA token could not be refreshed: $e');
      return null;
    }
  }

  Future<IcaSession?> current() async {
    final bytes = await _ref.read(secretStoreProvider).read(_key);
    if (bytes == null) return null;
    try {
      return IcaSession.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  Future<bool> get isConnected async => await current() != null;

  /// Forgets this device's ICA session. Local only — it does not close
  /// the account's access at ICA's end, and the screen says so, because
  /// the person who wants that wants it properly.
  Future<void> disconnect() =>
      _ref.read(secretStoreProvider).delete(_key);

  Future<void> _save(IcaSession session) => _ref
      .read(secretStoreProvider)
      .write(
        _key,
        Uint8List.fromList(utf8.encode(jsonEncode(session.toJson()))),
      );

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, String> form, {
    Map<String, String>? headers,
  }) async {
    final response = await _http.post(
      Uri.parse(url),
      body: form,
      headers: headers,
    );
    if (response.statusCode >= 300) {
      throw IcaException('${response.statusCode} from $url');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, Object?> body, {
    required String bearer,
  }) async {
    final response = await _http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearer',
      },
    );
    if (response.statusCode >= 300) {
      throw IcaException('${response.statusCode} from $url');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static String _randomUrlSafe(int bytes) {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(bytes, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }
}

/// A login in progress: what the view must open, and what the code must
/// come back with.
class IcaLogin {
  const IcaLogin({
    required this.clientId,
    required this.clientSecret,
    required this.scope,
    required this.verifier,
    required this.state,
    required this.authorizeUrl,
  });

  final String clientId;
  final String clientSecret;
  final String scope;
  final String verifier;
  final String state;
  final Uri authorizeUrl;
}

/// What this device keeps: its own registered client, and a refresh
/// token. No password, because there never was one here to keep.
class IcaSession {
  const IcaSession({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.accessToken,
    required this.expiresAt,
  });

  final String clientId;
  final String clientSecret;
  final String refreshToken;
  final String accessToken;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'clientId': clientId,
    'clientSecret': clientSecret,
    'refreshToken': refreshToken,
    'accessToken': accessToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  static IcaSession fromJson(Map<String, dynamic> json) => IcaSession(
    clientId: json['clientId'] as String,
    clientSecret: json['clientSecret'] as String,
    refreshToken: json['refreshToken'] as String,
    accessToken: json['accessToken'] as String? ?? '',
    expiresAt:
        DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
        DateTime.utc(1970),
  );
}

class IcaException implements Exception {
  IcaException(this.message);
  final String message;
  @override
  String toString() => 'IcaException: $message';
}

final icaAuthProvider = Provider<IcaAuth>(IcaAuth.new);
