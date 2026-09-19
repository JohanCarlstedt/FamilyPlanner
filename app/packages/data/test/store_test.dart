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

  test('unlinking a feed takes its coming events with it', () async {
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
    expect([for (final (_, e) in left) e.localStart!.month], [9]);
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
