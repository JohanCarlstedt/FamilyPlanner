// Runs on a device against a real backend: the whole pairing flow of crypto
// doc §7, with every role played in this one process.
//
//   dotnet run --project backend/src/Family.Api --urls http://localhost:5081
//   flutter test integration_test/pairing_flow_test.dart --flavor dev \
//     -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5081

import 'dart:convert';

import 'package:family/src/api/family_api_provider.dart';
import 'package:family_data/family_data.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family/src/pairing/pairing_service.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// One device: its own identity, vault and view of the family.
class _Phone {
  _Phone(this.service) : vault = DeviceVault(store: MemorySecretStore());

  final PairingService service;
  final DeviceVault vault;
  late Device device;
  late Membership membership;
  late Keyring keyring;

  Future<void> boot() async => device = await vault.loadOrCreate();

  /// Shows a code, lets [admitter] scan it, then collects the admission.
  Future<void> joinVia(_Phone admitter, NewDeviceFor forWhom) async {
    final session = PairingSession.start(device: device);
    expect(await service.checkMailbox(session, device), isNull);

    final (updated, _) = await admitter.service.addDevice(
      membership: admitter.membership,
      device: admitter.device,
      keyring: admitter.keyring,
      code: session.code,
      forWhom: forWhom,
    );
    admitter.membership = updated;

    membership = (await service.checkMailbox(session, device))!;
    keyring = await service.loadKeyring(membership, device);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FamilyApi api;
  late PairingService service;

  setUpAll(() async {
    await RustLib.init();
    api = FamilyApi(Uri.parse(apiBaseUrl));
    service = PairingService(api, platform: 'test');
  });
  tearDownAll(() => api.close());

  test('a family forms: founder, other parent, child tablet', () async {
    // The founder creates the family and holds both keys.
    final founder = _Phone(service);
    await founder.boot();
    final (membership, keyring) = await service.createFamily(
      device: founder.device,
      name: 'Integration family',
      timeZone: 'Europe/Stockholm',
    );
    founder.membership = membership;
    founder.keyring = keyring;
    expect(founder.membership.isParent, isTrue);

    // The other parent joins and gets both keys.
    final partner = _Phone(service);
    await partner.boot();
    await partner.joinVia(founder, NewDeviceFor.otherParent);
    expect(partner.membership.familyId, founder.membership.familyId);
    expect(partner.membership.isParent, isTrue);
    expect(partner.keyring.contains(group: adultsGroup, epoch: 0), isTrue);

    // Then a child's tablet: it gets `all` but not `adults`.
    final tablet = _Phone(service);
    await tablet.boot();
    await tablet.joinVia(founder, NewDeviceFor.newChild);
    expect(tablet.membership.isParent, isFalse);
    expect(tablet.keyring.contains(group: allGroup, epoch: 0), isTrue);
    expect(tablet.keyring.contains(group: adultsGroup, epoch: 0), isFalse);

    final slot = ObjectSlot(
      objectType: 'event',
      id: 'e1',
      familyId: founder.membership.familyId,
    );
    final dinner = seal(
      payload: utf8.encode('Dinner 18:00'),
      object: slot,
      audiences: const [Audience(group: allGroup, epoch: 0)],
      keyring: founder.keyring,
    );
    final gifts = seal(
      payload: utf8.encode('gift ideas'),
      object: slot,
      audiences: const [Audience(group: adultsGroup, epoch: 0)],
      keyring: founder.keyring,
    );
    expect(
      utf8.decode(open(envelope: dinner, keyring: tablet.keyring).payload),
      'Dinner 18:00',
    );
    expect(
      () => open(envelope: gifts, keyring: tablet.keyring),
      throwsA(
        isA<CryptoException>().having(
          (e) => e.kind,
          'kind',
          CryptoErrorKind.noAccess,
        ),
      ),
    );
    expect(
      utf8.decode(open(envelope: gifts, keyring: partner.keyring).payload),
      'gift ideas',
    );

    // The partner joined before the tablet existed, so it learns of it only
    // from the founder's endorsement.
    expect(
      partner.membership.trusted.map((d) => d.deviceId),
      isNot(contains(tablet.membership.deviceId)),
    );
    partner.membership = await service.refreshTrust(partner.membership);
    final learned = partner.membership.trusted.firstWhere(
      (d) => d.deviceId == tablet.membership.deviceId,
    );
    expect(learned.kemKey, tablet.device.kemPublicKey);

    // After a restart the founder rebuilds its keyring from its self-grants.
    final rebuilt = await service.loadKeyring(
      founder.membership,
      founder.device,
    );
    expect(rebuilt.contains(group: adultsGroup, epoch: 0), isTrue);
  });

  test('a child device cannot add devices', () async {
    final founder = _Phone(service);
    await founder.boot();
    final (membership, keyring) = await service.createFamily(
      device: founder.device,
      name: 'Integration family 2',
      timeZone: 'Europe/Stockholm',
    );
    founder.membership = membership;
    founder.keyring = keyring;
    final tablet = _Phone(service);
    await tablet.boot();
    await tablet.joinVia(founder, NewDeviceFor.newChild);

    final another = _Phone(service);
    await another.boot();
    await expectLater(
      service.addDevice(
        membership: tablet.membership,
        device: tablet.device,
        keyring: tablet.keyring,
        code: PairingSession.start(device: another.device).code,
        forWhom: NewDeviceFor.myself,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('stored membership round-trips', () async {
    final store = MembershipStore(MemorySecretStore());
    final founder = _Phone(service);
    await founder.boot();
    final (membership, _) = await service.createFamily(
      device: founder.device,
      name: 'Integration family 3',
      timeZone: 'Europe/Stockholm',
    );
    await store.save(membership);
    final loaded = (await store.load())!;
    expect(loaded.deviceId, membership.deviceId);
    expect(loaded.trusted.single.signingKey, founder.device.signingPublicKey);
  });
}
