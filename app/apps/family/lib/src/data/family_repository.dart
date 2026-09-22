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

  Stream<List<Place>> watchPlaces();
}

/// The family's real content, from the encrypted local store.
class SyncedFamilyRepository implements FamilyRepository {
  SyncedFamilyRepository(this._store);

  final FamilyStore _store;

  @override
  String get timeZone => familyTimeZone;

  @override
  /// The family as it is now: former members keep their profile, for
  /// history, but leave every list, picker and reminder.
  Stream<List<Member>> watchMembers() => _store.watchProfiles().map(
    (profiles) => [
      for (final (id, p) in profiles)
        if (p.endedAt == null) p.toDomain(id),
    ],
  );

  /// Events with their occurrence exceptions attached. The two are stored
  /// apart (spec §3 `event_exception`), so either changing re-emits.
  @override
  ///
  /// An event at a place shows the place's current name, so renaming the
  /// hall renames it everywhere; the name stored on the event is the
  /// fallback while the place can't be read.
  Stream<List<CalendarEvent>> watchEvents() => _combineLatest(
    _store.watchEvents(),
    _combineLatest(
      _combineLatest(
        _store.watchExceptions(),
        watchPlaces(),
        (exceptions, places) => (exceptions, places),
      ),
      _store.watchCalendarLinks(),
      (both, links) => (both.$1, both.$2, links),
    ),
    (events, extra) {
      final (exceptions, places, links) = extra;
      final byEvent = <String, List<ExceptionEntry>>{};
      for (final (_, x) in exceptions) {
        if (x.toDomain() case final entry?) {
          (byEvent[x.eventId] ??= []).add(entry);
        }
      }
      final placeNames = {for (final p in places) p.id: p.name};
      final linkNames = {for (final (id, l) in links) id: l.name};
      return [
        for (final (id, e) in events)
          if (!e.isDeleted)
            if (e.toDomain(id) case final event?)
              titledByFeed(
                _atPlace(
                  event.withExceptions(byEvent[id] ?? const []),
                  placeNames[event.placeId],
                ),
                linkNames[e.payload.nested('source')?.text('link')],
              ),
      ];
    },
  );

  @override
  Stream<List<Place>> watchPlaces() => _store.watchPlaces().map(
    (places) => [for (final (id, p) in places) p.toDomain(id)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  static CalendarEvent _atPlace(CalendarEvent event, String? placeName) =>
      placeName == null || placeName == event.location
      ? event
      : CalendarEvent(
          series: event.series,
          title: event.title,
          kind: event.kind,
          status: event.status,
          participantIds: event.participantIds,
          responsibleMemberId: event.responsibleMemberId,
          location: placeName,
          placeId: event.placeId,
          reminders: event.reminders,
        );
}

/// A subscribed calendar's events take the calendar's own name.
///
/// A club's feed titles every session "Träning". With three children on
/// three feeds the week reads "Träning, Träning, Träning" and says
/// nothing about whose or what — while the one label that does say,
/// the name the family gave the calendar when they linked it, was
/// shown nowhere at all.
///
/// Nothing is overwritten: the feed's own title is still in the stored
/// event, so this is a decision about display that can be taken back.
CalendarEvent titledByFeed(CalendarEvent event, String? linkName) =>
    linkName == null || linkName.isEmpty || linkName == event.title
    ? event
    : CalendarEvent(
        series: event.series,
        title: linkName,
        kind: event.kind,
        status: event.status,
        participantIds: event.participantIds,
        responsibleMemberId: event.responsibleMemberId,
        location: event.location,
        placeId: event.placeId,
        reminders: event.reminders,
      );

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

/// Members who've left and whose data hasn't been erased.
final formerMembersProvider = StreamProvider<List<Member>>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchProfiles().map(
    (profiles) => [
      for (final (id, p) in profiles)
        if (p.endedAt != null && !p.erased) p.toDomain(id),
    ],
  );
});

/// Away mode and school breaks (spec §3 `absence`).
final absencesProvider = StreamProvider<List<Absence>>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchAbsences().map(
    (rows) => [for (final (id, a) in rows) ?a.toDomain(id)],
  );
});

/// Custody arrangements this device can read (spec §3): the parents here
/// and the co-parent.
final custodyPayloadsProvider = StreamProvider<List<(String, CustodyPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchCustody();
});

final custodyProvider = Provider<List<CustodyArrangement>>(
  (ref) => [
    for (final (_, c)
        in ref.watch(custodyPayloadsProvider).value ??
            const <(String, CustodyPayload)>[])
      ?c.toDomain(),
  ],
);

final eventsProvider = StreamProvider<List<CalendarEvent>>((ref) async* {
  final repository = await ref.watch(familyRepositoryProvider.future);
  yield* repository.watchEvents();
});

/// The family's settings; the defaults until someone changes one.
final settingsProvider = StreamProvider<FamilySettings>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchSettings();
});

final placesProvider = StreamProvider<List<Place>>((ref) async* {
  final repository = await ref.watch(familyRepositoryProvider.future);
  yield* repository.watchPlaces();
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
