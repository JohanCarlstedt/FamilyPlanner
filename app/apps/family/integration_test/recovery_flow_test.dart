// Runs on a device against a real backend: losing every phone of a parent
// and coming back from the twelve words (crypto doc §7.3).
//
//   flutter test integration_test/recovery_flow_test.dart --flavor dev \
//     -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5081

import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:family/src/api/server_address.dart';
import 'package:family/src/pairing/pairing_service.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(RustLib.init);

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

  test('a parent loses their phone and comes back from the words', () async {
    // Anna founds the family; Erik joins.
    final annaDevice = Device.generate();
    final annaService = PairingService(apiFor(annaDevice), platform: 'test');
    var (anna, annaKeys) = await annaService.createFamily(
      device: annaDevice,
      name: 'Recovery family',
      timeZone: 'Europe/Stockholm',
    );
    final erikDevice = Device.generate();
    final erikService = PairingService(apiFor(erikDevice), platform: 'test');
    final session = PairingSession.start(device: erikDevice);
    (anna, _) = await annaService.addDevice(
      membership: anna,
      device: annaDevice,
      keyring: annaKeys,
      code: session.code,
      forWhom: NewDeviceFor.otherParent,
    );
    var erik = (await erikService.checkMailbox(session, erikDevice))!;
    final erikKeys = await erikService.loadKeyring(erik, erikDevice);

    // Anna writes down her twelve words.
    final words = recoveryWords();
    anna = await annaService.createRecoveryKit(
      membership: anna,
      device: annaDevice,
      keyring: annaKeys,
      words: words,
    );

    // Her phone is gone. A new one, and the words.
    final phone = Device.generate();
    final phoneApi = apiFor(phone);
    final phoneService = PairingService(phoneApi, platform: 'test');
    final (recovered, kitDeviceId) = await phoneService.recover(
      words: words,
      phone: phone,
      kitApi: apiFor,
    );
    expect(recovered.familyId, anna.familyId);
    expect(recovered.memberId, anna.memberId);
    final phoneKeys = await phoneService.loadKeyring(recovered, phone);
    expect(phoneKeys.latestEpoch(group: adultsGroup), 0);

    // Step 4: the words may have been seen, so everything moves on without
    // the kit's device.
    final after = await phoneService.removeDevices(
      membership: recovered,
      device: phone,
      keyring: phoneKeys,
      deviceIds: {kitDeviceId},
      members: [
        Member(id: anna.memberId, displayName: 'Anna', role: MemberRole.parent),
        Member(id: erik.memberId, displayName: 'Erik', role: MemberRole.parent),
      ],
    );
    expect(phoneKeys.latestEpoch(group: adultsGroup), 1);

    // Erik follows: he learns of the phone and takes the new keys.
    erik = await erikService.refreshTrust(erik);
    await erikService.acceptNewGrants(erik, erikDevice, erikKeys);
    expect(erikKeys.latestEpoch(group: adultsGroup), 1);
    final secret = seal(
      payload: utf8.encode('Present till Maja'),
      object: ObjectSlot(
        objectType: 'event',
        id: 'e1',
        familyId: anna.familyId,
      ),
      audiences: const [Audience(group: adultsGroup, epoch: 1)],
      keyring: phoneKeys,
    );
    expect(
      utf8.decode(open(envelope: secret, keyring: erikKeys).payload),
      'Present till Maja',
    );

    // The old words stop working; new ones take their place.
    await expectLater(
      phoneService.recover(
        words: words,
        phone: Device.generate(),
        kitApi: apiFor,
      ),
      throwsA(isA<RecoveryNotFound>()),
    );
    final fresh = recoveryWords();
    await phoneService.createRecoveryKit(
      membership: after,
      device: phone,
      keyring: phoneKeys,
      words: fresh,
    );
    expect(fresh, isNot(words));
  });
}
