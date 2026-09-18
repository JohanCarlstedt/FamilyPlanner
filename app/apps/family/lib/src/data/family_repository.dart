import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_providers.dart';

/// The family's zone: recurrence and day boundaries use it. Every family is
/// created in Stockholm for now; the server stores it, and the client will
/// read it from there once families elsewhere matter.
const familyTimeZone = 'Europe/Stockholm';

/// Read access to the family's decrypted content, as live streams.
abstract interface class FamilyRepository {
  /// IANA zone the family lives in. Recurrence and day boundaries use it.
  String get timeZone;

  Stream<List<Member>> watchMembers();

  Stream<List<CalendarEvent>> watchEvents();
}

/// The family's real content, from the encrypted local store.
class SyncedFamilyRepository implements FamilyRepository {
  SyncedFamilyRepository(this._store);

  final FamilyStore _store;

  @override
  String get timeZone => familyTimeZone;

  @override
  Stream<List<Member>> watchMembers() => _store.watchProfiles().map(
    (profiles) => [for (final (id, p) in profiles) p.toDomain(id)],
  );

  @override
  Stream<List<CalendarEvent>> watchEvents() => _store.watchEvents().map(
    (events) => [for (final (id, e) in events) ?e.toDomain(id)],
  );
}

final familyRepositoryProvider = FutureProvider<FamilyRepository>((ref) async {
  final store = await ref.watch(familyStoreProvider.future);
  return SyncedFamilyRepository(store);
});

final membersProvider = StreamProvider<List<Member>>((ref) async* {
  final repository = await ref.watch(familyRepositoryProvider.future);
  yield* repository.watchMembers();
});

final eventsProvider = StreamProvider<List<CalendarEvent>>((ref) async* {
  final repository = await ref.watch(familyRepositoryProvider.future);
  yield* repository.watchEvents();
});
