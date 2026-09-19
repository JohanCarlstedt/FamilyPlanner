// Runs on a device against a real backend: a helper paired for one child
// (spec §2, crypto doc §3 `adults+helper:{id}`), what they can read, and
// their access winding up when the time is over.
//
//   flutter test integration_test/helper_flow_test.dart --flavor dev \
//     -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5081

import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:family/src/api/family_api_provider.dart';
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
    dir = await (await getTemporaryDirectory()).createTemp('helper');
  });
  tearDownAll(() => dir.delete(recursive: true));

  FamilyApi apiFor(Device device) {
    final api = FamilyApi(
      Uri.parse(apiBaseUrl),
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

  Future<FamilyStore> openStore(
    String name,
    FamilyApi api,
    String familyId,
    String deviceId,
    String memberId,
    Keyring keys,
  ) async {
    final key = Uint8List.fromList(List.generate(32, (i) => i + name.length));
    final store = FamilyStore(
      cache: CacheDatabase(openEncrypted(File('${dir.path}/$name-c.db'), key)),
      queue: QueueDatabase(openEncrypted(File('${dir.path}/$name-q.db'), key)),
      api: api,
      familyId: familyId,
      deviceId: deviceId,
      keyring: () => keys,
      memberId: memberId,
    );
    return store;
  }

  EventPayload event(String title, List<String> who) => EventPayload.write(
    title: title,
    kind: EventKind.activity,
    localStart: DateTime.utc(2026, 9, 22, 17, 30),
    duration: const Duration(hours: 1),
    timeZone: 'Europe/Stockholm',
    participantIds: who,
  );

  test('removing a device never hands the family key to a helper', () async {
    final annaDevice = Device.generate();
    final annaApi = apiFor(annaDevice);
    final annaService = PairingService(annaApi, platform: 'test');
    final (anna, annaKeys) = await annaService.createFamily(
      device: annaDevice,
      name: 'Rotation family',
      timeZone: 'Europe/Stockholm',
    );
    final annaMember = Member(
      id: anna.memberId,
      displayName: 'Anna',
      role: MemberRole.parent,
    );

    // A babysitter, and a second phone of Anna's that is later removed.
    final saraDevice = Device.generate();
    final saraApi = apiFor(saraDevice);
    final saraService = PairingService(saraApi, platform: 'test');
    final saraSession = PairingSession.start(device: saraDevice);
    final (afterSara, sara) = await annaService.addDevice(
      membership: anna,
      device: annaDevice,
      keyring: annaKeys,
      code: saraSession.code,
      forWhom: NewDeviceFor.helper,
      members: [annaMember],
    );
    final saraMembership = (await saraService.checkMailbox(
      saraSession,
      saraDevice,
    ))!;

    final spareDevice = Device.generate();
    final spareApi = apiFor(spareDevice);
    final spareService = PairingService(spareApi, platform: 'test');
    final spareSession = PairingSession.start(device: spareDevice);
    final (afterSpare, _) = await annaService.addDevice(
      membership: afterSara,
      device: annaDevice,
      keyring: annaKeys,
      code: spareSession.code,
      forWhom: NewDeviceFor.myself,
      members: [annaMember],
    );
    final spare = (await spareService.checkMailbox(spareSession, spareDevice))!;

    await annaService.removeDevice(
      membership: afterSpare,
      device: annaDevice,
      keyring: annaKeys,
      deviceId: spare.deviceId,
      members: [
        annaMember,
        Member(id: sara, displayName: 'Sara', role: MemberRole.helper),
      ],
    );

    // The rotation reaches Anna and the helper's own group, never the
    // helper's phone with the family's key (crypto doc §3).
    final saraKeys = await saraService.loadKeyring(saraMembership, saraDevice);
    expect(saraKeys.latestEpoch(group: allGroup), isNull);
    expect(saraKeys.latestEpoch(group: adultsGroup), isNull);
    expect(saraKeys.latestEpoch(group: helperGroup(sara)), 1);
    expect(annaKeys.latestEpoch(group: allGroup), 1);
    expect(annaKeys.latestEpoch(group: adultsGroup), 1);
    expect(annaKeys.latestEpoch(group: helperGroup(sara)), 1);
  });

  test('a helper sees their child\'s calendar, then loses access', () async {
    final founderDevice = Device.generate();
    final founderApi = apiFor(founderDevice);
    final founderService = PairingService(founderApi, platform: 'test');
    final (founder, founderKeys) = await founderService.createFamily(
      device: founderDevice,
      name: 'Helper family',
      timeZone: 'Europe/Stockholm',
    );
    final maja = await founderApi.createMember(
      asDevice: founder.deviceId,
      role: MemberRole.child,
    );
    final erik = await founderApi.createMember(
      asDevice: founder.deviceId,
      role: MemberRole.child,
    );

    // Sara babysits Maja: her phone shows a code, the founder scans it.
    final saraDevice = Device.generate();
    final saraApi = apiFor(saraDevice);
    final saraService = PairingService(saraApi, platform: 'test');
    final session = PairingSession.start(device: saraDevice);
    final (afterPairing, sara) = await founderService.addDevice(
      membership: founder,
      device: founderDevice,
      keyring: founderKeys,
      code: session.code,
      forWhom: NewDeviceFor.helper,
      members: [
        Member(
          id: founder.memberId,
          displayName: 'Anna',
          role: MemberRole.parent,
        ),
      ],
    );
    final saraMembership = (await saraService.checkMailbox(
      session,
      saraDevice,
    ))!;
    final saraKeys = await saraService.loadKeyring(saraMembership, saraDevice);
    expect(saraMembership.isParent, isFalse);
    expect(saraKeys.latestEpoch(group: allGroup), isNull);
    expect(saraKeys.latestEpoch(group: helperGroup(sara)), 0);

    final founderStore = await openStore(
      'founder',
      founderApi,
      founder.familyId,
      founder.deviceId,
      founder.memberId,
      founderKeys,
    );
    await founderStore.saveHelperGrant(
      HelperGrantPayload.write(
        helperMemberId: sara,
        childIds: [maja],
        until: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    await founderStore.saveEvent(event('Swimming', [maja]));
    await founderStore.saveEvent(event('Chess club', [erik]));
    await founderStore.sync();

    final saraStore = await openStore(
      'sara',
      saraApi,
      saraMembership.familyId,
      saraMembership.deviceId,
      saraMembership.memberId,
      saraKeys,
    );
    await saraStore.sync();
    expect(
      [for (final (_, e) in await saraStore.watchEvents().first) e.title],
      ['Swimming'],
    );

    // Time's up: winding up revokes her phone.
    final grant = (await founderStore.watchHelperGrants().first).single;
    await founderStore.saveHelperGrant(
      HelperGrantPayload.write(
        existing: grant.$2.payload,
        helperMemberId: sara,
        childIds: [maja],
        until: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
      id: grant.$1,
    );
    expect(
      await founderService.expireHelpers(
        membership: afterPairing,
        store: founderStore,
      ),
      1,
    );
    await expectLater(
      saraStore.sync(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    await founderStore.sync();
    await founderStore.saveEvent(event('Swimming again', [maja]));
    expect(
      await founderStore.watchHelperGrants().first.then(
        (g) => g.single.$2.activeAt(DateTime.now().toUtc()),
      ),
      isFalse,
    );
  });
}
