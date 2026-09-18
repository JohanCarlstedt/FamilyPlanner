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
}
