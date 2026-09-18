// Runs on a device against a real backend: two family devices share events
// and names through the encrypted store (architecture doc §7), with the
// Android build of SQLite3 Multiple Ciphers.
//
//   flutter test integration_test/sync_flow_test.dart --flavor dev \
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

  late FamilyApi api;
  late PairingService service;
  late Directory dir;

  setUpAll(() async {
    await RustLib.init();
    api = FamilyApi(Uri.parse(apiBaseUrl));
    service = PairingService(api, platform: 'test');
    dir = await (await getTemporaryDirectory()).createTemp('sync');
  });
  tearDownAll(() async {
    api.close();
    await dir.delete(recursive: true);
  });

  Future<FamilyStore> openStore(
    String name,
    String familyId,
    String deviceId,
    Keyring keys,
  ) async {
    final key = Uint8List.fromList(List.generate(32, (i) => i + name.length));
    return FamilyStore(
      cache: CacheDatabase(
        openEncrypted(File('${dir.path}/$name-cache.db'), key),
      ),
      queue: QueueDatabase(
        openEncrypted(File('${dir.path}/$name-queue.db'), key),
      ),
      api: api,
      familyId: familyId,
      deviceId: deviceId,
      keyring: () => keys,
    );
  }

  test('a parent adds events; the child tablet sees the family ones', () async {
    // Founder, then a child's tablet paired to it.
    final founderDevice = Device.generate();
    final (founder, founderKeys) = await service.createFamily(
      device: founderDevice,
      name: 'Sync family',
      timeZone: 'Europe/Stockholm',
    );
    final tabletDevice = Device.generate();
    final session = PairingSession.start(device: tabletDevice);
    final (_, childMemberId) = await service.addDevice(
      membership: founder,
      device: founderDevice,
      keyring: founderKeys,
      code: session.code,
      forWhom: NewDeviceFor.newChild,
    );
    final tablet = (await service.checkMailbox(session, tabletDevice))!;
    final tabletKeys = await service.loadKeyring(tablet, tabletDevice);

    final parentStore = await openStore(
      'parent',
      founder.familyId,
      founder.deviceId,
      founderKeys,
    );
    final tabletStore = await openStore(
      'tablet',
      tablet.familyId,
      tablet.deviceId,
      tabletKeys,
    );

    // Names, then one family event and one parents-only event.
    await parentStore.saveProfile(
      founder.memberId,
      MemberProfile.write(
        displayName: 'Anna',
        role: MemberRole.parent,
        color: '#0072B2',
      ),
    );
    await parentStore.saveProfile(
      childMemberId,
      MemberProfile.write(
        displayName: 'Maja',
        role: MemberRole.child,
        color: '#009E73',
      ),
    );
    EventPayload event(String title, EventVisibility visibility) =>
        EventPayload.write(
          title: title,
          kind: EventKind.activity,
          localStart: DateTime.utc(2026, 9, 22, 17, 30),
          duration: const Duration(minutes: 75),
          timeZone: 'Europe/Stockholm',
          visibility: visibility,
          participantIds: [childMemberId],
          responsibleMemberId: founder.memberId,
        );
    await parentStore.saveEvent(
      event('Football training', EventVisibility.family),
    );
    await parentStore.saveEvent(
      event('Birthday present', EventVisibility.parentsOnly),
    );
    final pushed = await parentStore.sync();
    expect(pushed.pushed, 4);

    final pulled = await tabletStore.sync();
    expect(pulled.pulled, 4);
    final titles = [
      for (final (_, e) in await tabletStore.watchEvents().first) e.title,
    ];
    expect(titles, ['Football training']);
    expect(await tabletStore.unreadableCounts(), {'noAccess': 1});

    final names = {
      for (final (_, p) in await tabletStore.watchProfiles().first)
        p.displayName,
    };
    expect(names, {'Anna', 'Maja'});

    final football = (await tabletStore.watchEvents().first).single.$2.toDomain(
      'x',
    )!;
    expect(football.responsibleMemberId, founder.memberId);
    expect(football.series.localStart, DateTime.utc(2026, 9, 22, 17, 30));
  });
}
