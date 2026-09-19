import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

/// The backend's endpoints, typed. The server holds opaque bytes and routing
/// metadata only; everything readable is sealed before it gets here.
/// Signs a request as [deviceId] (crypto doc §2.2): returns the 64-byte
/// Ed25519 signature. The device key never leaves the Rust core; this only
/// says which device's key to ask.
typedef RequestSigner = Future<Uint8List> Function(
  String deviceId,
  String method,
  String pathAndQuery,
  int timestampMs,
  Uint8List body,
);

class FamilyApi {
  FamilyApi(this.baseUrl, {http.Client? client, this.signer})
    : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  /// Required for every call made as a device.
  final RequestSigner? signer;

  /// This device's clock minus the server's, learned from a request the
  /// server refused for skew. Signatures carry the server's idea of now.
  Duration _clockOffset = Duration.zero;

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
      body: {'role': _roleWire(role), 'profileEnvelope': ''},
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

  /// The family's devices and whose they are: the server's claim, fit for
  /// routing reminders, never for trust (keys are pinned at pairing).
  Future<
    List<({String deviceId, String memberId, bool revoked, String platform})>
  >
  directory({required String asDevice, required String familyId}) async {
    final json = await _send(
      'GET',
      '/v1/families/$familyId/devices',
      device: asDevice,
    );
    return [
      for (final d in json as List<dynamic>)
        (
          deviceId: (d as Map<String, dynamic>)['deviceId'] as String,
          memberId: d['memberId'] as String,
          revoked: d['revoked'] as bool,
          platform: d['platform'] as String? ?? '',
        ),
    ];
  }

  /// Removes a device from the family. Parents only; it stops
  /// authenticating at once. Rotating the groups it was in is the caller's
  /// job: only a device holding the keys can do it.
  Future<void> revokeDevice({
    required String asDevice,
    required String deviceId,
  }) => _send('POST', '/v1/devices/$deviceId/revoke', device: asDevice);

  // ---- recovery (crypto doc §7.3) -------------------------------------------

  /// Stores this member's recovery kit, retiring any earlier one.
  Future<void> saveRecoveryKit({
    required String asDevice,
    required String lookupId,
    required String deviceId,
    required Uint8List note,
  }) => _send(
    'POST',
    '/v1/recovery',
    device: asDevice,
    body: {
      'lookupId': lookupId,
      'deviceId': deviceId,
      'note': base64Encode(note),
    },
  );

  /// Anonymous: after total loss there's no device to sign with. Null when
  /// no kit answers to [lookupId].
  Future<({String deviceId, String familyId, String memberId, Uint8List note})?>
  recoveryKit(String lookupId) async {
    try {
      final json =
          await _send('GET', '/v1/recovery/$lookupId') as Map<String, dynamic>;
      return (
        deviceId: json['deviceId'] as String,
        familyId: json['familyId'] as String,
        memberId: json['memberId'] as String,
        note: base64Decode(json['note'] as String),
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
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

  // ---- sync (architecture doc §7) ------------------------------------------

  /// Submits queued writes. Idempotent on each command's client id, so a batch
  /// can be resent after a lost response.
  Future<List<CommandResult>> submitCommands({
    required String asDevice,
    required List<OutgoingCommand> commands,
  }) async {
    final json = await _send(
      'POST',
      '/v1/commands',
      device: asDevice,
      body: {
        'commands': [
          for (final c in commands)
            {
              'clientCommandId': c.clientCommandId,
              'type': c.type,
              'targetObjectId': c.targetId,
              'targetKind': c.targetKind,
              'scope': c.scope,
              'envelope': base64Encode(c.envelope),
              'expectedVersion': c.expectedVersion,
              'issuedAt': c.issuedAt.toUtc().toIso8601String(),
            },
        ],
      },
    );
    return [
      for (final r
          in (json as Map<String, dynamic>)['results'] as List<dynamic>)
        CommandResult(
          clientCommandId:
              (r as Map<String, dynamic>)['clientCommandId'] as String,
          status: r['status'] as String,
          sequence: r['sequence'] as int?,
          reason: r['reason'] as String?,
        ),
    ];
  }

  /// Where this device receives pushes: an FCM token on Android.
  Future<void> registerPushToken({
    required String asDevice,
    required String token,
  }) => _send(
    'PUT',
    '/v1/devices/push-token',
    device: asDevice,
    body: {'token': token},
  );

  /// Schedules contentless wakes for this device and cancels others, by
  /// opaque reference. Registering a reference again moves its time.
  Future<void> scheduleWakes({
    required String asDevice,
    required Map<String, DateTime> wakes,
    List<String> cancel = const [],
  }) => _send(
    'POST',
    '/v1/wakes',
    device: asDevice,
    body: {
      'wakes': [
        for (final MapEntry(key: ref, value: at) in wakes.entries)
          {'correlationRef': ref, 'fireAt': at.toUtc().toIso8601String()},
      ],
      'cancelRefs': cancel,
    },
  );

  // ---- chat delivery service (crypto doc §7.2) --------------------------------

  /// Publishes key packages; returns how many of this device's are unclaimed.
  Future<int> publishKeyPackages({
    required String asDevice,
    required List<Uint8List> keyPackages,
  }) async {
    final json = await _send(
      'POST',
      '/v1/mls/key-packages',
      device: asDevice,
      body: {
        'keyPackages': [for (final k in keyPackages) base64Encode(k)],
      },
    );
    return (json as Map<String, dynamic>)['unclaimed'] as int;
  }

  Future<int> unclaimedKeyPackages({required String asDevice}) async {
    final json = await _send(
      'GET',
      '/v1/mls/key-packages/count',
      device: asDevice,
    );
    return (json as Map<String, dynamic>)['unclaimed'] as int;
  }

  /// One key package per device, each handed out once. Devices without one
  /// are missing from the result.
  Future<Map<String, Uint8List>> claimKeyPackages({
    required String asDevice,
    required List<String> deviceIds,
  }) async {
    final json = await _send(
      'POST',
      '/v1/mls/key-packages/claim',
      device: asDevice,
      body: {'deviceIds': deviceIds},
    );
    return {
      for (final k in json as List<dynamic>)
        (k as Map<String, dynamic>)['deviceId'] as String: base64Decode(
          k['keyPackage'] as String,
        ),
    };
  }

  /// Sends a commit for [epoch]. Throws [MlsEpochConflict] when another
  /// commit got there first.
  Future<int> commitMls({
    required String asDevice,
    required String groupId,
    required int epoch,
    required Uint8List commit,
    Uint8List? welcome,
    List<String> welcomeTo = const [],
  }) async {
    try {
      final json = await _send(
        'POST',
        '/v1/mls/groups/$groupId/commit',
        device: asDevice,
        body: {
          'epoch': epoch,
          'commit': base64Encode(commit),
          if (welcome != null) 'welcome': base64Encode(welcome),
          'welcomeTo': welcomeTo,
        },
      );
      return (json as Map<String, dynamic>)['epoch'] as int;
    } on ApiException catch (e) {
      if (e.status == 409) {
        throw MlsEpochConflict(
          (jsonDecode(e.body) as Map<String, dynamic>)['epoch'] as int,
        );
      }
      rethrow;
    }
  }

  /// Relays an encrypted chat message; returns its sequence number. One sent
  /// to a [slot] replaces this device's last one there. Throws
  /// [MlsEpochConflict] when the group has moved on: members added since
  /// couldn't read it.
  Future<int> sendMlsMessage({
    required String asDevice,
    required String groupId,
    required int epoch,
    required Uint8List message,
    String? slot,
  }) async {
    try {
      final json = await _send(
        'POST',
        '/v1/mls/groups/$groupId/messages',
        device: asDevice,
        body: {'epoch': epoch, 'message': base64Encode(message), 'slot': ?slot},
      );
      return (json as Map<String, dynamic>)['seq'] as int;
    } on ApiException catch (e) {
      if (e.status == 409) {
        throw MlsEpochConflict(
          (jsonDecode(e.body) as Map<String, dynamic>)['epoch'] as int,
        );
      }
      rethrow;
    }
  }

  Future<MlsPage> mlsMessages({
    required String asDevice,
    required int since,
  }) async {
    final json = await _send(
      'GET',
      '/v1/mls/messages?since=$since',
      device: asDevice,
    ) as Map<String, dynamic>;
    return MlsPage(
      messages: [
        for (final m in json['messages'] as List<dynamic>)
          MlsRelayed(
            seq: (m as Map<String, dynamic>)['seq'] as int,
            groupId: m['groupId'] as String,
            epoch: m['epoch'] as int,
            kind: m['kind'] as String,
            sender: m['sender'] as String,
            body: base64Decode(m['body'] as String),
          ),
      ],
      cursor: json['cursor'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  /// Everything changed in this device's scopes after [since].
  Future<SyncPage> pull({required String asDevice, required int since}) async {
    final json = await _send(
      'GET',
      '/v1/sync?since=$since',
      device: asDevice,
    ) as Map<String, dynamic>;
    return SyncPage(
      changes: [
        for (final c in json['changes'] as List<dynamic>)
          RemoteObject(
            id: (c as Map<String, dynamic>)['id'] as String,
            kind: c['kind'] as int,
            scope: c['scope'] as String,
            envelope: c['envelope'] == null
                ? null
                : base64Decode(c['envelope'] as String),
            version: c['version'] as int,
            deleted: c['deleted'] as bool,
          ),
      ],
      cursor: json['cursor'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  // ---------------------------------------------------------------------------

  // ---- encrypted blobs (photos) --------------------------------------------

  /// Uploads sealed bytes under [id]; idempotent, so a retry is harmless.
  Future<void> putBlob({
    required String asDevice,
    required String id,
    required Uint8List envelope,
  }) async {
    final r = await _sendRaw('PUT', '/v1/blobs/$id', asDevice, envelope);
    if (r.statusCode >= 400) {
      throw ApiException('PUT', '/v1/blobs/$id', r.statusCode, r.body);
    }
  }

  /// The sealed bytes stored under [id], or null if there are none.
  Future<Uint8List?> getBlob({
    required String asDevice,
    required String id,
  }) async {
    final r = await _sendRaw('GET', '/v1/blobs/$id', asDevice, Uint8List(0));
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) {
      throw ApiException('GET', '/v1/blobs/$id', r.statusCode, r.body);
    }
    return r.bodyBytes;
  }

  Future<void> deleteBlob({required String asDevice, required String id}) =>
      _sendRaw('DELETE', '/v1/blobs/$id', asDevice, Uint8List(0));

  /// A signed request with a raw body, for the blob store.
  Future<http.Response> _sendRaw(
    String method,
    String path,
    String device,
    Uint8List bytes,
  ) async {
    final uri = baseUrl.resolve(path);
    final request = http.Request(method, uri);
    if (bytes.isNotEmpty) {
      request.headers['Content-Type'] = 'application/octet-stream';
      request.bodyBytes = bytes;
    }
    final sign = signer;
    if (sign == null) {
      throw StateError('FamilyApi needs a signer to call as a device');
    }
    final timestamp = DateTime.now()
        .subtract(_clockOffset)
        .millisecondsSinceEpoch;
    request.headers
      ..['X-Device-Id'] = device
      ..['X-Fam-Timestamp'] = '$timestamp'
      ..['X-Fam-Signature'] = base64Encode(
        await sign(device, method, uri.path, timestamp, bytes),
      );
    return http.Response.fromStream(await _client.send(request));
  }

  Future<dynamic> _send(
    String method,
    String path, {
    String? device,
    Object? body,
    bool retriedForSkew = false,
  }) async {
    final uri = baseUrl.resolve(path);
    final request = http.Request(method, uri);
    final bytes = body == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(jsonEncode(body)));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.bodyBytes = bytes;
    }
    if (device != null) {
      final sign = signer;
      if (sign == null) {
        throw StateError('FamilyApi needs a signer to call as a device');
      }
      final timestamp = DateTime.now()
          .subtract(_clockOffset)
          .millisecondsSinceEpoch;
      final target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      request.headers
        ..['X-Device-Id'] = device
        ..['X-Fam-Timestamp'] = '$timestamp'
        ..['X-Fam-Signature'] = base64Encode(
          await sign(device, method, target, timestamp, bytes),
        );
    }

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode == 401 &&
        device != null &&
        !retriedForSkew &&
        response.body.contains('clock_skew')) {
      // A phone whose clock is off by minutes is common; the server's Date
      // header says by how much. One retry on its clock.
      final serverNow = _httpDate(response.headers['date']);
      if (serverNow != null) {
        _clockOffset = DateTime.now().difference(serverNow);
        return _send(
          method,
          path,
          device: device,
          body: body,
          retriedForSkew: true,
        );
      }
    }
    if (response.statusCode >= 400) {
      throw ApiException(method, path, response.statusCode, response.body);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  static DateTime? _httpDate(String? value) {
    if (value == null) return null;
    try {
      return http_parser.parseHttpDate(value);
    } on FormatException {
      return null;
    }
  }
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

class OutgoingCommand {
  const OutgoingCommand({
    required this.clientCommandId,
    required this.type,
    required this.targetId,
    required this.targetKind,
    required this.scope,
    required this.envelope,
    required this.expectedVersion,
    required this.issuedAt,
  });

  final String clientCommandId;
  final String type;
  final String targetId;
  final int targetKind;
  final String scope;
  final Uint8List envelope;
  final int? expectedVersion;
  final DateTime issuedAt;
}

class CommandResult {
  const CommandResult({
    required this.clientCommandId,
    required this.status,
    this.sequence,
    this.reason,
  });

  final String clientCommandId;

  /// `applied`, `duplicate`, `conflict` or `rejected`.
  final String status;
  final int? sequence;
  final String? reason;
}

class RemoteObject {
  const RemoteObject({
    required this.id,
    required this.kind,
    required this.scope,
    required this.envelope,
    required this.version,
    required this.deleted,
  });

  final String id;
  final int kind;
  final String scope;

  /// Null for a deletion.
  final Uint8List? envelope;
  final int version;
  final bool deleted;
}

class SyncPage {
  const SyncPage({
    required this.changes,
    required this.cursor,
    required this.hasMore,
  });

  final List<RemoteObject> changes;
  final int cursor;
  final bool hasMore;
}

/// The backend's MemberRole values.
int _roleWire(MemberRole role) => switch (role) {
  MemberRole.parent => 0,
  MemberRole.child => 1,
  MemberRole.helper => 2,
};

/// Another device's commit reached the delivery service first.
class MlsEpochConflict implements Exception {
  MlsEpochConflict(this.epoch);

  /// The group's epoch now.
  final int epoch;

  @override
  String toString() => 'MlsEpochConflict(epoch: $epoch)';
}

/// One message from the delivery service: `commit`, `application` or
/// `welcome`, in the service's order.
class MlsRelayed {
  const MlsRelayed({
    required this.seq,
    required this.groupId,
    required this.epoch,
    required this.kind,
    required this.sender,
    required this.body,
  });

  final int seq;
  final String groupId;
  final int epoch;
  final String kind;
  final String sender;
  final Uint8List body;
}

class MlsPage {
  const MlsPage({
    required this.messages,
    required this.cursor,
    required this.hasMore,
  });

  final List<MlsRelayed> messages;
  final int cursor;
  final bool hasMore;
}
