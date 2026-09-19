import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../api/family_api_provider.dart';
import '../data/family_repository.dart';
import '../data/store_providers.dart';
import '../membership/membership.dart';
import '../pairing/device_providers.dart';

/// The family thread on this device. Built once per family and device: MLS
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

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) async* {
  final chat = await ref.watch(familyChatProvider.future);
  yield* chat.watch();
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

/// Follows the thread, then, on a parent's device, brings its members in
/// step: every trusted device of a parent or child, never a helper's (spec
/// §2: helpers never see chat from before they joined; their threads come
/// later). Returns the messages other devices sent since the last sync.
Future<List<ChatMessage>> syncFamilyChat(ChatReader read) async {
  final membership = await read(membershipProvider.future);
  if (membership == null) return const [];
  final chat = await read(familyChatProvider.future);
  final fresh = await chat.sync();
  if (membership.isParent) {
    final members = {
      for (final m in await read(membersProvider.future)) m.id: m,
    };
    final directory = await read(
      familyApiProvider,
    ).directory(asDevice: membership.deviceId, familyId: membership.familyId);
    final active = {
      for (final d in directory)
        if (!d.revoked && members[d.memberId]?.role != MemberRole.helper)
          d.deviceId,
    };
    await chat.reconcile(
      familyDevices: {
        for (final t in membership.trusted)
          if (active.contains(t.deviceId)) t.deviceId,
      },
      mayStart: true,
    );
  }
  return fresh;
}
