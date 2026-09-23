import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../api/family_api_provider.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../membership/membership.dart';
import '../pairing/pairing_service.dart';
import '../pairing/device_providers.dart';

/// The family's chat on this device. Built once per family and device: MLS
/// state must never be driven from two instances at once, so it isn't
/// rebuilt when trust changes; it reads the current trust list each time.
final familyChatProvider = FutureProvider<FamilyChat>((ref) async {
  final ids = await ref.watch(
    membershipProvider.selectAsync(
      (m) => m == null ? null : (m.familyId, m.deviceId),
    ),
  );
  if (ids == null) throw StateError('no family on this device yet');
  final (familyId, deviceId) = ids;
  final (_, queue) = await ref.watch(localDatabasesProvider.future);
  return FamilyChat(
    db: queue,
    api: ref.watch(familyApiProvider),
    familyId: familyId,
    deviceId: deviceId,
    device: await ref.watch(deviceProvider.future),
    trusted: () =>
        ref.read(membershipProvider).value?.trustedSigners ?? const [],
  );
});

/// Every thread this device is in, the family's first.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) async* {
  final chat = await ref.watch(familyChatProvider.future);
  yield* chat.watchConversations();
});

/// One thread's messages, oldest first.
final threadProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  group,
) async* {
  final chat = await ref.watch(familyChatProvider.future);
  yield* chat.watch(group);
});

/// Which member each device belongs to, for naming senders.
final deviceMembersProvider = FutureProvider<Map<String, String>>((ref) async {
  ref.watch(membersProvider);
  final membership = await ref.watch(membershipProvider.future);
  if (membership == null) return const {};
  final directory = await ref
      .read(familyApiProvider)
      .directory(asDevice: membership.deviceId, familyId: membership.familyId);
  return {for (final d in directory) d.deviceId: d.memberId};
});

typedef ChatReader = T Function<T>(ProviderListenable<T> provider);

typedef DirectoryDevice = ({
  String deviceId,
  String memberId,
  bool revoked,
  String platform,
});

/// Who belongs in this family's threads, as far as this device can tell.
///
/// Three answers, not two. [byMember] may be added: trusted, active, and
/// never a helper's (spec §2: helpers never see chat) or a recovery kit.
/// [barred] must go wherever they are. Everything else — above all a
/// device this phone does not trust *yet* — is neither: left where it is,
/// never added. Trust spreads between devices one at a time, so treating
/// "not trusted here" as "remove" had two parents' phones throwing a
/// tablet out and putting it back on every sync.
class ChatDevices {
  ChatDevices._(this.byMember, this.barred, this._anyByMember);

  factory ChatDevices.from(
    Iterable<DirectoryDevice> directory, {
    required Iterable<Member> members,
    required Set<String> trusted,
  }) {
    final byId = {for (final m in members) m.id: m};
    final byMember = <String, Set<String>>{};
    final anyByMember = <String, Set<String>>{};
    final barred = <String>{};
    for (final d in directory) {
      final m = byId[d.memberId];
      if (d.revoked ||
          d.platform == 'recovery' ||
          // A wall tablet holds no chat keys (crypto doc §6): anyone in
          // the house, or visiting it, can read what's on it.
          d.platform == kitchenPlatform ||
          (m != null &&
              (!m.isActive || m.role == MemberRole.helper || m.isCoParent))) {
        barred.add(d.deviceId);
        continue;
      }
      // A member this phone has not synced yet: nothing known either way.
      if (m == null) continue;
      (anyByMember[d.memberId] ??= {}).add(d.deviceId);
      if (trusted.contains(d.deviceId)) {
        (byMember[d.memberId] ??= {}).add(d.deviceId);
      }
    }
    return ChatDevices._(byMember, barred, anyByMember);
  }

  final Map<String, Set<String>> byMember;
  final Set<String> barred;
  final Map<String, Set<String>> _anyByMember;

  /// Every device that may be added anywhere.
  Set<String> get all => {for (final d in byMember.values) ...d};

  /// What may be added to a thread [readers] read.
  Set<String> of(Set<String> readers) => devicesOf(byMember, readers);

  /// What has to leave a thread [readers] read: the barred, and the
  /// devices, trusted here or not, of known members who are not readers.
  Set<String> outside(Set<String> readers) => {
    ...barred,
    for (final e in _anyByMember.entries)
      if (!readers.contains(e.key)) ...e.value,
  };
}

Future<ChatDevices> chatDevices(ChatReader read) async {
  final membership = (await read(membershipProvider.future))!;
  final members = await read(membersProvider.future);
  final directory = await read(familyApiProvider)
      .directory(asDevice: membership.deviceId, familyId: membership.familyId);
  return ChatDevices.from(
    directory,
    members: members,
    trusted: {for (final t in membership.trusted) t.deviceId},
  );
}

/// The devices that may be in a thread, by member.
Future<Map<String, Set<String>>> chatDevicesByMember(ChatReader read) async =>
    (await chatDevices(read)).byMember;

Set<String> devicesOf(Map<String, Set<String>> byMember, Set<String> ids) => {
  for (final id in ids) ...?byMember[id],
};

/// Follows every thread, then brings their members in step: on a parent's
/// device, the family thread to every chat device; on any device, each
/// direct and group thread to its readers under the family's supervision
/// setting, announcing in the thread when who reads it changes. Returns
/// the messages other devices sent since the last sync.
Future<List<ChatMessage>> syncChat(ChatReader read) async {
  final membership = await read(membershipProvider.future);
  if (membership == null || membership.isKitchen) return const [];
  final chat = await read(familyChatProvider.future);
  final fresh = await chat.sync();
  ChatDevices? known;
  // Any device, not just a parent's: a phone out of step with its own
  // location group can only be let back in by someone who sees it.
  if (await chat.hasRejoins()) {
    known = await chatDevices(read);
    await chat.letBackIn(known.all);
  }
  final joined = await chat.joined();
  if (!membership.isParent && joined.isEmpty) return fresh;

  final devices = known ?? await chatDevices(read);
  if (membership.isParent) {
    await chat.reconcile(
      devices: devices.all,
      remove: devices.barred,
      mayStart: true,
    );
  }
  final members = await read(membersProvider.future);
  final settings = await read(settingsProvider.future);
  for (final c in joined) {
    final audience = ConversationAudience.of(
      participants: c.participants.toSet(),
      members: members,
      settings: settings,
    );
    final changed = await chat.reconcile(
      group: c.group,
      devices: devices.of(audience.readers),
      remove: devices.outside(audience.readers),
    );
    if (changed) await _announce(chat, c.group, audience);
  }
  return fresh;
}

/// Tells the thread who reads it without talking, unless it already says so.
Future<void> _announce(
  FamilyChat chat,
  String group,
  ConversationAudience audience,
) async {
  final said = (await chat.watch(group).first).lastWhere(
    (m) => m.kind == ChatMessageKind.readers,
    orElse: () => ChatMessage(
      id: '',
      group: group,
      sender: '',
      sentAt: DateTime(0),
      text: '',
      mine: false,
      kind: ChatMessageKind.readers,
    ),
  );
  final now = audience.supervisors;
  if (said.members.toSet().containsAll(now) && now.containsAll(said.members)) {
    return;
  }
  await chat.announceReaders(group, now.toList()..sort());
}

/// Starts a thread between this device's member and [others]: direct with
/// one, a group with more. Returns its group.
Future<String> startConversation(
  ChatReader read, {
  required List<String> others,
  String? title,
}) async {
  final membership = (await read(membershipProvider.future))!;
  final chat = await read(familyChatProvider.future);
  final participants = [membership.memberId, ...others];
  final audience = ConversationAudience.of(
    participants: participants.toSet(),
    members: await read(membersProvider.future),
    settings: await read(settingsProvider.future),
  );
  final group = await chat.start(
    scope: others.length == 1
        ? ConversationScope.direct
        : ConversationScope.group,
    participants: participants,
    devices: devicesOf(await chatDevicesByMember(read), audience.readers),
    title: others.length == 1 ? null : title,
  );
  if (chat.canTalkIn(group) && audience.isSupervised) {
    await _announce(chat, group, audience);
  }
  return group;
}
