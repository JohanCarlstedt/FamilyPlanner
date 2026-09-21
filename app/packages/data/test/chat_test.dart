import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// One phone in the family thread, with its own encrypted database.
class _Phone {
  _Phone(this.id) : device = Device.generate();

  final String id;
  final Device device;
  late QueueDatabase db;
  late FamilyChat chat;

  TrustedDevice get record =>
      TrustedDevice(deviceId: id, signingKey: device.signingPublicKey);

  void open(Directory dir, FakeServer server, List<_Phone> family) {
    db = QueueDatabase(
      openEncrypted(
        File('${dir.path}/$id-queue.db'),
        Uint8List.fromList(List.generate(32, (i) => i + id.length)),
      ),
    );
    chat = FamilyChat(
      db: db,
      api: server,
      familyId: 'fam-1',
      deviceId: id,
      device: device,
      trusted: () => [for (final p in family) p.record],
    );
  }

  Future<List<String>> heard() async => [
    for (final m in await chat.sync()) m.text,
  ];
}

void main() {
  late Directory dir;
  late FakeServer server;
  late _Phone anna;
  late _Phone erik;
  late _Phone tablet;
  late List<_Phone> family;

  setUpAll(initRustForHost);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chat');
    server = FakeServer();
    anna = _Phone('anna');
    erik = _Phone('erik');
    tablet = _Phone('maja-tablet');
    family = [anna, erik, tablet];
    for (final p in family) {
      p.open(dir, server, family);
      await p.chat.sync();
    }
  });

  tearDown(() async {
    for (final p in family) {
      await p.db.close();
    }
    await dir.delete(recursive: true);
  });

  Set<String> ids(List<_Phone> phones) => {for (final p in phones) p.id};

  test('a family talks in one thread', () async {
    await anna.chat.reconcile(devices: {'anna'}, mayStart: true);
    expect(
      anna.chat.canTalk,
      isFalse,
      reason: 'alone, there is no one to hear',
    );
    await anna.chat.reconcile(devices: ids(family), mayStart: true);
    expect(anna.chat.canTalk, isTrue);
    await erik.chat.sync();
    await tablet.chat.sync();

    await anna.chat.send('Middag 18');
    expect(await erik.heard(), ['Middag 18']);
    expect(await tablet.heard(), ['Middag 18']);

    await tablet.chat.send('OK!');
    expect(await anna.heard(), ['OK!']);
    await erik.chat.sync();
    final thread = await erik.chat.watch().first;
    expect([for (final m in thread) m.text], ['Middag 18', 'OK!']);
    expect(thread.first.sender, 'anna');
    expect(
      [for (final m in await anna.chat.watch().first) m.mine],
      [true, false],
    );
  });

  test('the thread survives a restart', () async {
    await anna.chat.reconcile(devices: ids(family), mayStart: true);
    await erik.chat.sync();

    await erik.db.close();
    erik.open(dir, server, family);
    await anna.chat.send('still here?');
    expect(await erik.heard(), ['still here?']);
  });

  test('two parents starting the thread at once end up in one', () async {
    // Erik starts his own before Anna's welcome reaches him.
    await anna.chat.reconcile(devices: ids(family), mayStart: true);
    await erik.chat.reconcile(devices: ids(family), mayStart: true);
    await erik.chat.sync();

    await erik.chat.send('one thread?');
    expect(await anna.heard(), ['one thread?']);
  });

  test('a removed tablet reads nothing after', () async {
    await anna.chat.reconcile(devices: ids(family), mayStart: true);
    await erik.chat.sync();
    await tablet.chat.sync();

    await anna.chat.reconcile(devices: ids([anna, erik]));
    await erik.chat.sync();
    await anna.chat.send('present ideas');
    expect(await erik.heard(), ['present ideas']);
    expect(await tablet.heard(), isEmpty);
  });

  test('a stranger slipped in by the server is refused', () async {
    final mallory = _Phone('mallory')..open(dir, server, family);
    await mallory.chat.sync();
    // The family doesn't trust mallory's device, whatever the server says.
    await anna.chat.reconcile(
      devices: {...ids(family), 'mallory'},
      mayStart: true,
    );
    await erik.chat.sync();
    await anna.chat.send('family only');
    expect(await mallory.heard(), isEmpty);
    await mallory.db.close();
  });

  group('direct and group conversations', () {
    setUp(() async {
      await anna.chat.reconcile(devices: ids(family), mayStart: true);
      await erik.chat.sync();
      await tablet.chat.sync();
    });

    test('two people talk where the rest cannot read', () async {
      final group = await anna.chat.start(
        scope: ConversationScope.direct,
        participants: ['anna', 'maja'],
        devices: ids([anna, tablet]),
      );
      expect(group, anna.chat.directGroup('maja', 'anna'));
      await anna.chat.send('Hämtar dig 15', group: group);
      expect(await tablet.heard(), ['Hämtar dig 15']);
      expect(await erik.heard(), isEmpty);

      final threads = await tablet.chat.conversations();
      expect(
        [for (final c in threads) c.scope],
        [ConversationScope.family, ConversationScope.direct],
      );
      expect(threads.last.participants, ['anna', 'maja']);
      expect(threads.last.unread, 1);
      await tablet.chat.markRead(group);
      expect((await tablet.chat.conversations()).last.unread, 0);
      expect(tablet.chat.readersOf(group), {'anna', 'maja-tablet'});

      // Starting it again is the same thread.
      expect(
        await tablet.chat.start(
          scope: ConversationScope.direct,
          participants: ['maja', 'anna'],
          devices: ids([anna, tablet]),
        ),
        group,
      );
    });

    test(
      'a parent brought in reads from then on, and is told what it is',
      () async {
        final group = await tablet.chat.start(
          scope: ConversationScope.group,
          title: 'Födelsedag',
          participants: ['maja', 'anna'],
          devices: ids([anna, tablet]),
        );
        await tablet.chat.send('before', group: group);
        await anna.chat.sync();

        expect(
          await anna.chat.reconcile(group: group, devices: ids(family)),
          isTrue,
        );
        await anna.chat.announceReaders(group, ['erik']);
        await tablet.chat.send('after', group: group);
        await erik.chat.sync();
        final thread = await erik.chat.watch(group).first;
        expect([for (final m in thread) m.text], ['', 'after']);
        expect(thread.first.kind, ChatMessageKind.readers);
        expect(thread.first.members, ['erik']);
        final named = (await erik.chat.conversations()).last;
        expect(named.title, 'Födelsedag');

        // Supervision ends: taken out, then asked back in later.
        await tablet.chat.sync();
        expect(
          await tablet.chat.reconcile(
            group: group,
            devices: ids([anna, tablet]),
          ),
          isTrue,
        );
        await tablet.chat.send('private', group: group);
        expect(await erik.heard(), isEmpty);
        expect(erik.chat.canTalkIn(group), isFalse);

        await anna.chat.sync();
        await anna.chat.reconcile(group: group, devices: ids(family));
        await tablet.chat.send('again', group: group);
        expect(await erik.heard(), ['again']);
      },
    );
  });

  test('an emoji on a message, and taken back', () async {
    await anna.chat.reconcile(devices: ids(family), mayStart: true);
    await erik.chat.sync();
    await tablet.chat.sync();
    final said = await anna.chat.send('Middag 18');

    await erik.chat.react(
      group: erik.chat.familyGroup,
      messageId: said.id,
      emoji: '👍',
    );
    await anna.chat.sync();
    final reactions = [
      for (final m in await anna.chat.watch().first)
        if (m.kind == ChatMessageKind.reaction)
          (m.text, m.reactionTo, m.removed),
    ];
    expect(reactions, [('👍', said.id, false)]);
    expect(
      (await anna.chat.conversations()).single.last?.text,
      'Middag 18',
      reason: 'the thread still shows what was said',
    );

    await erik.chat.react(
      group: erik.chat.familyGroup,
      messageId: said.id,
      emoji: '👍',
      remove: true,
    );
    await anna.chat.sync();
    expect(
      [
        for (final m in await anna.chat.watch().first)
          if (m.kind == ChatMessageKind.reaction) m.removed,
      ],
      [false, true],
    );
  });

  group('location (spec §7: latest only)', () {
    Uint8List at(String place) => PositionMessage(
      state: PositionState.sharing,
      position: SharedPosition(
        placeId: place,
        since: DateTime.utc(2026, 9, 21, 8),
        capturedAt: DateTime.utc(2026, 9, 21, 8, 12),
      ),
    ).encode().encode();

    Future<String?> placeSeenBy(_Phone p, String member) async {
      await p.chat.sync();
      final positions = await p.chat.watchPositions().first;
      final entry = positions[p.chat.locationGroup(member)];
      if (entry == null) return null;
      return PositionMessage.decode(entry.$2)?.position?.placeId;
    }

    test('viewers see only the latest, and nobody else sees it', () async {
      final viewers = ids([tablet, anna]);
      await tablet.chat.sync();
      await anna.chat.sync();
      await tablet.chat.sharePosition('maja', at('school'), viewers: viewers);
      await tablet.chat.sharePosition('maja', at('home'), viewers: viewers);

      expect(await placeSeenBy(anna, 'maja'), 'home');
      expect(await placeSeenBy(erik, 'maja'), isNull);
      final relayed = [
        for (final (m, _) in server.mlsLog)
          if (m.groupId == tablet.chat.locationGroup('maja') &&
              m.kind == 'application')
            m,
      ];
      expect(relayed, hasLength(1), reason: 'no trail on the server');
      final rows = await anna.db.select(anna.db.chatMessages).get();
      expect(
        rows.where((r) => r.groupId == anna.chat.locationGroup('maja')),
        hasLength(1),
        reason: 'no trail on the phone',
      );
      expect(await anna.chat.conversations(), hasLength(1));
    });

    test(
      'a viewer added later gets the latest at once; one taken out stops',
      () async {
        await anna.chat.sync();
        await tablet.chat.sharePosition(
          'maja',
          at('school'),
          viewers: ids([tablet, anna]),
        );
        await erik.chat.sync();
        await tablet.chat.sharePosition(
          'maja',
          at('school'),
          viewers: ids(family),
        );
        expect(await placeSeenBy(erik, 'maja'), 'school');

        await anna.chat.sync();
        await tablet.chat.sharePosition(
          'maja',
          at('home'),
          viewers: ids([tablet, erik]),
        );
        expect(await placeSeenBy(erik, 'maja'), 'home');
        expect(await placeSeenBy(anna, 'maja'), 'school');
        expect(anna.chat.seesLocationOf('maja'), isFalse);
      },
    );
  });

  group('taking back something you said', () {
    ChatMessage said(String id, String sender, String text) => ChatMessage(
      id: id,
      group: 'g',
      sender: sender,
      sentAt: DateTime.utc(2026, 9, 21, 18),
      text: text,
      mine: sender == 'me',
    );
    ChatMessage withdrawal(String id, String sender, String target) =>
        ChatMessage(
          id: id,
          group: 'g',
          sender: sender,
          sentAt: DateTime.utc(2026, 9, 21, 18, 1),
          text: '',
          mine: sender == 'me',
          kind: ChatMessageKind.withdrawal,
          reactionTo: target,
        );

    test('the words go, and that there was a line does not', () {
      final left = FamilyChat.withdrawalsApplied([
        said('m1', 'me', 'Oops wrong thread'),
        said('m2', 'me', 'Dinner at seven'),
        withdrawal('w1', 'me', 'm1'),
      ]);

      // A thread that silently loses a message reads as the app having
      // lost it, so what is left says something was taken back.
      expect(left.map((m) => m.id), ['m1', 'm2']);
      expect(left.first.text, isEmpty);
      expect(left.first.removed, isTrue);
      expect(left.last.text, 'Dinner at seven');
    });

    test('the withdrawal itself is not a message in the thread', () {
      final left = FamilyChat.withdrawalsApplied([
        said('m1', 'me', 'Hello'),
        withdrawal('w1', 'me', 'm1'),
      ]);

      expect(left.where((m) => m.kind == ChatMessageKind.withdrawal), isEmpty);
    });

    test('you cannot take back what someone else said', () {
      // Otherwise "delete your own message" becomes deleting anyone's.
      final left = FamilyChat.withdrawalsApplied([
        said('m1', 'anna', 'I will pick her up'),
        withdrawal('w1', 'me', 'm1'),
      ]);

      expect(left.single.text, 'I will pick her up');
      expect(left.single.removed, isFalse);
    });

    test('order does not matter: the withdrawal may arrive first', () {
      // A phone that was off comes back to both at once, in whatever
      // order the delivery service hands them over.
      final left = FamilyChat.withdrawalsApplied([
        withdrawal('w1', 'me', 'm1'),
        said('m1', 'me', 'Never mind'),
      ]);

      expect(left.single.id, 'm1');
      expect(left.single.removed, isTrue);
    });
  });
}
