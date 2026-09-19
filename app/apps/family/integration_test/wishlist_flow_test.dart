// Runs on a device against a real backend: a claim on a child's wishlist
// (spec §3 "Wishlists", crypto doc §3 `wishlist:{id}:observers`) reaches the
// family but not the child whose list it is — their device is never given
// the key.
//
//   flutter test integration_test/wishlist_flow_test.dart --flavor dev \
//     -d <device> --dart-define=API_BASE_URL=http://10.0.2.2:5081

import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:family/src/api/family_api_provider.dart';
import 'package:family/src/membership/membership.dart';
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
    dir = await (await getTemporaryDirectory()).createTemp('wishlist');
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
    Membership membership,
    Keyring keys,
  ) async {
    final key = Uint8List.fromList(List.generate(32, (i) => i + name.length));
    return FamilyStore(
      cache: CacheDatabase(openEncrypted(File('${dir.path}/$name-c.db'), key)),
      queue: QueueDatabase(openEncrypted(File('${dir.path}/$name-q.db'), key)),
      api: api,
      familyId: membership.familyId,
      deviceId: membership.deviceId,
      keyring: () => keys,
      memberId: membership.memberId,
    );
  }

  test('the child whose list it is never gets the key to a claim', () async {
    final annaDevice = Device.generate();
    final annaApi = apiFor(annaDevice);
    final annaService = PairingService(annaApi, platform: 'test');
    final (anna, annaKeys) = await annaService.createFamily(
      device: annaDevice,
      name: 'Wishlist family',
      timeZone: 'Europe/Stockholm',
    );

    // Maja's tablet joins as a child.
    final tabletDevice = Device.generate();
    final tabletApi = apiFor(tabletDevice);
    final tabletService = PairingService(tabletApi, platform: 'test');
    final session = PairingSession.start(device: tabletDevice);
    final (afterPairing, majaId) = await annaService.addDevice(
      membership: anna,
      device: annaDevice,
      keyring: annaKeys,
      code: session.code,
      forWhom: NewDeviceFor.newChild,
      members: [
        Member(id: anna.memberId, displayName: 'Anna', role: MemberRole.parent),
      ],
    );
    final tablet = (await tabletService.checkMailbox(session, tabletDevice))!;
    final tabletKeys = await tabletService.loadKeyring(tablet, tabletDevice);

    final members = [
      Member(id: anna.memberId, displayName: 'Anna', role: MemberRole.parent),
      Member(
        id: majaId,
        displayName: 'Maja',
        role: MemberRole.child,
        tier: MaturityTier.kid,
      ),
    ];
    final annaStore = await openStore('anna', annaApi, afterPairing, annaKeys);
    final tabletStore = await openStore(
      'tablet',
      tabletApi,
      tablet,
      tabletKeys,
    );

    final maja = await annaStore.savePerson(
      PersonPayload.write(name: 'Maja', memberId: majaId),
      timeZone: 'Europe/Stockholm',
    );
    final list = await annaStore.saveWishlist(
      WishlistPayload.write(personId: maja, name: 'Födelsedag'),
    );
    final bike = await annaStore.saveWishlistItem(
      WishlistItemPayload.write(wishlistId: list, title: 'Cykel'),
    );

    // Anna can't claim it before the group everyone-but-Maja exists.
    await expectLater(
      annaStore.claimWish(bike, ownerMemberId: majaId),
      throwsA(isA<MissingObserversKey>()),
    );
    await annaService.ensureWishlistObservers(
      membership: afterPairing,
      device: annaDevice,
      keyring: annaKeys,
      ownerMemberId: majaId,
      members: members,
    );
    await annaStore.claimWish(bike, ownerMemberId: majaId);
    await annaStore.sync();
    await tabletStore.sync();

    // The tablet holds the family key and reads the list, but the claim's
    // group was never granted to it.
    expect(tabletKeys.latestEpoch(group: allGroup), 0);
    expect(
      tabletKeys.latestEpoch(group: wishlistObserversGroup(majaId)),
      isNull,
    );
    expect(
      [for (final (_, i) in await tabletStore.watchWishlistItems().first)
        i.title],
      ['Cykel'],
    );
    expect(await tabletStore.watchClaimsFor(majaId).first, isEmpty);
    expect(
      (await annaStore.watchClaimsFor(anna.memberId).first).single.$2.itemId,
      bike,
    );

    // A second parent's phone is added later and can read it at once.
    final erikDevice = Device.generate();
    final erikApi = apiFor(erikDevice);
    final erikService = PairingService(erikApi, platform: 'test');
    final erikSession = PairingSession.start(device: erikDevice);
    final (_, erikId) = await annaService.addDevice(
      membership: afterPairing,
      device: annaDevice,
      keyring: annaKeys,
      code: erikSession.code,
      forWhom: NewDeviceFor.otherParent,
      members: members,
    );
    final erik = (await erikService.checkMailbox(erikSession, erikDevice))!;
    final erikKeys = await erikService.loadKeyring(erik, erikDevice);
    expect(erikId, isNot(majaId));
    expect(erikKeys.latestEpoch(group: wishlistObserversGroup(majaId)), 0);
    final erikStore = await openStore('erik', erikApi, erik, erikKeys);
    await erikStore.sync();
    expect(
      (await erikStore.watchClaimsFor(erik.memberId).first).single.$2.claimedBy,
      anna.memberId,
    );
  });
}
