import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timezone/data/latest.dart' as tzdata;

import 'support/harness.dart';

EventPayload _event(
  String title, {
  EventVisibility? visibility,
  Payload? existing,
}) => EventPayload.write(
  existing: existing,
  title: title,
  kind: EventKind.activity,
  localStart: DateTime.utc(2026, 9, 22, 17, 30),
  duration: const Duration(minutes: 75),
  timeZone: 'Europe/Stockholm',
  visibility: visibility ?? EventVisibility.family,
);

void main() {
  late Directory dir;
  late FakeServer server;
  late Keyring parentKeys;
  late Keyring childKeys;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initRustForHost();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('family_data');
    server = FakeServer();
    parentKeys = Keyring()
      ..generate(group: allGroup, epoch: 0)
      ..generate(group: adultsGroup, epoch: 0)
      // Everyone but the child: what a claim on their list is sealed to.
      ..generate(group: wishlistObserversGroup('member-child'), epoch: 0)
      // Everyone's passwords, and this parent's own.
      ..generate(group: familyPasswordsGroup, epoch: 0)
      ..generate(group: memberPasswordsGroup('member-parent'), epoch: 0);
    // The child holds `all` and the family's passwords, delivered the way
    // a grant would; never `adults`, and never a parent's own passwords.
    final device = Device.generate();
    childKeys = Keyring();
    for (final group in [allGroup, familyPasswordsGroup]) {
      childKeys.acceptGrant(
        grant: parentKeys.grant(
          group: group,
          epoch: 0,
          familyId: 'fam-1',
          granter: device,
          fromDevice: 'parent',
          toDevice: 'child',
          toKemKey: device.kemPublicKey,
        ),
        familyId: 'fam-1',
        me: device,
        myDevice: 'child',
        trusted: [
          TrustedDevice(
            deviceId: 'parent',
            signingKey: device.signingPublicKey,
          ),
        ],
      );
    }
  });

  tearDown(() => dir.delete(recursive: true));

  Future<TestDevice> device(String name, Keyring keys) =>
      TestDevice.open(dir: dir, name: name, api: server, keyring: keys);

  group('encrypted at rest', () {
    test('the database file is not readable SQLite without the key', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveEvent(_event('Football'));
      await parent.close();

      final header = File('${dir.path}/parent-cache.db')
          .readAsBytesSync()
          .take(16)
          .toList();
      expect(
        String.fromCharCodes(header),
        isNot(startsWith('SQLite format 3')),
      );
    });

    test('a wrong key fails at open, not at the first query', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveEvent(_event('Football'));
      await parent.close();

      final wrong = CacheDatabase(
        openEncrypted(File('${dir.path}/parent-cache.db'), Uint8List(32)),
      );
      await expectLater(
        wrong.select(wrong.cachedObjects).get(),
        throwsA(anything),
      );
      await wrong.close();
    });
  });

  test('a file from another key is told apart before opening', () async {
    final parent = await device('parent', parentKeys);
    await parent.store.saveEvent(_event('Football'));
    await parent.close();
    final file = File('${dir.path}/parent-cache.db');
    final key = Uint8List.fromList(
      List.generate(32, (i) => (i * 7 + 'parent'.length) & 0xff),
    );
    expect(opensWith(file, key), isTrue);
    expect(opensWith(file, Uint8List(32)), isFalse);
    expect(opensWith(File('${dir.path}/none.db'), key), isTrue);
  });

  group('local first', () {
    test('a write shows at once, before any sync', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveEvent(_event('Football'));

      final events = await parent.store.watchEvents().first;
      expect(events.single.$2.title, 'Football');
      await parent.close();
    });

    test('sync uploads the queue and another device reads it', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      await parent.store.saveEvent(_event('Football'));

      final report = await parent.store.sync();
      expect(report.pushed, 1);
      expect(
        await parent.queue.select(parent.queue.queuedCommands).get(),
        isEmpty,
      );

      await other.store.sync();
      final events = await other.store.watchEvents().first;
      expect(events.single.$2.title, 'Football');
      await parent.close();
      await other.close();
    });

    test('the server only ever holds ciphertext', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveEvent(_event('Secret surprise party'));
      await parent.store.sync();

      final stored = server.objects.values.single.envelope!;
      expect(String.fromCharCodes(stored), isNot(contains('Secret')));
      await parent.close();
    });
  });

  group('audiences', () {
    test(
      'a child device receives parents-only events but cannot read them',
      () async {
        final parent = await device('parent', parentKeys);
        final child = await device('child', childKeys);
        await parent.store.saveEvent(_event('Dinner'));
        await parent.store.saveEvent(
          _event('Gift shopping', visibility: EventVisibility.parentsOnly),
        );
        await parent.store.sync();

        await child.store.sync();
        final titles = [
          for (final (_, e) in await child.store.watchEvents().first) e.title,
        ];
        expect(titles, ['Dinner']);
        expect(await child.store.unreadableCounts(), {'noAccess': 1});
        await parent.close();
        await child.close();
      },
    );

    test('objects become readable once the key arrives', () async {
      final parent = await device('parent', parentKeys);
      final laterKeys = Keyring();
      final newcomer = await device('newcomer', laterKeys);
      await parent.store.saveEvent(_event('Dinner'));
      await parent.store.sync();

      await newcomer.store.sync();
      expect(await newcomer.store.watchEvents().first, isEmpty);

      // A grant arrives later: here, simulated with the same key material.
      final device2 = Device.generate();
      laterKeys.acceptGrant(
        grant: parentKeys.grant(
          group: allGroup,
          epoch: 0,
          familyId: 'fam-1',
          granter: device2,
          fromDevice: 'parent',
          toDevice: 'newcomer',
          toKemKey: device2.kemPublicKey,
        ),
        familyId: 'fam-1',
        me: device2,
        myDevice: 'newcomer',
        trusted: [
          TrustedDevice(
            deviceId: 'parent',
            signingKey: device2.signingPublicKey,
          ),
        ],
      );
      expect(await newcomer.store.reopenUnreadable(), 1);
      expect(
        (await newcomer.store.watchEvents().first).single.$2.title,
        'Dinner',
      );
      await parent.close();
      await newcomer.close();
    });
  });

  group('a server it does not trust', () {
    test('serving one object\'s envelope under another id is caught', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      final a = await parent.store.saveEvent(_event('Dentist'));
      await parent.store.saveEvent(_event('Football'));
      await parent.store.sync();

      // Every object now comes back carrying the Dentist envelope.
      final dentist = server.objects[a]!.envelope;
      server.tamper = (o) => RemoteObject(
        id: o.id,
        kind: o.kind,
        scope: o.scope,
        envelope: dentist,
        version: o.version,
        deleted: o.deleted,
      );

      await other.store.sync();
      final titles = [
        for (final (_, e) in await other.store.watchEvents().first) e.title,
      ];
      expect(titles, [
        'Dentist',
      ], reason: 'only the genuine Dentist object opens');
      expect(await other.store.unreadableCounts(), {'damaged': 1});
      await parent.close();
      await other.close();
    });
  });

  group('offline edits and conflicts', () {
    test(
      'several offline edits of one object do not conflict with each other',
      () async {
        final parent = await device('parent', parentKeys);
        final id = await parent.store.saveEvent(_event('v1'));
        await parent.store.saveEvent(_event('v2'), id: id);
        await parent.store.saveEvent(_event('v3'), id: id);

        final report = await parent.store.sync();
        expect(report.pushed, 3);
        expect(report.rebased, 0);
        expect(server.objects[id]!.version, 3);
        await parent.close();
      },
    );

    test(
      'a lost race is resent on top of the newer version: last writer wins',
      () async {
        final parent = await device('parent', parentKeys);
        final other = await device('other', parentKeys);
        final id = await parent.store.saveEvent(_event('Football'));
        await parent.store.sync();
        await other.store.sync();

        // Both edit the same version offline; the other device syncs first.
        await other.store.saveEvent(_event('Football at 18:00'), id: id);
        await parent.store.saveEvent(_event('Football cancelled'), id: id);
        await other.store.sync();
        final report = await parent.store.sync();

        expect(report.rebased, 1);
        expect(
          await parent.queue.select(parent.queue.queuedCommands).get(),
          isEmpty,
        );
        await other.store.sync();
        final title = (await other.store.watchEvents().first).single.$2.title;
        expect(title, 'Football cancelled');
        await parent.close();
        await other.close();
      },
    );

    test('a pull never hides an edit that has not uploaded yet', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.sync();
      await other.store.sync();

      await other.store.saveEvent(_event('Newer from elsewhere'), id: id);
      await other.store.sync();

      // The parent edits offline, then pulls the other device's change
      // without having pushed its own.
      await parent.store.saveEvent(_event('Mine, not yet sent'), id: id);
      await parent.store.sync();
      // After sync the rebased edit went up and remains what the parent sees.
      expect(
        (await parent.store.watchEvents().first).single.$2.title,
        'Mine, not yet sent',
      );
      await parent.close();
      await other.close();
    });

    test('deletions sync', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.sync();
      await other.store.sync();

      await parent.store.delete(ObjectKind.event, id);
      expect(await parent.store.watchEvents().first, isEmpty);
      await parent.store.sync();
      await other.store.sync();
      expect(await other.store.watchEvents().first, isEmpty);
      await parent.close();
      await other.close();
    });
  });

  test(
    'editing through the store keeps fields this client does not know',
    () async {
      final parent = await device('parent', parentKeys);
      final future = Payload.decode(_event('Football').payload.encode())
        ..setText('carpoolNote', 'Anna drives on even weeks');
      final id = await parent.store.saveEvent(EventPayload.read(future));

      final stored = await parent.store.payloadOf(id);
      await parent.store.saveEvent(
        _event('Football training', existing: stored),
        id: id,
      );
      await parent.store.sync();

      final reread = await parent.store.payloadOf(id);
      expect(reread!.text('carpoolNote'), 'Anna drives on even weeks');
      expect(reread.text('title'), 'Football training');
      await parent.close();
    },
  );

  test('member profiles sync and read back', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    await parent.store.saveProfile(
      'member-maja',
      MemberProfile.write(
        displayName: 'Maja',
        role: MemberRole.child,
        color: '#009E73',
      ),
    );
    await parent.store.sync();
    await child.store.sync();

    final (id, profile) = (await child.store.watchProfiles().first).single;
    expect(id, 'member-maja');
    expect(profile.displayName, 'Maja');
    await parent.close();
    await child.close();
  });

  group('event exceptions', () {
    final thursday = DateTime.utc(2026, 9, 17, 15, 30);

    EventExceptionPayload cancelOn(String eventId, DateTime at) =>
        EventExceptionPayload.write(
          eventId: eventId,
          originalStart: at,
          type: ExceptionType.cancelled,
        );

    test('sync to other devices', () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.saveException(
        cancelOn(id, thursday),
        visibility: EventVisibility.family,
      );
      await parent.store.sync();
      await child.store.sync();

      final (_, e) = (await child.store.watchExceptions().first).single;
      expect(e.eventId, id);
      expect(e.type, ExceptionType.cancelled);
      await parent.close();
      await child.close();
    });

    test('editing one occurrence twice keeps one object', () async {
      final parent = await device('parent', parentKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.saveException(
        cancelOn(id, thursday),
        visibility: EventVisibility.family,
      );
      await parent.store.saveException(
        EventExceptionPayload.write(
          eventId: id,
          originalStart: thursday,
          type: ExceptionType.modified,
          overrideTitle: 'Away match',
        ),
        visibility: EventVisibility.family,
      );
      await parent.store.sync();

      final (_, e) = (await parent.store.watchExceptions().first).single;
      expect(e.overrideTitle, 'Away match');
      expect(server.objects.values.where((o) => o.kind == 15), hasLength(1));
      await parent.close();
    });

    test('a parents-only event keeps its exceptions from children', () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      final id = await parent.store.saveEvent(
        _event('Gift shopping', visibility: EventVisibility.parentsOnly),
      );
      await parent.store.saveException(
        cancelOn(id, thursday),
        visibility: EventVisibility.parentsOnly,
      );
      await parent.store.sync();
      await child.store.sync();

      expect(await child.store.watchExceptions().first, isEmpty);
      expect(await child.store.unreadableCounts(), {'noAccess': 2});
      await parent.close();
      await child.close();
    });

    test('deleting an event deletes its exceptions', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      final football = await parent.store.saveEvent(_event('Football'));
      final piano = await parent.store.saveEvent(_event('Piano'));
      for (final id in [football, piano]) {
        await parent.store.saveException(
          cancelOn(id, thursday),
          visibility: EventVisibility.family,
        );
      }
      await parent.store.sync();
      await other.store.sync();

      await parent.store.deleteEvent(football);
      await parent.store.sync();
      await other.store.sync();

      final left = await other.store.watchExceptions().first;
      expect([for (final (_, e) in left) e.eventId], [piano]);
      await parent.close();
      await other.close();
    });
  });

  test('device preferences stay on the device', () async {
    final parent = await device('parent', parentKeys);
    final other = await device('other', parentKeys);
    await parent.store.setDevicePreference('calendar.scope', 'mine');
    await parent.store.sync();
    await other.store.sync();

    expect(await parent.store.devicePreference('calendar.scope'), 'mine');
    expect(await other.store.devicePreference('calendar.scope'), isNull);
    expect(
      await parent.store.devicePreference('cursor'),
      isNull,
      reason: 'preferences are namespaced apart from sync state',
    );
    await parent.close();
    await other.close();
  });

  group('soft delete', () {
    test('hides the event on every device until restored', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.sync();
      await other.store.sync();

      await parent.store.softDeleteEvent(id);
      await parent.store.sync();
      await other.store.sync();
      final (_, deleted) = (await other.store.watchEvents().first).single;
      expect(deleted.isDeleted, isTrue);
      expect(deleted.title, 'Football', reason: 'nothing else changes');

      await other.store.restoreEvent(id);
      await other.store.sync();
      await parent.store.sync();
      final (_, restored) = (await parent.store.watchEvents().first).single;
      expect(restored.isDeleted, isFalse);
      await parent.close();
      await other.close();
    });

    test('the server cannot tell a deleted event from another', () async {
      final parent = await device('parent', parentKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.sync();
      await parent.store.softDeleteEvent(id);
      await parent.store.sync();

      expect(server.objects[id]!.deleted, isFalse);
      expect(server.objects[id]!.envelope, isNotNull);
      await parent.close();
    });

    test('purges after the restore window, exceptions included', () async {
      final parent = await device('parent', parentKeys);
      final now = DateTime.utc(2026, 10, 1);
      final old = await parent.store.saveEvent(_event('Old'));
      final recent = await parent.store.saveEvent(_event('Recent'));
      await parent.store.saveException(
        EventExceptionPayload.write(
          eventId: old,
          originalStart: DateTime.utc(2026, 9, 22, 15, 30),
          type: ExceptionType.cancelled,
        ),
        visibility: EventVisibility.family,
      );
      await parent.store.softDeleteEvent(
        old,
        now: now.subtract(const Duration(days: 31)),
      );
      await parent.store.softDeleteEvent(
        recent,
        now: now.subtract(const Duration(days: 29)),
      );

      expect(await parent.store.purgeDeleted(now: now), 1);
      final left = [
        for (final (id, _) in await parent.store.watchEvents().first) id,
      ];
      expect(left, [recent]);
      expect(await parent.store.watchExceptions().first, isEmpty);
      await parent.close();
    });
  });

  test('places sync to every device, children included', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    final hall = await parent.store.savePlace(
      PlacePayload.write(
        name: 'Sportshallen',
        address: 'Idrottsvägen 3, 181 41 Lidingö',
        parkingBufferMinutes: 10,
      ),
    );
    await parent.store.saveEvent(
      EventPayload.write(
        title: 'Football',
        kind: EventKind.activity,
        localStart: DateTime.utc(2026, 9, 22, 17, 30),
        duration: const Duration(hours: 1),
        timeZone: 'Europe/Stockholm',
        placeId: hall,
        location: 'Sportshallen',
      ),
    );
    await parent.store.sync();
    await child.store.sync();

    final (id, place) = (await child.store.watchPlaces().first).single;
    expect(id, hall);
    expect(place.toDomain(id).parkingBufferMinutes, 10);
    expect(place.payload.text('geocode'), 'unresolved');
    final (_, event) = (await child.store.watchEvents().first).single;
    expect(event.toDomain('e')!.placeId, hall);
    await parent.close();
    await child.close();
  });

  test('family settings: defaults, then what a parent saves', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    expect(
      (await child.store.watchSettings().first).quietStart,
      FamilySettings.defaults.quietStart,
    );

    await parent.store.saveSettings(
      const FamilySettings(quietStart: 22 * 60, digestAt: null),
    );
    await parent.store.sync();
    await child.store.sync();

    final settings = await child.store.watchSettings().first;
    expect(settings.quietStart, 22 * 60);
    expect(settings.digestAt, isNull, reason: 'the digest turned off');
    expect(
      settings.prepBufferMinutes,
      FamilySettings.defaults.prepBufferMinutes,
    );
    await parent.close();
    await child.close();
  });

  test('every write says which member made it, inside the envelope', () async {
    final parent = await device('parent', parentKeys);
    final other = await device('other', parentKeys);
    final id = await parent.store.saveEvent(_event('Football'));
    await parent.store.sync();
    await other.store.sync();

    expect((await other.store.payloadOf(id))!.editedBy, 'member-parent');
    expect((await other.store.payloadOf(id))!.createdBy, 'member-parent');
    // Someone else's edit keeps who made it.
    await other.store.saveEvent(
      _event('Football', existing: await other.store.payloadOf(id)),
      id: id,
    );
    final edited = (await other.store.payloadOf(id))!;
    expect(edited.createdBy, 'member-parent');
    expect(edited.editedBy, 'member-other');
    expect(
      String.fromCharCodes(server.objects[id]!.envelope!),
      isNot(contains('member-parent')),
    );
    await parent.close();
    await other.close();
  });

  group('key rotation', () {
    test(
      'after a rotation a removed device reads nothing, old or new',
      () async {
        final parent = await device('parent', parentKeys);
        final child = await device('child', childKeys);
        final id = await parent.store.saveEvent(_event('Dinner'));
        await parent.store.sync();
        await child.store.sync();
        expect(await child.store.watchEvents().first, hasLength(1));

        // The child's device is removed: `all` moves to epoch 1 without it.
        parentKeys.generate(group: allGroup, epoch: 1);
        expect(await parent.store.rewrapToLatest(), 1);
        await parent.store.saveEvent(_event('Lunch'));
        await parent.store.sync();
        await child.store.sync();

        expect(await child.store.watchEvents().first, isEmpty);
        expect(await child.store.unreadableCounts(), {'noAccess': 2});
        final header = inspect(envelope: server.objects[id]!.envelope!);
        expect(header.audiences.map((a) => '${a.group}@${a.epoch}'), ['all@1']);
        await parent.close();
        await child.close();
      },
    );

    test('a rewrap never overwrites a newer edit', () async {
      final parent = await device('parent', parentKeys);
      final other = await device('other', parentKeys);
      final id = await parent.store.saveEvent(_event('Football'));
      await parent.store.sync();
      await other.store.sync();

      parentKeys.generate(group: allGroup, epoch: 1);
      await parent.store.rewrapToLatest();
      // Meanwhile the other parent renames it and gets there first.
      final stored = await other.store.payloadOf(id);
      await other.store.saveEvent(
        _event('Football training', existing: stored),
        id: id,
      );
      await other.store.sync();
      await parent.store.sync();
      await parent.store.sync();

      final (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.title, 'Football training');
      expect(
        await parent.queue.select(parent.queue.queuedCommands).get(),
        isEmpty,
      );
      await parent.close();
      await other.close();
    });
  });

  group('helpers', () {
    final helper = helperGroup('member-sara');

    EventPayload withParticipants(
      String title,
      List<String> who, {
      EventVisibility visibility = EventVisibility.family,
    }) => EventPayload.write(
      title: title,
      kind: EventKind.activity,
      localStart: DateTime.utc(2026, 9, 22, 17, 30),
      duration: const Duration(hours: 1),
      timeZone: 'Europe/Stockholm',
      participantIds: who,
      visibility: visibility,
    );

    Future<(TestDevice, TestDevice)> setUpHelper({DateTime? until}) async {
      parentKeys.generate(group: helper, epoch: 0);
      final saraKeys = Keyring();
      final saraDevice = Device.generate();
      saraKeys.acceptGrant(
        grant: parentKeys.grant(
          group: helper,
          epoch: 0,
          familyId: 'fam-1',
          granter: saraDevice,
          fromDevice: 'parent',
          toDevice: 'sara',
          toKemKey: saraDevice.kemPublicKey,
        ),
        familyId: 'fam-1',
        me: saraDevice,
        myDevice: 'sara',
        trusted: [
          TrustedDevice(
            deviceId: 'parent',
            signingKey: saraDevice.signingPublicKey,
          ),
        ],
      );
      final parent = await device('parent', parentKeys);
      final sara = await device('sara', saraKeys);
      await parent.store.saveHelperGrant(
        HelperGrantPayload.write(
          helperMemberId: 'member-sara',
          childIds: const ['maja'],
          until: until ?? DateTime.now().toUtc().add(const Duration(days: 1)),
        ),
      );
      return (parent, sara);
    }

    Future<List<String>> titles(TestDevice d) async =>
        [for (final (_, e) in await d.store.watchEvents().first) e.title]
          ..sort();

    test('a co-parent reads the arrangement, the changeovers and their '
        'child\'s events, and nothing else', () async {
      final (parent, sara) = await setUpHelper();
      await parent.store.saveHelperGrant(
        HelperGrantPayload.write(
          helperMemberId: 'member-sara',
          childIds: const ['maja'],
          coParent: true,
        ),
      );
      await parent.store.saveCustody(
        CustodyPayload.write(
          childId: 'maja',
          coParentId: 'member-sara',
          pattern: CustodyPattern.alternatingWeeks,
          reference: DateTime.utc(2026, 9, 20, 17),
        ),
        timeZone: 'Europe/Stockholm',
        toUs: 'Maja till oss',
        toThem: 'Maja till Sara',
      );
      await parent.store.saveEvent(withParticipants('Football', ['maja']));
      await parent.store.saveEvent(withParticipants('Dentist', ['erik']));
      await parent.store.sync();
      await sara.store.sync();
      expect(await titles(sara), [
        'Football',
        'Maja till Sara',
        'Maja till oss',
      ]);
      final (_, custody) = (await sara.store.watchCustody().first).single;
      expect(
        custody.toDomain()!.isHere(DateTime.utc(2026, 9, 29, 12)),
        isFalse,
      );
      await parent.close();
      await sara.close();
    });

    test('a co-parent\'s access has no end date', () {
      final grant = HelperGrantPayload.write(
        helperMemberId: 'x',
        childIds: const ['maja'],
        coParent: true,
      );
      expect(grant.activeAt(DateTime.utc(2099)), isTrue);
    });

    test('a helper reads what concerns the children they cover', () async {
      final (parent, sara) = await setUpHelper();
      await parent.store.saveEvent(withParticipants('Football', ['maja']));
      await parent.store.saveEvent(withParticipants('Dentist', ['erik']));
      await parent.store.saveEvent(withParticipants('Dinner', []));
      await parent.store.saveEvent(
        withParticipants('Gift shopping', [
          'maja',
        ], visibility: EventVisibility.parentsOnly),
      );
      await parent.store.saveProfile(
        'maja',
        MemberProfile.write(displayName: 'Maja', role: MemberRole.child),
      );
      await parent.store.sync();
      await sara.store.sync();

      expect(await titles(sara), ['Dinner', 'Football']);
      expect(
        (await sara.store.watchProfiles().first).single.$2.displayName,
        'Maja',
      );
      expect(
        (await sara.store.watchHelperGrants().first),
        isEmpty,
        reason: 'the grant itself is for parents',
      );
      await parent.close();
      await sara.close();
    });

    test(
      'what was there before the grant reaches them after a rewrap',
      () async {
        parentKeys.generate(group: helper, epoch: 0);
        final parent = await device('parent', parentKeys);
        await parent.store.saveEvent(withParticipants('Football', ['maja']));
        await parent.close();

        final (again, sara) = await setUpHelper();
        await again.store.rewrapToLatest();
        await again.store.sync();
        await sara.store.sync();
        expect(await titles(sara), ['Football']);
        await again.close();
        await sara.close();
      },
    );

    test('nothing new reaches a helper after their time is up', () async {
      final (parent, sara) = await setUpHelper(
        until: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      await parent.store.saveEvent(withParticipants('Football', ['maja']));
      await parent.store.sync();
      await sara.store.sync();
      expect(await titles(sara), isEmpty);
      await parent.close();
      await sara.close();
    });
  });

  group('calendar feeds', () {
    ImportedEvent feedEvent(
      String uid,
      String title, {
      DateTime? start,
      int sequence = 0,
      bool cancelled = false,
    }) => ImportedEvent(
      uid: uid,
      sequence: sequence,
      title: title,
      localStart: start ?? DateTime.utc(2026, 10, 6, 17, 30),
      duration: const Duration(minutes: 90),
      allDay: false,
      location: 'Lidingövallen',
      description: 'Samlingstid\n2026-10-06 17:10',
      categories: const ['Träning'],
      cancelled: cancelled,
    );

    Future<int> import(TestDevice d, List<ImportedEvent> events) =>
        d.store.importFeed(
          linkId: 'link-1',
          memberId: 'maja',
          timeZone: 'Europe/Stockholm',
          events: events,
          now: DateTime.utc(2026, 9, 19),
        );

    test('a phone calendar opened up backfills what it was hiding', () async {
      // Switching a calendar from busy to full has to reach the entries
      // already imported, not just the next ones. Otherwise the family is
      // left with a week of "Busy" that no amount of syncing repairs, and
      // the only way out is deleting the calendar and adding it again.
      final parent = await device('parent', parentKeys);

      ImportedEvent asPhone(CalendarDetail detail) => fromPhoneCalendar(
        id: 'phone-7',
        title: 'Tandläkare',
        localStart: DateTime.utc(2026, 9, 24, 9),
        duration: const Duration(minutes: 45),
        detail: detail,
        busyTitle: 'Upptagen',
        location: 'Folktandvården, Mölnlycke',
      );

      await import(parent, [asPhone(CalendarDetail.busy)]);
      var event = (await parent.store.watchEvents().first).single.$2;
      expect(event.title, 'Upptagen');
      expect(event.location, isNull);

      final changed = await import(parent, [asPhone(CalendarDetail.full)]);

      expect(changed, 1, reason: 'the entry is rewritten, not skipped');
      event = (await parent.store.watchEvents().first).single.$2;
      expect(event.title, 'Tandläkare');
      expect(event.location, 'Folktandvården, Mölnlycke');
      await parent.close();
    });

    test('links are for the parents only', () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      await parent.store.saveCalendarLink(
        CalendarLinkPayload.write(
          memberId: 'maja',
          name: 'LIF F15',
          url: 'https://cal.laget.se/LIF2003_F15.ics',
        ),
      );
      await parent.store.sync();
      await child.store.sync();
      expect(await child.store.watchCalendarLinks().first, isEmpty);
      final (_, link) = (await parent.store.watchCalendarLinks().first).single;
      expect(link.memberId, 'maja');
      await parent.close();
      await child.close();
    });

    test(
      'events arrive for the member, and a re-fetch changes nothing',
      () async {
        final parent = await device('parent', parentKeys);
        expect(await import(parent, [feedEvent('1@laget.se', 'Träning')]), 1);
        expect(await import(parent, [feedEvent('1@laget.se', 'Träning')]), 0);
        final (id, e) = (await parent.store.watchEvents().first).single;
        expect(id, FamilyStore.importedEventId('link-1', '1@laget.se'));
        expect(e.participantIds, ['maja']);
        expect(e.toDomain(id)!.meetMinutesBefore, 20);
        expect(e.payload.nested('source')!.text('uid'), '1@laget.se');
        await parent.close();
      },
    );

    test(
      'a usual driver is set on arrival, not over the family\'s choice',
      () async {
        final parent = await device('parent', parentKeys);
        Future<void> fetch(List<ImportedEvent> events) =>
            parent.store.importFeed(
              linkId: 'link-1',
              memberId: 'maja',
              timeZone: 'Europe/Stockholm',
              events: events,
              responsibleMemberId: 'anna',
            );
        await fetch([feedEvent('1@laget.se', 'Träning')]);
        final (id, e) = (await parent.store.watchEvents().first).single;
        expect(e.responsibleMemberId, 'anna');
        final erik = Payload.decode(e.payload.encode())
          ..setText('responsible', 'erik');
        await parent.store.saveEvent(EventPayload.read(erik), id: id);
        await fetch([feedEvent('1@laget.se', 'Träning', sequence: 1)]);
        final (_, after) = (await parent.store.watchEvents().first).single;
        expect(after.responsibleMemberId, 'erik');
        await parent.close();
      },
    );

    test('a calendar for the whole family names nobody, so it is everyone\'s',
        () async {
      final parent = await device('parent', parentKeys);
      Future<void> fetch(String? member) => parent.store.importFeed(
        linkId: 'link-1',
        memberId: member,
        timeZone: 'Europe/Stockholm',
        events: [feedEvent('1@shared', 'Middag hos mormor')],
      );
      await fetch(null);
      var (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.participantIds, isEmpty);
      expect(e.payload.nested('source')?.boolean('family'), isTrue);

      // Made one person's after all, and back again.
      await fetch('johan');
      (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.participantIds, ['johan']);
      expect(e.payload.nested('source')?.boolean('family'), isFalse);
      await fetch(null);
      (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.participantIds, isEmpty);

      // Fetched again unchanged: nothing written.
      expect(
        await parent.store.importFeed(
          linkId: 'link-1',
          memberId: null,
          timeZone: 'Europe/Stockholm',
          events: [feedEvent('1@shared', 'Middag hos mormor')],
        ),
        0,
      );
      await parent.close();
    });

    test('relinking to and from the whole family', () async {
      final parent = await device('parent', parentKeys);
      await import(parent, [feedEvent('1@laget.se', 'Träning')]);
      await parent.store.relinkFeed('link-1', from: 'maja', to: null);
      var (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.participantIds, isEmpty);
      expect(e.payload.nested('source')?.boolean('family'), isTrue);
      await parent.store.relinkFeed('link-1', from: null, to: 'ella');
      (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.participantIds, ['ella']);
      expect(e.payload.nested('source')?.text('member'), 'ella');
      await parent.close();
    });

    test('a link moved to another member moves its events', () async {
      final parent = await device('parent', parentKeys);
      Future<void> fetch(String member) => parent.store.importFeed(
        linkId: 'link-1',
        memberId: member,
        timeZone: 'Europe/Stockholm',
        events: [feedEvent('1@laget.se', 'Träning')],
      );
      await fetch('johan');
      final (id, e) = (await parent.store.watchEvents().first).single;
      final plusErik = Payload.decode(e.payload.encode())
        ..setTexts('participants', ['johan', 'erik']);
      await parent.store.saveEvent(EventPayload.read(plusErik), id: id);
      await fetch('maja');
      expect(
        (await parent.store.watchEvents().first).single.$2.participantIds,
        ['maja', 'erik'],
      );
      await parent.close();
    });

    test(
      'relinking moves events imported before links knew their member',
      () async {
        final parent = await device('parent', parentKeys);
        await import(parent, [feedEvent('1@laget.se', 'Träning')]);
        final (id, e) = (await parent.store.watchEvents().first).single;
        final legacy = Payload.decode(e.payload.encode())
          ..setNested(
            'source',
            e.payload.nested('source')!..setText('member', null),
          );
        await parent.store.saveEvent(EventPayload.read(legacy), id: id);
        await parent.store.relinkFeed('link-1', from: 'maja', to: 'ella');
        expect(
          (await parent.store.watchEvents().first).single.$2.participantIds,
          ['ella'],
        );
        await parent.close();
      },
    );

    test('a usual driver chosen later fills in where no one is', () async {
      final parent = await device('parent', parentKeys);
      await import(parent, [feedEvent('1@laget.se', 'Träning')]);
      expect(
        (await parent.store.watchEvents().first).single.$2.responsibleMemberId,
        isNull,
      );
      await parent.store.importFeed(
        linkId: 'link-1',
        memberId: 'maja',
        timeZone: 'Europe/Stockholm',
        events: [feedEvent('1@laget.se', 'Träning')],
        responsibleMemberId: 'anna',
      );
      expect(
        (await parent.store.watchEvents().first).single.$2.responsibleMemberId,
        'anna',
      );
      await parent.close();
    });

    test(
      'a changed event updates in place and keeps what the family added',
      () async {
        final parent = await device('parent', parentKeys);
        await import(parent, [feedEvent('1@laget.se', 'Träning')]);
        final (id, e) = (await parent.store.watchEvents().first).single;
        await parent.store.saveEvent(
          EventPayload.write(
            existing: e.payload,
            title: e.title,
            kind: e.kind,
            localStart: e.localStart!,
            duration: e.duration,
            timeZone: e.timeZone,
            participantIds: e.participantIds,
            responsibleMemberId: 'member-parent',
            location: e.location,
            notes: e.notes,
          ),
          id: id,
        );

        await import(parent, [
          feedEvent(
            '1@laget.se',
            'Träning (flyttad)',
            start: DateTime.utc(2026, 10, 6, 18),
          ),
        ]);
        final (_, after) = (await parent.store.watchEvents().first).single;
        expect(after.title, 'Träning (flyttad)');
        expect(after.localStart, DateTime.utc(2026, 10, 6, 18));
        expect(after.responsibleMemberId, 'member-parent');
        await parent.close();
      },
    );

    test(
      'gone from the feed: future events cancelled, past ones left',
      () async {
        final parent = await device('parent', parentKeys);
        await import(parent, [
          feedEvent('past@laget.se', 'Match', start: DateTime.utc(2026, 9, 15)),
          feedEvent('future@laget.se', 'Match'),
        ]);
        await import(parent, []);
        final byTitle = {
          for (final (_, e) in await parent.store.watchEvents().first)
            e.localStart!.month: e.status,
        };
        expect(byTitle, {9: EventStatus.confirmed, 10: EventStatus.cancelled});
        await parent.close();
      },
    );

    test('an event the family deleted stays deleted', () async {
      final parent = await device('parent', parentKeys);
      await import(parent, [feedEvent('1@laget.se', 'Träning')]);
      final (id, _) = (await parent.store.watchEvents().first).single;
      await parent.store.softDeleteEvent(id);
      await import(parent, [feedEvent('1@laget.se', 'Träning', sequence: 2)]);
      final (_, e) = (await parent.store.watchEvents().first).single;
      expect(e.isDeleted, isTrue);
      await parent.close();
    });
  });

  test('a feed event the family deleted never comes back', () async {
    final parent = await device('parent', parentKeys);
    Future<void> fetch(DateTime now) => parent.store.importFeed(
      linkId: 'link-1',
      memberId: 'maja',
      timeZone: 'Europe/Stockholm',
      now: now,
      events: [
        ImportedEvent(
          uid: '1',
          sequence: 0,
          title: 'Match',
          localStart: DateTime.utc(2026, 11, 15, 10),
          duration: const Duration(hours: 1),
        ),
      ],
    );
    await fetch(DateTime.utc(2026, 9, 19));
    final (id, _) = (await parent.store.watchEvents().first).single;
    await parent.store.softDeleteEvent(id, now: DateTime.utc(2026, 9, 19));

    // 30 days on, the match is still ahead of the feed: kept, deleted.
    expect(await parent.store.purgeDeleted(now: DateTime.utc(2026, 10, 20)), 0);
    // A week after it's over the feed no longer brings it: purged for good.
    expect(await parent.store.purgeDeleted(now: DateTime.utc(2026, 11, 23)), 1);
    await fetch(DateTime.utc(2026, 11, 23));
    expect(await parent.store.watchEvents().first, isEmpty);
    await parent.close();
  });

  test("un-ticking a phone's calendar takes its events back", () async {
    // A phone calendar could be un-ticked and its events stayed in the
    // family's calendar for ever: nothing fetched it again, so nothing
    // ever marked them gone. The events outlived the decision that
    // brought them in.
    final parent = await device('parent', parentKeys);
    Future<int> fetch() => parent.store.importFeed(
      linkId: 'phone/work',
      memberId: 'anna',
      timeZone: 'Europe/Stockholm',
      now: DateTime.utc(2026, 9, 19),
      events: [
        // One just gone, one still to come: a feed does not bring in what
        // ended more than a week ago, so a March date would test nothing.
        for (final (uid, month, day) in [('a', 9, 16), ('b', 10, 16)])
          ImportedEvent(
            uid: uid,
            sequence: 0,
            title: 'Standup',
            localStart: DateTime.utc(2026, month, day, 9),
            duration: const Duration(minutes: 15),
          ),
      ],
    );
    await fetch();
    expect((await parent.store.watchEvents().first).length, 2);

    // Past ones too: the calendar is gone, and nothing can correct or
    // remove what it left behind afterwards.
    expect(
      await parent.store.withdrawFeed(
        'phone/work',
        now: DateTime.utc(2026, 9, 19),
      ),
      2,
    );
    // Gone from the calendar — the app shows nothing deleted — but
    // recoverable rather than destroyed: they are in the family's
    // recently deleted list, where an un-tick by mistake can be undone.
    expect(
      [for (final (_, e) in await parent.store.watchEvents().first) e.isDeleted],
      [true, true],
    );

    // And ticking it again brings them back, rather than finding them
    // deleted for ever.
    await fetch();
    expect(
      [for (final (_, e) in await parent.store.watchEvents().first) e.isDeleted],
      [false, false],
    );
    await parent.close();
  });

  test('a feed event the family deleted itself stays deleted through a '
      'withdrawal', () async {
    final parent = await device('parent', parentKeys);
    Future<int> fetch() => parent.store.importFeed(
      linkId: 'phone/work',
      memberId: 'anna',
      timeZone: 'Europe/Stockholm',
      now: DateTime.utc(2026, 9, 19),
      events: [
        ImportedEvent(
          uid: 'a',
          sequence: 0,
          title: 'Standup',
          localStart: DateTime.utc(2026, 10, 16, 9),
          duration: const Duration(minutes: 15),
        ),
      ],
    );
    await fetch();
    final (id, _) = (await parent.store.watchEvents().first).single;
    await parent.store.softDeleteEvent(id, now: DateTime.utc(2026, 9, 19));
    // Withdrawing the whole calendar must not turn "we chose not to see
    // this" into "bring it back the moment the calendar returns".
    await parent.store.withdrawFeed(
      'phone/work',
      now: DateTime.utc(2026, 9, 19),
    );
    await fetch();
    expect(
      (await parent.store.watchEvents().first).single.$2.isDeleted,
      isTrue,
    );
    await parent.close();
  });

  test('unlinking a feed takes every event it brought, past ones too',
      () async {
    final parent = await device('parent', parentKeys);
    final link = await parent.store.saveCalendarLink(
      CalendarLinkPayload.write(memberId: 'maja', name: 'F15', url: 'x'),
    );
    await parent.store.importFeed(
      linkId: link,
      memberId: 'maja',
      timeZone: 'Europe/Stockholm',
      now: DateTime.utc(2026, 9, 19),
      events: [
        for (final (uid, month) in [('a', 9), ('b', 10)])
          ImportedEvent(
            uid: uid,
            sequence: 0,
            title: 'Träning',
            localStart: DateTime.utc(2026, month, 16, 17),
            duration: const Duration(hours: 1),
          ),
      ],
    );
    await parent.store.unlinkFeed(link, now: DateTime.utc(2026, 9, 19));
    final left = await parent.store.watchEvents().first;
    // Gone from the calendar, but only as far as Recently deleted: an
    // unlink by mistake is recoverable, not final.
    expect([for (final (_, e) in left) e.isDeleted], [true, true]);
    expect(await parent.store.watchCalendarLinks().first, isEmpty);
    await parent.close();
  });

  test('erasing a member anonymises them and keeps what\'s shared', () async {
    final parent = await device('parent', parentKeys);
    await parent.store.saveProfile(
      'maja',
      MemberProfile.write(
        displayName: 'Maja',
        role: MemberRole.child,
        color: '#E69F00',
        tier: MaturityTier.kid,
        endedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    EventPayload with_(String title, List<String> going, {String? driver}) =>
        EventPayload.write(
          title: title,
          kind: EventKind.activity,
          localStart: DateTime.utc(2026, 9, 22, 17),
          duration: const Duration(hours: 1),
          timeZone: 'Europe/Stockholm',
          participantIds: going,
          responsibleMemberId: driver,
        );
    await parent.store.saveEvent(with_('Maja\'s dentist', ['maja']));
    await parent.store.saveEvent(with_('Cinema', ['maja', 'erik']));
    await parent.store.saveEvent(with_('Dinner', [], driver: 'maja'));
    await parent.store.saveCalendarLink(
      CalendarLinkPayload.write(memberId: 'maja', name: 'F15', url: 'x'),
    );

    await parent.store.eraseMember('maja');

    final profile = MemberProfile.read((await parent.store.payloadOf('maja'))!);
    expect(profile.erased, isTrue);
    expect(profile.displayName, isEmpty);
    expect(profile.color, isNull);
    expect(profile.tier, isNull);
    expect(profile.endedAt, DateTime.utc(2026, 9, 1));
    final events = {
      for (final (_, e) in await parent.store.watchEvents().first)
        e.title: '${e.participantIds.join(',')}|${e.responsibleMemberId}',
    };
    expect(events, {'Cinema': 'erik|null', 'Dinner': '|null'});
    expect(await parent.store.watchCalendarLinks().first, isEmpty);
    await parent.close();
  });

  group('shopping', () {
    RecipePayload recipe(
      String title,
      List<String> lines, {
      int servings = 4,
    }) => RecipePayload.write(
      title: title,
      ingredients: lines,
      servings: servings,
    );

    Future<Map<String, String>> list(TestDevice d, String listId) async => {
      for (final (_, i) in await d.store.watchShoppingItems().first)
        if (i.listId == listId) i.describe(): i.state.name,
    };

    test('two recipes on one list, the whole family sees it', () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      final listId = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'Veckohandling'),
      );
      await parent.store.addRecipeToList(
        listId,
        'curry',
        recipe('Kycklinggryta', [
          '2 dl grädde',
          '1 gul lök',
          '1 förp kokosmjölk',
        ]),
      );
      await parent.store.addRecipeToList(
        listId,
        'soup',
        recipe('Soppa', ['3 msk vispgrädde', '2 gula lökar', 'salt']),
        servings: 8,
      );
      await parent.store.sync();
      await child.store.sync();
      expect(
        (await child.store.watchShoppingLists().first).single.$2.name,
        'Veckohandling',
      );
      expect(await list(child, listId), {
        '2,9 dl grädde': 'needed',
        '5 st gul lök': 'needed',
        '1 förp kokosmjölk': 'needed',
        'salt': 'needed',
      });
      await parent.close();
      await child.close();
    });

    test('the week\'s menu onto the list, and in step as it changes', () async {
      final parent = await device('parent', parentKeys);
      final listId = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'L'),
      );
      await parent.store.saveRecipe(
        recipe('Curry', ['2 dl grädde', '1 gul lök']),
        id: 'curry',
      );
      await parent.store.saveRecipe(recipe('Sallad', ['1 gurka']), id: 'salad');
      final tuesday = await parent.store.saveMeal(
        MealPayload.write(
          date: DateTime.utc(2026, 9, 22),
          recipes: const [
            MealRecipe(recipeId: 'curry'),
            MealRecipe(recipeId: 'salad', role: 'salad'),
          ],
        ),
      );
      await parent.store.saveMeal(
        MealPayload.write(
          date: DateTime.utc(2026, 9, 24),
          servings: 8,
          recipes: const [MealRecipe(recipeId: 'curry')],
        ),
      );
      // Next week: not this list's business.
      await parent.store.saveMeal(
        MealPayload.write(
          date: DateTime.utc(2026, 9, 29),
          recipes: const [MealRecipe(recipeId: 'salad')],
        ),
      );
      Future<void> sync() => parent.store.menuToList(
        listId,
        from: DateTime.utc(2026, 9, 21),
        until: DateTime.utc(2026, 9, 28),
        defaultServings: 4,
      );
      await sync();
      await sync();
      expect(await list(parent, listId), {
        '6 dl grädde': 'needed',
        '3 st gul lök': 'needed',
        '1 st gurka': 'needed',
      });

      // The salad comes off Tuesday: only the salad's share goes.
      final meal = MealPayload.read((await parent.store.payloadOf(tuesday))!);
      await parent.store.saveMeal(
        MealPayload.write(
          existing: meal.payload,
          date: meal.date!,
          recipes: const [MealRecipe(recipeId: 'curry')],
        ),
        id: tuesday,
      );
      await sync();
      expect(await list(parent, listId), {
        '6 dl grädde': 'needed',
        '3 st gul lök': 'needed',
      });
      await parent.close();
    });

    test('staples go on once, and merge with what\'s there', () async {
      final parent = await device('parent', parentKeys);
      final staples = await parent.store.staplesList(name: 'Basvaror');
      expect(await parent.store.staplesList(name: 'Basvaror'), staples);
      await parent.store.addToList(staples, [
        for (final t in ['mjölk', '1 bröd', 'kaffe'])
          ShoppingLine.fromIngredient(
            IngredientLine.parse(t),
            IngredientCatalogue.swedish,
          ),
      ], source: (_) => const ItemSource(type: 'manual'));
      final listId = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'L'),
      );
      await parent.store.addRecipeToList(
        listId,
        'a',
        recipe('A', ['2 st bröd']),
      );
      await parent.store.staplesToList(listId, staples);
      await parent.store.staplesToList(listId, staples);
      expect(await list(parent, listId), {
        '3 st bröd': 'needed',
        'mjölk': 'needed',
        'kaffe': 'needed',
      });
      expect(
        (await parent.store.watchShoppingLists().first).where(
          (l) => l.$2.state == ShoppingListState.template,
        ),
        hasLength(1),
      );
      await parent.close();
    });

    test('taking a recipe off takes only its share', () async {
      final parent = await device('parent', parentKeys);
      final listId = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'L'),
      );
      await parent.store.addRecipeToList(
        listId,
        'a',
        recipe('A', ['2 gula lökar', '4 dl mjölk']),
      );
      await parent.store.addRecipeToList(
        listId,
        'b',
        recipe('B', ['1 gul lök']),
      );
      await parent.store.removeFromList(listId, 'a');
      expect(await list(parent, listId), {'1 st gul lök': 'needed'});
      await parent.close();
    });

    test('what\'s bought stays bought; more of it is a new line', () async {
      final parent = await device('parent', parentKeys);
      final listId = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'L'),
      );
      await parent.store.addRecipeToList(
        listId,
        'a',
        recipe('A', ['4 dl mjölk']),
      );
      final (id, milk) = (await parent.store.watchShoppingItems().first).single;
      await parent.store.saveShoppingItem(
        milk.copyWith(state: ItemState.bought, checkedBy: 'member-parent'),
        id: id,
      );
      await parent.store.addRecipeToList(
        listId,
        'b',
        recipe('B', ['2 dl mjölk']),
      );
      await parent.store.removeFromList(listId, 'a');
      expect(await list(parent, listId), {
        '4 dl mjölk': 'bought',
        '2 dl mjölk': 'needed',
      });
      await parent.close();
    });
  });

  test('dietary notes travel with the profile and survive an edit', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    final profile =
        MemberProfile.write(
          displayName: 'Maja',
          role: MemberRole.child,
        ).withDiet(const [
          DietNote(
            memberId: 'maja',
            type: DietType.allergy,
            value: 'nuts',
            strict: true,
          ),
        ]);
    await parent.store.saveProfile('maja', profile);
    await parent.store.saveProfile(
      'maja',
      MemberProfile.write(
        existing: profile.payload,
        displayName: 'Maja S',
        role: MemberRole.child,
      ),
    );
    await parent.store.sync();
    await child.store.sync();
    final (_, read) = (await child.store.watchProfiles().first).single;
    expect(read.displayName, 'Maja S');
    expect(read.dietNotes('maja').single.value, 'nuts');
    expect(read.dietNotes('maja').single.strict, isTrue);
    await parent.close();
    await child.close();
  });

  test('a person\'s birthday is a yearly event that follows them', () async {
    final parent = await device('parent', parentKeys);
    final id = await parent.store.savePerson(
      PersonPayload.write(
        name: 'Farmor',
        label: 'Farmor',
        date: DateTime.utc(1950, 10, 20),
      ),
      timeZone: 'Europe/Stockholm',
    );
    var (eventId, event) = (await parent.store.watchEvents().first).single;
    expect(eventId, FamilyStore.celebrationId(id));
    expect(event.kind, EventKind.celebration);
    expect(event.rule?.frequency, Frequency.yearly);
    expect(
      event.reminders.map((r) => r.target),
      everyElement(ReminderTarget.adults),
    );
    expect(event.payload.text('person'), id);

    final person = PersonPayload.read((await parent.store.payloadOf(id))!);
    await parent.store.savePerson(
      PersonPayload.write(
        existing: person.payload,
        name: 'Farmor Inga',
        date: DateTime.utc(1950, 10, 21),
      ),
      id: id,
      timeZone: 'Europe/Stockholm',
    );
    (_, event) = (await parent.store.watchEvents().first).single;
    expect(event.title, 'Farmor Inga');
    expect(event.localStart, DateTime.utc(1950, 10, 21));

    await parent.store.deletePerson(id);
    expect(await parent.store.watchEvents().first, isEmpty);
    expect(await parent.store.watchPeople().first, isEmpty);
    await parent.close();
  });

  test('a wishlist\'s owner never sees who claimed what', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    final maja = await parent.store.savePerson(
      PersonPayload.write(name: 'Child', memberId: 'member-child'),
      timeZone: 'Europe/Stockholm',
    );
    final list = await parent.store.saveWishlist(
      WishlistPayload.write(personId: maja, name: 'Födelsedag 2026'),
    );
    final lego = await parent.store.saveWishlistItem(
      WishlistItemPayload.write(wishlistId: list, title: 'Lego'),
    );
    await parent.store.saveWishlistItem(
      WishlistItemPayload.write(wishlistId: list, title: 'Bok', received: true),
    );
    // The claim is sealed to everyone but the child: their own device
    // holds no key for it (crypto doc §3), so this is not a rule of a
    // query that a curious device could ask around.
    await expectLater(
      child.store.claimWish(lego, ownerMemberId: 'member-child'),
      throwsA(isA<MissingObserversKey>()),
    );
    await parent.store.claimWish(lego, ownerMemberId: 'member-child');
    await parent.store.sync();
    await child.store.sync();
    expect(
      (await parent.store.watchClaimsFor('member-parent').first)
          .single
          .$2
          .itemId,
      lego,
    );
    expect(await child.store.watchClaimsFor('member-child').first, isEmpty);
    final claimId =
        (await parent.store.watchClaimsFor('member-parent').first).single.$1;
    expect(
      await child.store.payloadOf(claimId),
      isNull,
      reason: "the owner's device can't open it at all",
    );
    expect(
      server.objects[claimId]?.envelope,
      isNotNull,
      reason: 'the server holds it, unreadable, and relays it as usual',
    );
    expect(
      await child.store.watchWishlistItems().first,
      hasLength(2),
      reason: 'the items themselves are theirs to see',
    );

    final next = await parent.store.carryForward(list, name: 'Födelsedag 2027');
    final carried = [
      for (final (_, i) in await parent.store.watchWishlistItems().first)
        if (i.wishlistId == next) i.title,
    ];
    expect(carried, ['Lego']);
    await parent.close();
    await child.close();
  });

  test(
    'homework: a session is an event; done clears the ones to come',
    () async {
      final parent = await device('parent', parentKeys);
      final maths = await parent.store.saveSubject(
        SubjectPayload.write(memberId: 'maja', name: 'Matte'),
      );
      final id = await parent.store.saveHomework(
        HomeworkPayload.write(
          memberId: 'maja',
          title: 'Sid 42–44',
          subjectId: maths,
          dueAt: DateTime.utc(2026, 9, 25, 6),
          estimatedMinutes: 45,
        ),
      );
      await parent.store.planHomeworkSession(
        id,
        localStart: DateTime.utc(2026, 9, 23, 15, 30),
        minutes: 45,
        timeZone: 'Europe/Stockholm',
      );
      final (eventId, event) = (await parent.store.watchEvents().first).single;
      expect(event.kind, EventKind.homework);
      expect(event.participantIds, ['maja']);
      var hw = HomeworkPayload.read((await parent.store.payloadOf(id))!);
      expect(hw.sessions.single.eventId, eventId);
      expect(hw.overdueAt(DateTime.utc(2026, 9, 26)), isTrue);

      await parent.store.setHomeworkState(
        id,
        HomeworkState.done,
        now: DateTime.utc(2026, 9, 22),
      );
      hw = HomeworkPayload.read((await parent.store.payloadOf(id))!);
      expect(hw.state, HomeworkState.done);
      expect(hw.overdueAt(DateTime.utc(2026, 9, 26)), isFalse);
      expect(await parent.store.watchEvents().first, isEmpty);
      await parent.close();
    },
  );

  test('an absence reaches every device and reads back', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    await parent.store.saveAbsence(
      AbsencePayload.write(
        title: 'Höstlov',
        startsOn: DateTime.utc(2026, 10, 26),
        endsOn: DateTime.utc(2026, 10, 30),
        memberIds: {'maja'},
        suppressKinds: {EventKind.routine},
        schoolBreak: true,
      ),
    );
    await parent.store.sync();
    await child.store.sync();
    final (id, a) = (await child.store.watchAbsences().first).single;
    final absence = a.toDomain(id)!;
    expect(absence.memberIds, {'maja'});
    expect(absence.suppressKinds, {EventKind.routine});
    expect(absence.coversDay(DateTime.utc(2026, 10, 30)), isTrue);
    expect(a.schoolBreak, isTrue);
    await parent.close();
    await child.close();
  });

  test(
    'a child\'s sharing choice and a place\'s spot reach the family',
    () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      await child.store.saveLocationShare(
        const LocationShare(
          memberId: 'maja',
          mode: ShareMode.whileUsing,
          precision: SharePrecision.placeOnly,
        ),
      );
      final school = await parent.store.savePlace(
        PlacePayload.write(name: 'Skolan'),
      );
      await parent.store.setPlaceLocation(
        school,
        const GeoPoint(57.689012, 11.975034),
        radiusMeters: 150,
      );
      await child.store.sync();
      await parent.store.sync();
      await child.store.sync();

      final share = (await parent.store.watchLocationShares().first)['maja']!;
      expect(share.mode, ShareMode.whileUsing);
      expect(share.precision, SharePrecision.placeOnly);
      // A parent's floor keeps the child's own choices.
      await parent.store.saveLocationShare(
        share.copyWith(floor: () => ShareMode.whileUsing),
      );
      final floored = (await parent.store.watchLocationShares().first)['maja']!;
      expect(floored.precision, SharePrecision.placeOnly);
      expect(floored.floor, ShareMode.whileUsing);

      final place = PlacePayload.read((await child.store.payloadOf(school))!)
          .toDomain(school);
      expect(place.location, const GeoPoint(57.689012, 11.975034));
      expect(place.radiusMeters, 150);
      await parent.close();
      await child.close();
    },
  );

  test('a password is the family\'s or one member\'s, by the key', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);

    await parent.store.saveCredential(
      CredentialPayload.write(
        title: 'Wifi',
        secret: 'kallbadhuset',
        scope: const PasswordFor.family(),
      ),
    );
    final mine = await parent.store.saveCredential(
      CredentialPayload.write(
        title: 'Banken',
        secret: 'nope',
        username: 'anna',
        scope: const PasswordFor.member('member-parent'),
      ),
    );
    // The child holds the family's passwords, not a parent's own.
    await expectLater(
      child.store.saveCredential(
        CredentialPayload.write(
          title: 'Skolan',
          secret: 'x',
          scope: const PasswordFor.member('member-parent'),
        ),
      ),
      throwsA(isA<MissingPasswordKey>()),
    );
    await parent.store.sync();
    await child.store.sync();

    expect(
      [
        for (final (_, c) in await child.store.watchCredentials().first)
          c.title,
      ],
      ['Wifi'],
      reason: "the parent's own never opens on the child's device",
    );
    expect(await child.store.payloadOf(mine), isNull);
    expect(
      server.objects[mine]?.envelope,
      isNotNull,
      reason: 'the server holds it, unreadable, and syncs it as usual',
    );
    final family = (await child.store.watchCredentials().first).single.$2;
    expect(family.secret, 'kallbadhuset');
    expect(family.scope, isA<FamilyPassword>());
    final own = CredentialPayload.read((await parent.store.payloadOf(mine))!);
    expect(own.username, 'anna');
    expect((own.scope as MemberPassword).memberId, 'member-parent');
    await parent.close();
    await child.close();
  });

  test('a kit list is shared by the events that carry it', () async {
    final parent = await device('parent', parentKeys);
    final kit = await parent.store.saveEquipmentSet(
      EquipmentSetPayload.write(
        name: 'Fotbollsväska',
        items: const [
          KitItem(name: 'Benskydd'),
          KitItem(name: 'Fällstol', forMember: 'member-parent'),
        ],
      ),
    );
    final training = await parent.store.saveEvent(_event('Träning'));
    await parent.store.setEventEquipment(training, [kit]);
    final event = EventPayload.read((await parent.store.payloadOf(training))!);
    expect(event.equipmentSets, [kit]);
    expect(event.title, 'Träning', reason: 'the rest of the event is kept');
    final (_, set) = (await parent.store.watchEquipmentSets().first).single;
    expect(set.items.map((i) => (i.name, i.forMember)), [
      ('Benskydd', null),
      ('Fällstol', 'member-parent'),
    ]);
    await parent.close();
  });

  test('a child asks, a parent answers, the child sees it', () async {
    final parent = await device('parent', parentKeys);
    final child = await device('child', childKeys);
    final id = await child.store.ask('Får jag sova över hos Elsa på fredag?');
    await child.store.sync();
    await parent.store.sync();
    var (_, r) = (await parent.store.watchRequests().first).single;
    expect((r.requestedBy, r.state), ('member-child', RequestState.pending));
    await parent.store.answer(
      id,
      approved: true,
      note: 'Om du tar med tandborsten',
    );
    await parent.store.sync();
    await child.store.sync();
    (_, r) = (await child.store.watchRequests().first).single;
    expect(r.state, RequestState.approved);
    expect(r.decidedBy, 'member-parent');
    expect(r.answer, 'Om du tar med tandborsten');
    await parent.close();
    await child.close();
  });

  test(
    'a photo is sealed like its owner and opens only where it may',
    () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      final everyone = await parent.store.addPhoto(
        Uint8List.fromList([1, 2, 3]),
        groups: [allGroup],
      );
      final parentsOnly = await parent.store.addPhoto(
        Uint8List.fromList([4, 5, 6]),
        groups: [adultsGroup],
      );
      await parent.store.sync();
      expect(server.blobs.keys, containsAll([everyone, parentsOnly]));
      expect(
        server.blobs[everyone],
        isNot(equals([1, 2, 3])),
        reason: 'the server holds only the sealed bytes',
      );
      expect(await child.store.photo(everyone), [1, 2, 3]);
      expect(await child.store.photo(parentsOnly), isNull);
      expect(await parent.store.photo(parentsOnly), [4, 5, 6]);
      await parent.close();
      await child.close();
    },
  );

  group('answered questions', () {
    test('clearing one away keeps it cleared on every device', () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);

      final id = await child.store.ask('Can I sleep over at Otto\u2019s?');
      await child.store.sync();
      await parent.store.sync();
      await parent.store.answer(id, approved: true, note: 'Home by ten');
      await parent.store.sync();
      await child.store.sync();

      final answered = (await child.store.watchRequests().first).single.$2;
      expect(answered.state, RequestState.approved);
      expect(answered.acknowledged, isFalse);

      // Swiped away on the phone that asked.
      await child.store.acknowledgeRequest(id);
      await child.store.sync();

      expect(
        (await child.store.watchRequests().first).single.$2.acknowledged,
        isTrue,
      );

      // And on the tablet, which never saw the swipe: an answer already
      // read is not news an hour later.
      await parent.store.sync();
      expect(
        (await parent.store.watchRequests().first).single.$2.acknowledged,
        isTrue,
        reason: 'acknowledgement rides on the request, not the device',
      );

      await parent.close();
      await child.close();
    });
  });

  group('the school week plan', () {
    test('a republished week lands on the same homework, not a second copy',
        () async {
      final parent = await device('parent', parentKeys);
      final link = await parent.store.saveWeekPlanLink(
        WeekPlanLinkPayload.write(
          memberId: 'maja',
          url: 'https://school.example/vecka',
          group: '5A',
        ),
      );

      const entries = [
        WeekPlanEntry(
          group: '5A',
          title: 'läxa magma + diagnos kap. 1',
          subject: 'Matematik',
          dueAt: null,
        ),
      ];
      final dated = [
        WeekPlanEntry(
          group: '5A',
          title: 'Läsuppdrag och veckans ord',
          subject: 'Svenska',
          dueAt: DateTime.utc(2026, 9, 25),
        ),
      ];

      expect(
        await parent.store.importWeekPlan(
          linkId: link,
          memberId: 'maja',
          entries: [...entries, ...dated],
        ),
        2,
      );

      // The school republishes the same week with a correction elsewhere in
      // the document; these two are unchanged and must not arrive twice.
      expect(
        await parent.store.importWeekPlan(
          linkId: link,
          memberId: 'maja',
          entries: [...entries, ...dated],
        ),
        0,
      );
      expect(await parent.store.watchHomework().first, hasLength(2));

      // Ticked off here, and still ticked off after the next fetch: a
      // school republishing is not a reason to undo a child's evening.
      final (id, done) = (await parent.store.watchHomework().first).first;
      await parent.store.saveHomework(
        done.withState(HomeworkState.done),
        id: id,
      );
      await parent.store.importWeekPlan(
        linkId: link,
        memberId: 'maja',
        entries: [...entries, ...dated],
      );
      final after = {
        for (final (i, h) in await parent.store.watchHomework().first)
          i: h.state,
      };
      expect(after[id], HomeworkState.done);

      await parent.close();
    });
  });

  group('clearing a shopping list', () {
    test('the ticked ones go, the ones nobody found stay', () async {
      final parent = await device('parent', parentKeys);
      final list = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'Week 39'),
      );
      final other = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'Bauhaus'),
      );
      for (final (name, state) in [
        ('Mjölk', ItemState.bought),
        ('Ägg', ItemState.bought),
        ('Koriander', ItemState.needed),
      ]) {
        await parent.store.saveShoppingItem(
          ShoppingItemPayload.write(listId: list, name: name, state: state),
        );
      }
      await parent.store.saveShoppingItem(
        ShoppingItemPayload.write(
          listId: other,
          name: 'Skruvar',
          state: ItemState.bought,
        ),
      );

      expect(await parent.store.clearShoppingList(list), 2);

      final left = [
        for (final (_, i) in await parent.store.watchShoppingItems().first)
          (i.listId, i.name),
      ];
      // The herb nobody could find is still wanted, and the other list is
      // none of this list's business.
      expect(left, containsAll([(list, 'Koriander'), (other, 'Skruvar')]));
      expect(left, hasLength(2));

      await parent.close();
    });

    test('clearing the lot leaves the list itself', () async {
      final parent = await device('parent', parentKeys);
      final list = await parent.store.saveShoppingList(
        ShoppingListPayload.write(name: 'Week 39'),
      );
      for (final name in ['Mjölk', 'Koriander']) {
        await parent.store.saveShoppingItem(
          ShoppingItemPayload.write(listId: list, name: name),
        );
      }

      expect(
        await parent.store.clearShoppingList(list, boughtOnly: false),
        2,
      );
      expect(await parent.store.watchShoppingItems().first, isEmpty);
      // Emptied, not deleted: it is still the list you are shopping from.
      expect(
        [for (final (id, _) in await parent.store.watchShoppingLists().first) id],
        contains(list),
      );

      await parent.close();
    });
  });

  group('weekly homework', () {
    test('one piece a week, the same on every device, and never twice',
        () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveHomeworkTemplate(
        HomeworkTemplatePayload.write(
          memberId: 'maja',
          title: 'Glosor',
          estimatedMinutes: 20,
          schedule: EventPayload.write(
            title: 'Glosor',
            kind: EventKind.homework,
            localStart: DateTime.utc(2026, 9, 18, 8),
            duration: Duration.zero,
            timeZone: 'Europe/Stockholm',
            rule: const RecurrenceRule(
              frequency: Frequency.weekly,
              byWeekday: {Weekday.fr},
            ),
          ),
        ),
      );

      final now = DateTime.utc(2026, 9, 18);
      const window = Duration(days: 14);
      expect(await parent.store.planHomeworkAhead(now: now, window: window), 2);

      // Running it again plans nothing: the week already has its homework.
      // This is what stops every sync from filling the child's list.
      expect(await parent.store.planHomeworkAhead(now: now, window: window), 0);

      final homework = await parent.store.watchHomework().first;
      expect(homework, hasLength(2));
      expect(
        [for (final (_, h) in homework) h.dueAt],
        containsAll([
          DateTime.utc(2026, 9, 18, 6),
          DateTime.utc(2026, 9, 25, 6),
        ]),
      );

      // Friday's being done says nothing about next Friday's, and planning
      // again must not undo it.
      final (doneId, done) = homework.first;
      await parent.store.saveHomework(
        done.withState(HomeworkState.done),
        id: doneId,
      );
      expect(await parent.store.planHomeworkAhead(now: now, window: window), 0);
      final after = {
        for (final (id, h) in await parent.store.watchHomework().first)
          id: h.state,
      };
      expect(after[doneId], HomeworkState.done);

      await parent.close();
    });
  });

  group('actions', () {
    CalendarEvent saturdays({List<ExceptionEntry> exceptions = const []}) =>
        CalendarEvent(
          series: EventSeries(
            eventId: 'football',
            localStart: DateTime.utc(2026, 9, 5, 10),
            duration: const Duration(hours: 1),
            timeZone: 'Europe/Stockholm',
            rule: const RecurrenceRule(
              frequency: Frequency.weekly,
              byWeekday: {Weekday.sa},
            ),
            exceptions: exceptions,
          ),
          title: 'Football',
          kind: EventKind.activity,
        );

    test('a chore done together is everyone\'s, every time', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Wash the kit',
          kind: ActionKind.prep,
          offsetMinutes: -2 * 24 * 60,
          eventId: 'football',
          rotateAmong: ['anna', 'erik'],
          together: true,
        ),
      );
      await parent.store.planActionsAhead(
        [saturdays()],
        now: DateTime.utc(2026, 9, 19),
        window: const Duration(days: 14),
      );
      final all = [for (final (_, a) in await parent.store.watchActions().first) a];
      expect(all, hasLength(2));
      for (final a in all) {
        expect(a.assignees, ['anna', 'erik']);
      }
      await parent.close();
    });

    test('prep planned ahead once, on every device alike; cancelled with its '
        'occurrence', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Wash the kit',
          kind: ActionKind.prep,
          offsetMinutes: -2 * 24 * 60,
          eventId: 'football',
          rotateAmong: ['anna', 'erik'],
        ),
      );
      final now = DateTime.utc(2026, 9, 19);
      final window = const Duration(days: 14);
      expect(
        await parent.store.planActionsAhead(
          [saturdays()],
          now: now,
          window: window,
        ),
        2,
      );
      expect(
        await parent.store.planActionsAhead(
          [saturdays()],
          now: now,
          window: window,
        ),
        0,
      );
      final cancelled = saturdays(
        exceptions: [
          ExceptionEntry(
            originalStart: DateTime.utc(2026, 9, 26, 8),
            type: ExceptionType.cancelled,
          ),
        ],
      );
      expect(
        await parent.store.planActionsAhead(
          [cancelled],
          now: now,
          window: window,
        ),
        1,
      );
      final actions = {
        for (final (_, a) in await parent.store.watchActions().first)
          a.occurrenceStart!.day: (a.assignedTo, a.state),
      };
      expect(actions, {
        19: ('anna', ActionState.open),
        26: ('erik', ActionState.cancelled),
      });
      await parent.close();
    });

    test('a rota with an end date stops at it', () async {
      // A term ends. Before this, a weekly chore ran for ever because
      // nothing ever asked whether it should.
      final parent = await device('parent', parentKeys);
      await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Wash the kit',
          kind: ActionKind.prep,
          offsetMinutes: -2 * 24 * 60,
          eventId: 'football',
          rotateAmong: ['anna'],
        ),
      );
      final now = DateTime.utc(2026, 9, 19);
      // Saturdays, ending after the second one.
      final ending = CalendarEvent(
        series: EventSeries(
          eventId: 'football',
          localStart: DateTime.utc(2026, 9, 19, 8),
          duration: const Duration(hours: 2),
          timeZone: 'Europe/Stockholm',
          rule: RecurrenceRule(
            frequency: Frequency.weekly,
            byWeekday: const {Weekday.sa},
            until: DateTime.utc(2026, 9, 27),
          ),
        ),
        title: 'Football',
        kind: EventKind.activity,
      );
      await parent.store.planActionsAhead(
        [ending],
        now: now,
        window: const Duration(days: 60),
      );
      final days = [
        for (final (_, a) in await parent.store.watchActions().first)
          a.occurrenceStart!.day,
      ]..sort();
      // The 19th and the 26th, and nothing in October.
      expect(days, [19, 26]);
      await parent.close();
    });

    test('pausing a chore takes its open to-dos back', () async {
      // Reported: a paused rota kept handing out chores. Planning skipped
      // a paused template entirely, so every to-do it had already written
      // stood there for ever, and pausing stopped nothing anyone could see.
      final parent = await device('parent', parentKeys);
      final templateId = await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Wash the kit',
          kind: ActionKind.prep,
          offsetMinutes: -2 * 24 * 60,
          eventId: 'football',
          rotateAmong: ['anna', 'erik'],
        ),
      );
      final now = DateTime.utc(2026, 9, 19);
      const window = Duration(days: 14);
      await parent.store.planActionsAhead(
        [saturdays()],
        now: now,
        window: window,
      );
      expect(
        (await parent.store.watchActions().first)
            .where((a) => a.$2.isOpen)
            .length,
        2,
      );

      final paused = Payload.decode(
        (await parent.store.payloadOf(templateId))!.encode(),
      )..setBoolean('paused', true);
      await parent.store.saveActionTemplate(
        ActionTemplatePayload.read(paused),
        id: templateId,
      );
      await parent.store.planActionsAhead(
        [saturdays()],
        now: now,
        window: window,
      );

      final states = [
        for (final (_, a) in await parent.store.watchActions().first) a.state,
      ];
      expect(states, everyElement(ActionState.cancelled));

      // And it stays stopped: a second pass writes nothing more.
      expect(
        await parent.store.planActionsAhead(
          [saturdays()],
          now: now,
          window: window,
        ),
        0,
      );
      await parent.close();
    });

    test('a chore already done stays done when the rota is paused', () async {
      // The past is not rewritten because someone paused next week.
      final parent = await device('parent', parentKeys);
      final templateId = await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Wash the kit',
          kind: ActionKind.prep,
          offsetMinutes: -2 * 24 * 60,
          eventId: 'football',
          rotateAmong: ['anna'],
        ),
      );
      final now = DateTime.utc(2026, 9, 19);
      const window = Duration(days: 14);
      await parent.store.planActionsAhead(
        [saturdays()],
        now: now,
        window: window,
      );
      final first = (await parent.store.watchActions().first).first;
      await parent.store.completeAction(first.$1);

      final paused = Payload.decode(
        (await parent.store.payloadOf(templateId))!.encode(),
      )..setBoolean('paused', true);
      await parent.store.saveActionTemplate(
        ActionTemplatePayload.read(paused),
        id: templateId,
      );
      await parent.store.planActionsAhead(
        [saturdays()],
        now: now,
        window: window,
      );

      final done = (await parent.store.watchActions().first)
          .where((a) => a.$1 == first.$1)
          .single;
      expect(done.$2.state, ActionState.done);
      await parent.close();
    });

    test('a chore deleted on purpose does not come back next time', () async {
      // Reported from a real family: a recurring chore could not be got rid
      // of. Planning saw only live actions, so a deleted one looked like one
      // never made, and the next sync wrote it again — every time, for ever.
      // The importers here already keep this rule ("deleted stays deleted");
      // planning did not.
      final parent = await device('parent', parentKeys);
      await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Empty the dishwasher',
          kind: ActionKind.chore,
          schedule: EventPayload.write(
            title: 'Empty the dishwasher',
            kind: EventKind.actionBlock,
            localStart: DateTime.utc(2026, 9, 21, 17),
            duration: Duration.zero,
            timeZone: 'Europe/Stockholm',
            rule: const RecurrenceRule(
              frequency: Frequency.weekly,
              byWeekday: {Weekday.mo},
            ),
          ),
          assignee: 'anna',
        ),
      );
      final now = DateTime.utc(2026, 9, 21);
      const window = Duration(days: 21);

      final planned = await parent.store.planActionsAhead(
        const [],
        now: now,
        window: window,
      );
      expect(planned, greaterThan(1), reason: 'several Mondays ahead');

      final chores = await parent.store.watchActions().first;
      final doomed = chores.first.$1;
      await parent.store.delete(ObjectKind.action, doomed);

      expect(
        await parent.store.planActionsAhead(const [], now: now, window: window),
        0,
        reason: 'nothing to write: the rest are there and that one was refused',
      );
      expect(
        (await parent.store.watchActions().first).map((a) => a.$1),
        isNot(contains(doomed)),
      );
      await parent.close();
    });

    test('moving a chore to another day does not leave the old one', () async {
      // Editing a chore is new, and it opened this: planning only ever
      // created, so a chore moved from Mondays to Tuesdays kept its
      // Mondays and gained Tuesdays beside them — which reads as the chore
      // having doubled rather than moved.
      final parent = await device('parent', parentKeys);
      EventPayload weekly(Weekday day) => EventPayload.write(
        title: 'Bins',
        kind: EventKind.actionBlock,
        localStart: DateTime.utc(2026, 9, 21, 17),
        duration: Duration.zero,
        timeZone: 'Europe/Stockholm',
        rule: RecurrenceRule(frequency: Frequency.weekly, byWeekday: {day}),
      );

      final templateId = await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Bins',
          kind: ActionKind.chore,
          schedule: weekly(Weekday.mo),
          assignee: 'anna',
        ),
      );
      final now = DateTime.utc(2026, 9, 21);
      const window = Duration(days: 21);
      await parent.store.planActionsAhead(const [], now: now, window: window);

      Future<Set<int>> openWeekdays() async => {
        for (final (_, a) in await parent.store.watchActions().first)
          if (a.isOpen && a.occurrenceStart != null)
            a.occurrenceStart!.weekday,
      };
      expect(await openWeekdays(), {DateTime.monday});

      await parent.store.saveActionTemplate(
        ActionTemplatePayload.write(
          title: 'Bins',
          kind: ActionKind.chore,
          schedule: weekly(Weekday.tu),
          assignee: 'anna',
        ),
        id: templateId,
      );
      await parent.store.planActionsAhead(const [], now: now, window: window);

      expect(await openWeekdays(), {DateTime.tuesday});
      await parent.close();
    });

    test('a parent marks a child\'s finished chore seen, once, until reopened',
        () async {
      final parent = await device('parent', parentKeys);
      final child = await device('child', childKeys);
      final id = await parent.store.saveAction(
        ActionPayload.write(title: 'Feed the cat', assignedTo: 'member-child'),
      );
      await parent.store.sync();
      await child.store.sync();
      await child.store.completeAction(id);
      await child.store.sync();
      await parent.store.sync();

      var a = ActionPayload.read((await parent.store.payloadOf(id))!);
      expect(a.seenBy, isNull);
      await parent.store.markActionSeen(id);
      a = ActionPayload.read((await parent.store.payloadOf(id))!);
      expect(a.seenBy, 'member-parent');
      expect(a.seenAt, isNotNull);
      expect(a.state, ActionState.done, reason: 'seeing is not approving');
      expect(a.history.last.what, 'seen');

      // Done again after a reopen is new: it needs seeing again.
      await parent.store.sync();
      await child.store.sync();
      await child.store.reopenAction(id);
      await child.store.completeAction(id);
      a = ActionPayload.read((await child.store.payloadOf(id))!);
      expect(a.seenBy, isNull);
      await parent.close();
      await child.close();
    });

    test(
      'claim, delegate, decline back to the asker, then done and approved',
      () async {
        final parent = await device('parent', parentKeys);
        final child = await device('child', childKeys);
        final id = await parent.store.saveAction(
          ActionPayload.write(
            title: 'Empty the dishwasher',
            requiresApproval: true,
          ),
        );
        await parent.store.sync();
        await child.store.sync();
        await child.store.claimAction(id);
        await child.store.delegateAction(id, 'member-parent', note: 'homework');
        await child.store.sync();
        await parent.store.sync();
        var a = ActionPayload.read((await parent.store.payloadOf(id))!);
        expect(a.assignedTo, 'member-child');
        expect(a.delegation?.to, 'member-parent');
        await parent.store.answerDelegation(
          id,
          accept: false,
          note: 'nice try',
        );
        await parent.store.sync();
        await child.store.sync();
        a = ActionPayload.read((await child.store.payloadOf(id))!);
        expect(
          a.assignedTo,
          'member-child',
          reason: 'declined goes back, not to the pool',
        );
        expect(a.delegation, isNull);
        await child.store.completeAction(id);
        a = ActionPayload.read((await child.store.payloadOf(id))!);
        expect(a.awaitingApproval, isTrue);
        await child.store.sync();
        await parent.store.sync();
        await parent.store.approveAction(id);
        a = ActionPayload.read((await parent.store.payloadOf(id))!);
        expect(a.state, ActionState.approved);
        expect(a.completedBy, 'member-child');
        expect(
          [for (final s in a.history) s.what],
          ['claimed', 'delegated', 'declined', 'done', 'approved'],
        );
        await parent.close();
        await child.close();
      },
    );
  });

  group('meal polls', () {
    Future<String> openPoll(TestDevice d, {DateTime? closes}) =>
        d.store.savePoll(
          MealPollPayload.write(
            title: 'Torsdag',
            date: DateTime.utc(2026, 9, 24),
            closesAt: closes ?? DateTime.utc(2026, 9, 23, 18),
            eligible: ['member-parent', 'member-child'],
            createdBy: 'member-parent',
            options: const [
              MealPollOption(id: 'a', proposer: 'member-child', title: 'Tacos'),
              MealPollOption(
                id: 'b',
                proposer: 'member-parent',
                recipeId: 'curry',
              ),
            ],
          ),
        );

    test(
      'everyone votes from their own device; the winner is dinner',
      () async {
        final parent = await device('parent', parentKeys);
        final child = await device('child', childKeys);
        final poll = await openPoll(parent);
        await parent.store.sync();
        await child.store.sync();
        await child.store.castVote(poll, 'member-child', {'a'});
        await child.store.castVote(poll, 'member-child', {'a', 'b'});
        await parent.store.castVote(poll, 'member-parent', {'b'});
        await child.store.sync();
        await parent.store.sync();
        await parent.store.closePoll(poll, now: DateTime.utc(2026, 9, 23, 18));
        final closed = MealPollPayload.read(
          (await parent.store.payloadOf(poll))!,
        );
        expect(closed.state, PollState.closed);
        expect(closed.winner, 'b');
        expect(closed.overriddenBy, isNull);
        final (_, meal) = (await parent.store.watchMeals().first).single;
        expect(meal.date, DateTime.utc(2026, 9, 24));
        expect(meal.recipes.single.recipeId, 'curry');
        await parent.close();
        await child.close();
      },
    );

    test('a parent override shows beside what the vote said', () async {
      final parent = await device('parent', parentKeys);
      final poll = await openPoll(parent);
      await parent.store.castVote(poll, 'member-parent', {'b'});
      await parent.store.closePoll(
        poll,
        override: 'a',
        overriddenBy: 'member-parent',
      );
      final closed = MealPollPayload.read(
        (await parent.store.payloadOf(poll))!,
      );
      expect(
        (closed.winner, closed.votedWinner, closed.overriddenBy),
        ('a', 'b', 'member-parent'),
      );
      expect((await parent.store.watchMeals().first).single.$2.title, 'Tacos');
      await parent.close();
    });

    test('polls close themselves when their time is up', () async {
      final parent = await device('parent', parentKeys);
      await openPoll(parent, closes: DateTime.utc(2026, 9, 23, 18));
      expect(
        await parent.store.closeDuePolls(now: DateTime.utc(2026, 9, 23, 17)),
        0,
      );
      expect(
        await parent.store.closeDuePolls(now: DateTime.utc(2026, 9, 23, 18)),
        1,
      );
      expect(
        await parent.store.closeDuePolls(now: DateTime.utc(2026, 9, 24)),
        0,
      );
      await parent.close();
    });

    test('once everyone asked has answered, it closes early', () async {
      // Nothing more is coming, so waiting for the clock only keeps the
      // family from the answer. Closing is what tells everyone the result.
      final parent = await device('parent', parentKeys);
      final poll = await openPoll(parent);
      final early = DateTime.utc(2026, 9, 23, 9);

      await parent.store.castVote(poll, 'member-parent', {'b'});
      expect(await parent.store.closeDuePolls(now: early), 0,
          reason: 'one of two has answered');

      await parent.store.castVote(poll, 'member-child', {'a', 'b'});
      expect(await parent.store.closeDuePolls(now: early), 1);
      final closed = MealPollPayload.read((await parent.store.payloadOf(poll))!);
      expect(closed.state, PollState.closed);
      expect(closed.winner, 'b');
      await parent.close();
    });

    test('a vote from someone not asked does not count towards everyone', () async {
      final parent = await device('parent', parentKeys);
      final poll = await openPoll(parent);
      final early = DateTime.utc(2026, 9, 23, 9);
      await parent.store.castVote(poll, 'member-parent', {'b'});
      await parent.store.castVote(poll, 'someone-else', {'a'});
      expect(await parent.store.closeDuePolls(now: early), 0);
      await parent.close();
    });
  });

  group("a child's world", () {
    test('things go only where a seed has been earned', () async {
      // How far a child has come is counted, never stored, so the one
      // thing that must not be possible is placing something with no
      // finished work behind it.
      final parent = await device('parent', parentKeys);
      expect(
        await parent.store.placeInWorld(
          'maja',
          level: 1,
          spot: 0,
          thing: 'sunflower',
          waiting: 0,
        ),
        isFalse,
      );
      expect(await parent.store.watchWorlds().first, isEmpty);

      expect(
        await parent.store.placeInWorld(
          'maja',
          level: 1,
          spot: 0,
          thing: 'sunflower',
          waiting: 1,
        ),
        isTrue,
      );
      final (id, world) = (await parent.store.watchWorlds().first).single;
      expect(id, FamilyStore.worldIdFor('maja'));
      expect(world.placedIn(1)[0]!.thing, 'sunflower');
      await parent.close();
    });

    test('changing your mind about a spot needs no new seed', () async {
      final parent = await device('parent', parentKeys);
      await parent.store.placeInWorld(
        'maja', level: 1, spot: 0, thing: 'tulip', waiting: 1);
      expect(
        await parent.store.placeInWorld(
          'maja', level: 1, spot: 0, thing: 'rose', waiting: 0),
        isTrue,
      );
      final (_, world) = (await parent.store.watchWorlds().first).single;
      expect(world.placedIn(1).length, 1);
      expect(world.placedIn(1)[0]!.thing, 'rose');
      await parent.close();
    });

    City cityFor(List<CityLot> lots, {int seeds = 3, DateTime? today}) => cityOf(
      'maja',
      contributions: [
        for (var i = 0; i < seeds; i++)
          Contribution(
            memberId: 'maja',
            at: DateTime.utc(2026, 9, 1, 8, i),
            growsWorld: true,
          ),
      ],
      lots: lots,
      jarEverFull: false,
      today: today ?? DateTime.utc(2026, 9, 22),
    );

    Future<List<CityLot>> built(TestDevice d) async =>
        (await d.store.watchWorlds().first).single.$2.city;

    City grownCity(String who, List<CityLot> lots) => cityOf(
      who,
      contributions: [
        for (var i = 0; i < 12; i++)
          Contribution(
            memberId: who,
            at: DateTime.utc(2026, 9, 1, 8, i),
            growsWorld: true,
          ),
      ],
      lots: lots,
      jarEverFull: false,
      today: DateTime.utc(2026, 9, 22),
    );

    Future<List<CityLot>> cityOfMember(TestDevice d, String who) async => [
      for (final (_, w) in await d.store.watchWorlds().first)
        if (w.memberId == who) ...w.city,
    ];

    test('a sibling\'s trading house makes something the first one does not',
        () async {
      final child = await device('child', childKeys);
      final sibling = await device('sibling', childKeys);
      expect(
        await sibling.store.buildTradingHouse(
          'member-sibling',
          grownCity('member-sibling', const []),
          x: 9,
          y: 9,
        ),
        isTrue,
      );
      await sibling.store.sync();
      await child.store.sync();
      expect(
        await child.store.buildTradingHouse(
          'member-child',
          grownCity('member-child', const []),
          x: 9,
          y: 9,
        ),
        isTrue,
      );
      final theirs = (await cityOfMember(child, 'member-sibling')).single;
      final mine = (await cityOfMember(child, 'member-child')).single;
      expect(theirs.zone, Zone.market);
      expect(mine.good, isNotNull);
      expect(mine.good, isNot(theirs.good));
      // One trading house a city.
      expect(
        await child.store.buildTradingHouse(
          'member-child',
          grownCity('member-child', [mine]),
          x: 10,
          y: 9,
        ),
        isFalse,
      );
      await child.close();
      await sibling.close();
    });

    test('a special building is kept with which one it is', () async {
      final child = await device('child', childKeys);
      final house = CityLot(
        x: 9,
        y: 9,
        zone: Zone.market,
        at: DateTime.utc(2026, 9, 2),
        good: Good.stone,
      );
      final city = grownCity('member-child', [house]);
      expect(
        await child.store.buildLandmark(
          'member-child',
          city,
          Landmark.castle,
          x: 10,
          y: 9,
          have: const {Good.stone: 3, Good.wool: 2},
        ),
        isFalse,
        reason: 'one stone short',
      );
      expect(
        await child.store.buildLandmark(
          'member-child',
          city,
          Landmark.castle,
          x: 10,
          y: 9,
          have: const {Good.stone: 4, Good.wool: 2},
        ),
        isTrue,
      );
      final castle = (await cityOfMember(child, 'member-child')).single;
      expect((castle.zone, castle.landmark), (Zone.landmark, Landmark.castle));
      await child.close();
    });

    test('a service is paid for, and kept with what paid for it', () async {
      final child = await device('child', childKeys);
      final city = grownCity('member-child', const []);
      expect(
        await child.store.buildService(
          'member-child',
          city,
          Service.fire,
          x: 9,
          y: 9,
          coins: 10,
          have: const {Good.stone: 3},
          paid: const {Good.stone: 1},
        ),
        isFalse,
        reason: 'a fire station takes two goods',
      );
      expect(
        await child.store.buildService(
          'member-child',
          city,
          Service.fire,
          x: 9,
          y: 9,
          coins: 5,
          have: const {Good.stone: 3},
          paid: const {Good.stone: 2},
        ),
        isFalse,
        reason: 'a coin short',
      );
      expect(
        await child.store.buildService(
          'member-child',
          city,
          Service.fire,
          x: 9,
          y: 9,
          coins: 6,
          have: const {Good.stone: 3},
          paid: const {Good.stone: 2},
        ),
        isTrue,
      );
      final station = (await cityOfMember(child, 'member-child')).single;
      expect((station.zone, station.service), (Zone.service, Service.fire));
      expect(station.paid, {Good.stone: 2});
      await child.close();
    });

    test('a parent\'s present is kept with the parent', () async {
      final parent = await device('parent', parentKeys);
      expect(
        await parent.store.givePresent(
          from: 'member-parent',
          to: 'member-child',
          coins: maxGiftCoins + 1,
        ),
        isFalse,
      );
      expect(
        await parent.store.givePresent(
          from: 'member-parent',
          to: 'member-child',
          coins: 5,
          note: ' For helping grandma ',
        ),
        isTrue,
      );
      await parent.store.givePresent(
        from: 'member-parent',
        to: CityGift.family,
        good: Good.wood,
        count: 2,
      );
      final world = (await parent.store.watchWorlds().first).single.$2;
      expect(world.memberId, 'member-parent');
      expect(world.presents.first.coins, 5);
      expect(world.presents.first.note, 'For helping grandma');
      expect(world.presents.last.to, CityGift.family);
      await parent.close();
    });

    test('a building goes up along the path chosen, and keeps it', () async {
      final child = await device('child', childKeys);
      City town(List<CityLot> lots) => cityOf(
        'member-child',
        contributions: [
          for (var i = 0; i < 8; i++)
            Contribution(
              memberId: 'member-child',
              at: DateTime.utc(2026, 10, 2, 8, i),
              growsWorld: true,
            ),
        ],
        lots: lots,
        jarEverFull: false,
        today: DateTime.utc(2026, 10, 20),
      );
      await child.store.buildInCity(
        'member-child',
        town(const []),
        x: 9,
        y: 9,
        zone: Zone.home,
        now: DateTime.utc(2026, 10, 1),
      );
      final built = await cityOfMember(child, 'member-child');
      expect(town(built).canUpgrade(9, 9), isTrue);
      expect(
        await child.store.upgradeInCity('member-child', town(built),
            x: 9, y: 9, path: UpgradePath.cafe),
        isFalse,
        reason: 'a home has no café path',
      );
      expect(
        await child.store.upgradeInCity('member-child', town(built),
            x: 9, y: 9, path: UpgradePath.garden),
        isTrue,
      );
      final after = await cityOfMember(child, 'member-child');
      expect(after.single.upgrades.single.path, UpgradePath.garden);
      expect(town(after).sizeOf(9, 9), 1);
      expect(town(after).canUpgrade(9, 9), isFalse);
      await child.close();
    });

    test('going to an activity counts once, as being active', () async {
      final child = await device('child', childKeys);
      final start = DateTime.utc(2026, 10, 3, 9);
      for (var i = 0; i < 2; i++) {
        await child.store.markAttended(
          eventId: 'football',
          occurrenceStart: start,
          member: 'member-child',
          title: 'Football',
        );
      }
      expect(
        await child.store.attended('football', start, 'member-child'),
        isTrue,
      );
      final counted = await child.store.contributions();
      expect(counted, hasLength(1), reason: 'ticked twice, counted once');
      expect(counted.single.isActivity, isTrue);
      expect(counted.single.memberId, 'member-child');
      await child.close();
    });

    test('a child\'s logged activity waits for a parent', () async {
      final child = await device('child', childKeys);
      await child.store.logActivity(
        title: '30 min cycling',
        needsApproval: true,
      );
      expect(await child.store.contributions(), isEmpty);
      final (_, logged) = (await child.store.watchActions().first).single;
      expect(logged.kind, ActionKind.activity);
      expect(logged.awaitingApproval, isTrue);
      await child.close();
    });

    test('a sports building is placed once being active unlocks it',
        () async {
      final child = await device('child', childKeys);
      City town(int active) => cityOf(
        'member-child',
        contributions: [
          for (var i = 0; i < active; i++)
            Contribution(
              memberId: 'member-child',
              at: DateTime.utc(2026, 10, 2, 8, i),
              growsWorld: true,
              isActivity: true,
            ),
        ],
        lots: const [],
        jarEverFull: false,
        today: DateTime.utc(2026, 10, 20),
      );
      expect(
        await child.store.buildSport('member-child', town(2), Sport.pitch,
            x: 9, y: 9),
        isFalse,
        reason: 'three times active first',
      );
      expect(
        await child.store.buildSport('member-child', town(3), Sport.pitch,
            x: 9, y: 9),
        isTrue,
      );
      final pitch = (await cityOfMember(child, 'member-child')).single;
      expect((pitch.zone, pitch.sport), (Zone.sport, Sport.pitch));
      expect(pitch.takesSeed, isFalse);
      await child.close();
    });

    test('sales, gifts and a goal are kept beside the city', () async {
      final child = await device('child', childKeys);
      await child.store.buildInCity(
        'member-child',
        grownCity('member-child', const []),
        x: 9,
        y: 9,
        zone: Zone.home,
      );
      expect(
        await child.store.sellGoods('member-child', Good.fish, 3,
            have: const {Good.fish: 2}),
        isFalse,
      );
      expect(
        await child.store.sellGoods('member-child', Good.fish, 2,
            have: const {Good.fish: 2}),
        isTrue,
      );
      await child.store.giveToProject('member-child', Good.fish, 1,
          have: const {Good.fish: 1});
      await child.store.setCityGoal('member-child', 'landmark:castle');
      final world = (await child.store.watchWorlds().first).single.$2;
      expect(world.city, hasLength(1), reason: 'the home is still there');
      expect(world.sales.single.count, 2);
      expect(world.gifts.single.good, Good.fish);
      expect(world.goal, 'landmark:castle');
      await child.store.setCityGoal('member-child', '');
      expect((await child.store.watchWorlds().first).single.$2.goal, isNull);
      await child.close();
    });

    test('an offer is answered only by the child asked, or taken back', () async {
      final child = await device('child', childKeys);
      final sibling = await device('sibling', childKeys);
      final id = (await child.store.offerTrade(
        to: 'member-sibling',
        give: Good.fish,
        get: Good.wood,
        count: 2,
      ))!;
      expect(
        await child.store.offerTrade(
          to: 'member-sibling',
          give: Good.fish,
          get: Good.fish,
          count: 2,
        ),
        isNull,
        reason: 'fish for fish is not a trade',
      );
      expect(await child.store.answerTrade(id, accept: true), isFalse,
          reason: 'not yours to accept');
      await child.store.sync();
      await sibling.store.sync();
      expect(await sibling.store.withdrawTrade(id), isFalse,
          reason: 'not yours to take back');
      expect(await sibling.store.answerTrade(id, accept: true), isTrue);
      await sibling.store.sync();
      await child.store.sync();
      final (_, t) = (await child.store.watchTrades().first).single;
      final trade = t.toTrade(id)!;
      expect(trade.state, TradeState.accepted);
      expect(trade.agreed, isTrue);
      expect(await child.store.withdrawTrade(id), isFalse,
          reason: 'already answered');
      await child.close();
      await sibling.close();
    });

    test('a city is built only where the city says it may be', () async {
      final parent = await device('parent', parentKeys);
      expect(
        await parent.store.buildInCity(
          'maja', cityFor(const [], seeds: 0), x: 8, y: 9, zone: Zone.home),
        isFalse,
        reason: 'no seed to spend',
      );
      expect(
        await parent.store.buildInCity(
          'maja', cityFor(const []), x: City.centre, y: 9, zone: Zone.home),
        isFalse,
        reason: 'the main street',
      );
      expect(
        await parent.store.buildInCity(
          'maja', cityFor(const []), x: 8, y: 9, zone: Zone.home),
        isTrue,
      );
      expect([for (final l in await built(parent)) (l.x, l.y, l.zone)], [
        (8, 9, Zone.home),
      ]);
      await parent.close();
    });

    test("today's building can be changed or taken back; yesterday's cannot", () async {
      final parent = await device('parent', parentKeys);
      final today = DateTime.utc(2026, 9, 22);
      await parent.store.buildInCity(
        'maja', cityFor(const [], today: today),
        x: 8, y: 9, zone: Zone.home, now: DateTime.utc(2026, 9, 22, 15));

      var lots = await built(parent);
      expect(
        await parent.store.changeCityLot(
          'maja', cityFor(lots, today: today), x: 8, y: 9, zone: Zone.park),
        isTrue,
      );
      lots = await built(parent);
      expect(lots.single.zone, Zone.park);

      // Tomorrow it is there for good.
      final tomorrow = DateTime.utc(2026, 9, 23);
      expect(
        await parent.store.changeCityLot(
          'maja', cityFor(lots, today: tomorrow), x: 8, y: 9, zone: Zone.home),
        isFalse,
      );
      expect(
        await parent.store.changeCityLot(
          'maja', cityFor(lots, today: tomorrow), x: 8, y: 9),
        isFalse,
        reason: 'no bulldozer',
      );
      expect((await built(parent)).single.zone, Zone.park);

      // And taken back on the day, which gives its seed back.
      await parent.store.buildInCity(
        'maja', cityFor(lots, today: tomorrow),
        x: 9, y: 9, zone: Zone.home, now: DateTime.utc(2026, 9, 23, 9));
      lots = await built(parent);
      expect(
        await parent.store.changeCityLot(
          'maja', cityFor(lots, today: tomorrow), x: 9, y: 9),
        isTrue,
      );
      expect([for (final l in await built(parent)) (l.x, l.y)], [(8, 9)]);
      await parent.close();
    });

    test('a new theme keeps everything already placed', () async {
      // Swapping a garden for an aquarium does not undo the work that
      // grew it.
      final parent = await device('parent', parentKeys);
      await parent.store.placeInWorld(
        'maja', level: 1, spot: 4, thing: 'tulip', waiting: 1);
      await parent.store.chooseWorldTheme('maja', WorldTheme.aquarium);
      final (_, world) = (await parent.store.watchWorlds().first).single;
      expect(world.theme, WorldTheme.aquarium);
      expect(world.placedIn(1).keys, {4});
      await parent.close();
    });
  });

  group('feed links', () {
    test('laget.se pages, webcal and https', () {
      expect(
        feedUrl('https://www.laget.se/LIF2003_F15/Event/Month'),
        'https://cal.laget.se/LIF2003_F15.ics',
      );
      expect(
        feedUrl('webcal://cal.laget.se/LIF2003_F15.ics'),
        'https://cal.laget.se/LIF2003_F15.ics',
      );
      expect(
        feedUrl(' https://example.com/school.ics '),
        'https://example.com/school.ics',
      );
      expect(feedUrl('not a link'), isNull);
      expect(feedUrl('ftp://example.com/a.ics'), isNull);
    });
  });
}
