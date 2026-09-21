// Runs on a device against a real backend: the family thread over MLS
// (crypto doc §7.2) with the Android build of OpenMLS, between two phones
// paired the real way.
//
//   flutter test integration_test/chat_flow_test.dart --flavor dev \
//     -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5081

import 'dart:io';
import 'dart:typed_data';

import 'package:family/src/api/server_address.dart';
import 'package:family/src/pairing/pairing_service.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    await RustLib.init();
    dir = await (await getTemporaryDirectory()).createTemp('chat');
  });
  tearDownAll(() => dir.delete(recursive: true));

  FamilyApi apiFor(Device device) {
    final api = FamilyApi(
      defaultServer,
      signer: (deviceId, method, target, timestamp, body) async =>
          device.signRequest(
            deviceId: deviceId,
            method: method,
            pathAndQuery: target,
            timestampMs: BigInt.from(timestamp),
            body: body,
          ),
    );
    addTearDown(api.close);
    return api;
  }

  QueueDatabase openDb(String name) {
    final db = QueueDatabase(
      openEncrypted(
        File('${dir.path}/$name.db'),
        Uint8List.fromList(List.generate(32, (i) => i + name.length)),
      ),
    );
    addTearDown(db.close);
    return db;
  }

  test('two parents talk, and it survives a restart', () async {
    final annaDevice = Device.generate();
    final annaApi = apiFor(annaDevice);
    final annaService = PairingService(annaApi, platform: 'test');
    var (anna, annaKeys) = await annaService.createFamily(
      device: annaDevice,
      name: 'Chat family',
      timeZone: 'Europe/Stockholm',
    );

    final erikDevice = Device.generate();
    final erikApi = apiFor(erikDevice);
    final erikService = PairingService(erikApi, platform: 'test');
    final session = PairingSession.start(device: erikDevice);
    (anna, _) = await annaService.addDevice(
      membership: anna,
      device: annaDevice,
      keyring: annaKeys,
      code: session.code,
      forWhom: NewDeviceFor.otherParent,
    );
    final erik = (await erikService.checkMailbox(session, erikDevice))!;

    FamilyChat chatFor(
      Device device,
      FamilyApi api,
      String id,
      List<TrustedDevice> Function() trusted,
      QueueDatabase db,
    ) => FamilyChat(
      db: db,
      api: api,
      familyId: anna.familyId,
      deviceId: id,
      device: device,
      trusted: trusted,
    );

    final annaChat = chatFor(
      annaDevice,
      annaApi,
      anna.deviceId,
      () => anna.trustedSigners,
      openDb('anna'),
    );
    var erikDb = openDb('erik');
    var erikChat = chatFor(
      erikDevice,
      erikApi,
      erik.deviceId,
      () => erik.trustedSigners,
      erikDb,
    );

    // Erik publishes key packages; Anna starts the thread and adds him.
    await erikChat.sync();
    await annaChat.sync();
    await annaChat.reconcile(
      devices: {anna.deviceId, erik.deviceId},
      mayStart: true,
    );
    await erikChat.sync();
    expect(erikChat.hasThread, isTrue);

    await annaChat.send('Middag kl 18');
    expect([for (final m in await erikChat.sync()) m.text], ['Middag kl 18']);
    await erikChat.send('Jag handlar på vägen');
    expect(
      [for (final m in await annaChat.sync()) m.text],
      ['Jag handlar på vägen'],
    );

    // Erik's phone restarts: state and history come back from its database.
    await erikDb.close();
    erikDb = openDb('erik');
    erikChat = chatFor(
      erikDevice,
      erikApi,
      erik.deviceId,
      () => erik.trustedSigners,
      erikDb,
    );
    expect(
      [for (final m in await erikChat.watch().first) m.text],
      ['Middag kl 18', 'Jag handlar på vägen'],
    );
    await annaChat.send('Toppen');
    expect([for (final m in await erikChat.sync()) m.text], ['Toppen']);
  });
}
