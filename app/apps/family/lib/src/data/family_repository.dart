import 'dart:async';

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

  /// Events with their occurrence exceptions attached. The two are stored
  /// apart (spec §3 `event_exception`), so either changing re-emits.
  @override
  Stream<List<CalendarEvent>> watchEvents() => _combineLatest(
    _store.watchEvents(),
    _store.watchExceptions(),
    (events, exceptions) {
      final byEvent = <String, List<ExceptionEntry>>{};
      for (final (_, x) in exceptions) {
        if (x.toDomain() case final entry?) {
          (byEvent[x.eventId] ??= []).add(entry);
        }
      }
      return [
        for (final (id, e) in events)
          if (!e.isDeleted)
            if (e.toDomain(id) case final event?)
              event.withExceptions(byEvent[id] ?? const []),
      ];
    },
  );
}

/// Emits [combine] of both streams' latest values once each has emitted, and
/// again whenever either does.
Stream<R> _combineLatest<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? lastA;
  B? lastB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(lastA as A, lastB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onPause: () {
      subA?.pause();
      subB?.pause();
    },
    onResume: () {
      subA?.resume();
      subB?.resume();
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
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

/// Events in the family's recently deleted list, newest deletion first.
final deletedEventsProvider = StreamProvider<List<(String, EventPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchEvents().map(
    (events) => [
      for (final e in events)
        if (e.$2.isDeleted) e,
    ]..sort((a, b) => b.$2.deletedAt!.compareTo(a.$2.deletedAt!)),
  );
});
