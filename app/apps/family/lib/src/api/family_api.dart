import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Where the backend lives. The default reaches the host machine from the
/// Android emulator; a phone needs the Mac's address on the local network:
///
///   flutter run --flavor dev --dart-define=API_BASE_URL=http://192.168.1.20:5080
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5080',
);

final familyApiProvider = Provider<FamilyApi>((ref) {
  final api = FamilyApi(Uri.parse(apiBaseUrl));
  ref.onDispose(api.close);
  return api;
});

/// The backend's endpoints, typed. The server holds opaque bytes and routing
/// metadata only; everything readable is sealed before it gets here.
class FamilyApi {
  FamilyApi(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  void close() => _client.close();

  // ---- families, members, devices -----------------------------------------

  Future<CreatedFamily> createFamily({
    required String name,
    required String timeZone,
    required Uint8List signingPublicKey,
    required Uint8List kemPublicKey,
    required String platform,
  }) async {
    final json = await _send(
      'POST',
      '/v1/families',
      body: {
        'name': name,
        'timeZone': timeZone,
        'signingPublicKey': base64Encode(signingPublicKey),
        'kemPublicKey': base64Encode(kemPublicKey),
        'platform': platform,
        // Sealed later, through sync: an envelope binds the member's id, which
        // doesn't exist until this call returns.
        'founderProfileEnvelope': '',
      },
    );
    return CreatedFamily(
      familyId: json['familyId'] as String,
      memberId: json['memberId'] as String,
      deviceId: json['deviceId'] as String,
    );
  }

  Future<String> createMember({
    required String asDevice,
    required MemberRole role,
  }) async {
    final json = await _send(
      'POST',
      '/v1/members',
      device: asDevice,
      body: {'role': role.wire, 'profileEnvelope': ''},
    );
    return json['memberId'] as String;
  }

  /// Registers a scanned device (crypto doc §7.1). Parents only.
  Future<String> registerDevice({
    required String asDevice,
    required String memberId,
    required Uint8List signingPublicKey,
    required Uint8List kemPublicKey,
    required String platform,
  }) async {
    final json = await _send(
      'POST',
      '/v1/devices',
      device: asDevice,
      body: {
        'memberId': memberId,
        'signingPublicKey': base64Encode(signingPublicKey),
        'kemPublicKey': base64Encode(kemPublicKey),
        'platform': platform,
      },
    );
    return json['deviceId'] as String;
  }

  // ---- group keys -----------------------------------------------------------

  Future<void> publishGrants({
    required String asDevice,
    required String group,
    required int epoch,
    required Map<String, Uint8List> grantsByDevice,
  }) => _send(
    'POST',
    '/v1/keys',
    device: asDevice,
    body: {
      'groupName': group,
      'epoch': epoch,
      'keys': [
        for (final MapEntry(key: deviceId, value: grant)
            in grantsByDevice.entries)
          {'deviceId': deviceId, 'wrappedKey': base64Encode(grant)},
      ],
    },
  );

  /// Every grant addressed to this device. The group and epoch beside each
  /// are the server's claim; the signed grant is the only trustworthy reading.
  Future<List<Uint8List>> grants({required String asDevice}) async {
    final json = await _send('GET', '/v1/keys', device: asDevice);
    return [
      for (final k in json as List<dynamic>)
        base64Decode((k as Map<String, dynamic>)['wrappedKey'] as String),
    ];
  }

  // ---- pairing (crypto doc §7.1) --------------------------------------------

  Future<void> sendAdmission({
    required String asDevice,
    required String toDevice,
    required String mailbox,
    required Uint8List admission,
  }) => _send(
    'POST',
    '/v1/pairing/admissions',
    device: asDevice,
    body: {
      'toDeviceId': toDevice,
      'mailbox': mailbox,
      'admission': base64Encode(admission),
    },
  );

  /// Anonymous: the new device has no id to authenticate with yet.
  Future<List<PendingAdmission>> collectAdmissions(String mailbox) async {
    final json = await _send('GET', '/v1/pairing/mailbox/$mailbox');
    return [
      for (final a in json as List<dynamic>)
        PendingAdmission(
          id: (a as Map<String, dynamic>)['admissionId'] as String,
          admission: base64Decode(a['admission'] as String),
        ),
    ];
  }

  Future<void> acknowledgeAdmission({
    required String asDevice,
    required String admissionId,
  }) =>
      _send('DELETE', '/v1/pairing/admissions/$admissionId', device: asDevice);

  Future<void> publishEndorsement({
    required String asDevice,
    required String subjectDevice,
    required Uint8List endorsement,
  }) => _send(
    'POST',
    '/v1/pairing/endorsements',
    device: asDevice,
    body: {
      'subjectDeviceId': subjectDevice,
      'endorsement': base64Encode(endorsement),
    },
  );

  Future<List<Uint8List>> endorsements({required String asDevice}) async {
    final json = await _send(
      'GET',
      '/v1/pairing/endorsements',
      device: asDevice,
    );
    return [
      for (final e in json as List<dynamic>)
        base64Decode((e as Map<String, dynamic>)['endorsement'] as String),
    ];
  }

  // ---------------------------------------------------------------------------

  Future<dynamic> _send(
    String method,
    String path, {
    String? device,
    Object? body,
  }) async {
    final request = http.Request(method, baseUrl.resolve(path));
    if (device != null) request.headers['X-Device-Id'] = device;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode >= 400) {
      throw ApiException(method, path, response.statusCode, response.body);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }
}

enum MemberRole {
  parent(0),
  child(1),
  helper(2);

  const MemberRole(this.wire);

  /// The backend's enum value.
  final int wire;
}

class CreatedFamily {
  const CreatedFamily({
    required this.familyId,
    required this.memberId,
    required this.deviceId,
  });

  final String familyId;
  final String memberId;
  final String deviceId;
}

class PendingAdmission {
  const PendingAdmission({required this.id, required this.admission});

  final String id;
  final Uint8List admission;
}

class ApiException implements Exception {
  ApiException(this.method, this.path, this.status, this.body);

  final String method;
  final String path;
  final int status;
  final String body;

  @override
  String toString() => 'ApiException: $method $path → $status $body';
}
