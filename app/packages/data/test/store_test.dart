import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

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

  setUpAll(initRustForHost);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('family_data');
    server = FakeServer();
    parentKeys = Keyring()
      ..generate(group: allGroup, epoch: 0)
      ..generate(group: adultsGroup, epoch: 0);
    // The child holds `all` only, delivered the way a grant would.
    final device = Device.generate();
    childKeys = Keyring()
      ..acceptGrant(
        grant: parentKeys.grant(
          group: allGroup,
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
}
