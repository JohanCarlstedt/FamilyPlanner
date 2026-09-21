import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/device_providers.dart';
import 'server_address.dart';

final familyApiProvider = Provider<FamilyApi>((ref) {
  // Where the backend lives: the compiled default until this install pairs,
  // and the address it paired against ever after (server_address.dart).
  // Watched, so choosing a server during setup rebuilds the client and
  // closes the old one.
  final api = FamilyApi(
    ref.watch(serverProvider),
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
