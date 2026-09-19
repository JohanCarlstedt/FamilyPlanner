import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/device_providers.dart';

/// Where the backend lives. The default reaches the host machine from the
/// Android emulator; a phone needs the Mac's address on the local network:
///
///   flutter run --flavor dev --dart-define=API_BASE_URL=http://192.168.1.20:5080
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5080',
);

final familyApiProvider = Provider<FamilyApi>((ref) {
  final api = FamilyApi(
    Uri.parse(apiBaseUrl),
    // Every call made as a device is signed with this device's own key
    // (crypto doc §2.2). An app has one device, whatever id it calls as.
    signer: (deviceId, method, target, timestamp, body) async =>
        (await ref.read(deviceProvider.future)).signRequest(
          deviceId: deviceId,
          method: method,
          pathAndQuery: target,
          timestampMs: BigInt.from(timestamp),
          body: body,
        ),
  );
  ref.onDispose(api.close);
  return api;
});
