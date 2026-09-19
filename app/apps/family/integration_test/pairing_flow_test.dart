// Runs on a device against a real backend: the whole pairing flow of crypto
// doc §7, with every role played in this one process.
//
//   dotnet run --project backend/src/Family.Api --urls http://localhost:5081
//   flutter test integration_test/pairing_flow_test.dart --flavor dev \
//     -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5081

import 'dart:convert';

import 'package:domain/domain.dart';

import 'package:family/src/api/family_api_provider.dart';
import 'package:family_data/family_data.dart';
import 'package:family/src/membership/membership.dart';
import 'package:family/src/pairing/pairing_service.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// One device: its own identity, vault, API client and view of the family.
/// Its requests are signed with its own key, as on a real phone.
class _Phone {
  _Phone() : vault = DeviceVault(store: MemorySecretStore()) {
    api = signedApi(() => device);
    service = PairingService(api, platform: 'test');
    addTearDown(api.close);
  }

  late final FamilyApi api;
  late final PairingService service;
  final DeviceVault vault;
  late Device device;
  late Membership membership;
  late Keyring keyring;

  Future<void> boot() async => device = await vault.loadOrCreate();

  /// Shows a code, lets [admitter] scan it, then collects the admission.
  Future<void> joinVia(
    _Phone admitter,
    NewDeviceFor forWhom, {
    Member? existing,
  }) async {
    final session = PairingSession.start(device: device);
    expect(await service.checkMailbox(session, device), isNull);

    final (updated, _) = await admitter.service.addDevice(
      membership: admitter.membership,
      device: admitter.device,
      keyring: admitter.keyring,
      code: session.code,
      forWhom: forWhom,
      existing: existing,
    );
    admitter.membership = updated;

    membership = (await service.checkMailbox(session, device))!;
    keyring = await service.loadKeyring(membership, device);
  }
}

/// An API client whose requests are signed by [device] (crypto doc §2.2).
FamilyApi signedApi(Device Function() device) => FamilyApi(
  Uri.parse(apiBaseUrl),
  signer: (deviceId, method, target, timestamp, body) async =>
      device().signRequest(
        deviceId: deviceId,
        method: method,
        pathAndQuery: target,
        timestampMs: BigInt.from(timestamp),
        body: body,
      ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(RustLib.init);

  test('a family forms: founder, other parent, child tablet', () async {
    // The founder creates the family and holds both keys.
    final founder = _Phone();
    await founder.boot();
    final (membership, keyring) = await founder.service.createFamily(
      device: founder.device,
      name: 'Integration family',
      timeZone: 'Europe/Stockholm',
    );
    founder.membership = membership;
    founder.keyring = keyring;
    expect(founder.membership.isParent, isTrue);

    // The other parent joins and gets both keys.
    final partner = _Phone();
    await partner.boot();
    await partner.joinVia(founder, NewDeviceFor.otherParent);
    expect(partner.membership.familyId, founder.membership.familyId);
    expect(partner.membership.isParent, isTrue);
    expect(partner.keyring.contains(group: adultsGroup, epoch: 0), isTrue);

    // Then a child's tablet: it gets `all` but not `adults`.
    final tablet = _Phone();
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
    partner.membership = await partner.service.refreshTrust(partner.membership);
    final learned = partner.membership.trusted.firstWhere(
      (d) => d.deviceId == tablet.membership.deviceId,
    );
    expect(learned.kemKey, tablet.device.kemPublicKey);

    // After a restart the founder rebuilds its keyring from its self-grants.
    final rebuilt = await founder.service.loadKeyring(
      founder.membership,
      founder.device,
    );
    expect(rebuilt.contains(group: adultsGroup, epoch: 0), isTrue);
  });

  test('a child device cannot add devices', () async {
    final founder = _Phone();
    await founder.boot();
    final (membership, keyring) = await founder.service.createFamily(
      device: founder.device,
      name: 'Integration family 2',
      timeZone: 'Europe/Stockholm',
    );
    founder.membership = membership;
    founder.keyring = keyring;
    final tablet = _Phone();
    await tablet.boot();
    await tablet.joinVia(founder, NewDeviceFor.newChild);

    final another = _Phone();
    await another.boot();
    await expectLater(
      tablet.service.addDevice(
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
    final founder = _Phone();
    await founder.boot();
    final (membership, _) = await founder.service.createFamily(
      device: founder.device,
      name: 'Integration family 3',
      timeZone: 'Europe/Stockholm',
    );
    await store.save(membership);
    final loaded = (await store.load())!;
    expect(loaded.deviceId, membership.deviceId);
    expect(loaded.trusted.single.signingKey, founder.device.signingPublicKey);
  });

  test('a request signed with another key is refused', () async {
    final founder = _Phone();
    await founder.boot();
    final (membership, _) = await founder.service.createFamily(
      device: founder.device,
      name: 'Integration family 4',
      timeZone: 'Europe/Stockholm',
    );

    // Someone who knows the founder's device id but not its key.
    final impostor = signedApi(Device.generate);
    addTearDown(impostor.close);
    await expectLater(
      impostor.grants(asDevice: membership.deviceId),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    // The real device still gets in.
    expect(await founder.api.grants(asDevice: membership.deviceId), isNotEmpty);
  });

  test('a device joins a child already in the family', () async {
    final founder = _Phone();
    await founder.boot();
    final (membership, keyring) = await founder.service.createFamily(
      device: founder.device,
      name: 'Integration family 5',
      timeZone: 'Europe/Stockholm',
    );
    founder.membership = membership;
    founder.keyring = keyring;
    // Entered on day one, without a phone.
    final majaId = await founder.api.createMember(
      asDevice: membership.deviceId,
      role: MemberRole.child,
    );

    final tablet = _Phone();
    await tablet.boot();
    await tablet.joinVia(
      founder,
      NewDeviceFor.existing,
      existing: Member(id: majaId, displayName: 'Maja', role: MemberRole.child),
    );
    expect(tablet.membership.memberId, majaId);
    expect(tablet.membership.isParent, isFalse);
    expect(tablet.keyring.contains(group: adultsGroup, epoch: 0), isFalse);
  });
}
