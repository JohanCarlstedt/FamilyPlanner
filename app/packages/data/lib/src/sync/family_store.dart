import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:family_crypto/family_crypto.dart';
import 'package:uuid/uuid.dart';

import '../api/family_api.dart';
import '../payload/absence_payload.dart';
import '../payload/action_payload.dart';
import '../payload/calendar_link_payload.dart';
import '../payload/credential_payload.dart';
import '../payload/custody_payload.dart';
import '../payload/equipment_payload.dart';
import '../payload/event_payload.dart';
import '../payload/helper_grant_payload.dart';
import '../payload/homework_payload.dart';
import '../payload/location_payload.dart';
import '../payload/meal_poll_payload.dart';
import '../payload/person_payload.dart';
import '../payload/payload.dart';
import '../payload/place_payload.dart';
import '../payload/settings_payload.dart';
import '../payload/request_payload.dart';
import '../payload/shopping_payload.dart';
import '../payload/wishlist_payload.dart';
import '../store/databases.dart';

/// Audience groups created with the family (crypto doc §3).
const allGroup = 'all';
const adultsGroup = 'adults';

/// The epoch every group starts at (crypto doc §3). New content is sealed to
/// the newest epoch this device holds for each group; see [FamilyStore].
const currentEpoch = 0;

/// Queued locally for a rewrap after key rotation, sent as an ordinary
/// upsert. Unlike an edit it never wins a conflict: a newer write is newer
/// content, and resending the older one would undo it.
const _rewrapType = 'object.rewrap';

/// Namespace for [FamilyStore.importedEventId]: UUIDv5 of
/// `https://github.com/JohanCarlstedt/FamilyPlanner/imported-event` in the
/// URL namespace. Fixed forever.
const _importNamespace = 'bd9e2b3a-4b5b-5360-96d1-93615d6b6ea6';

/// Object kinds, mirroring the backend's append-only ObjectKind.
enum ObjectKind {
  event(1, 'event'),
  place(2, 'place'),
  action(3, 'action'),
  person(4, 'person'),
  meal(5, 'meal_plan_entry'),
  recipe(6, 'recipe'),
  shoppingList(7, 'shopping_list'),
  shoppingListItem(8, 'shopping_list_item'),
  homework(9, 'homework'),
  wishlist(10, 'wishlist'),
  wishlistItem(11, 'wishlist_item'),
  equipmentSet(12, 'equipment_set'),
  settings(13, 'settings'),
  memberProfile(14, 'member_profile'),
  eventException(15, 'event_exception'),
  helperGrant(16, 'helper_grant'),
  calendarLink(17, 'calendar_link'),
  mealSuggestion(18, 'meal_suggestion'),
  mealPoll(19, 'meal_poll'),
  mealVote(20, 'meal_vote'),
  actionTemplate(21, 'action_template'),
  wishlistClaim(22, 'wishlist_claim'),
  subject(23, 'subject'),
  absence(24, 'absence'),
  approvalRequest(25, 'approval_request'),
  custody(26, 'custody_arrangement'),
  locationShare(27, 'location_share'),
  credential(28, 'credential'),

  /// Weekly homework: a template that plans one piece of homework a week.
  homeworkTemplate(29, 'homework_template');

  const ObjectKind(this.wire, this.slotType);

  /// The backend's enum value.
  final int wire;

  /// The object type bound into each envelope's slot (crypto doc §4).
  final String slotType;

  static ObjectKind? fromWire(int wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// This device holds no key for a group a password would be sealed to.
class MissingPasswordKey implements Exception {
  const MissingPasswordKey(this.group);

  final String group;

  @override
  String toString() => 'MissingPasswordKey($group)';
}

/// This device holds no key for a wishlist owner's observers group yet, so
/// it can't claim anything on their list until one is made and granted.
class MissingObserversKey implements Exception {
  const MissingObserversKey(this.ownerMemberId);

  final String ownerMemberId;

  @override
  String toString() => 'MissingObserversKey($ownerMemberId)';
}

/// What one [FamilyStore.sync] did.
class SyncReport {
  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.rebased,
    required this.rejected,
  });

  final int pushed;
  final int pulled;

  /// Edits that lost a race and were resent on top of the newer version.
  final int rebased;

  /// Commands the server refused; kept in the queue for a person to see.
  final int rejected;
}

/// Local-first access to the family's content (architecture doc §7): reads
/// come from the encrypted cache, writes go to the command queue and show at
/// once, and [sync] exchanges both with the server.
class FamilyStore {
  FamilyStore({
    required this._cache,
    required this._queue,
    required this._api,
    required this.familyId,
    required this.deviceId,
    required this._keyring,
    this.memberId,
  });

  final CacheDatabase _cache;
  final QueueDatabase _queue;
  final FamilyApi _api;
  final Keyring Function() _keyring;
  final String familyId;
  final String deviceId;

  /// Who is editing on this device. Stamped into every payload written, so
  /// the family's other devices can tell who changed what without the
  /// server knowing (spec §8: never notify the person who made the edit).
  final String? memberId;

  static const _uuid = Uuid();
  static const _cursorKey = 'cursor';

  String get _scope => 'family:$familyId';

  // ---- reads ----------------------------------------------------------------

  Stream<List<(String, EventPayload)>> watchEvents() => _watchReadable(
    ObjectKind.event,
  ).map((rows) => [for (final (id, p) in rows) (id, EventPayload.read(p))]);

  Stream<List<(String, EventExceptionPayload)>> watchExceptions() =>
      _watchReadable(ObjectKind.eventException).map(
        (rows) => [
          for (final (id, p) in rows) (id, EventExceptionPayload.read(p)),
        ],
      );

  Stream<List<(String, PlacePayload)>> watchPlaces() => _watchReadable(
    ObjectKind.place,
  ).map((rows) => [for (final (id, p) in rows) (id, PlacePayload.read(p))]);

  /// The family's settings; the defaults until someone changes one.
  Stream<FamilySettings> watchSettings() =>
      _watchReadable(ObjectKind.settings).map(
        (rows) =>
            [
              for (final (id, p) in rows)
                if (id == familyId) SettingsPayload.read(p).toDomain(),
            ].firstOrNull ??
            FamilySettings.defaults,
      );

  /// Saves the family's settings, keeping fields this client doesn't know.
  Future<void> saveSettings(FamilySettings settings) async {
    final existing = await payloadOf(familyId);
    await _put(
      ObjectKind.settings,
      familyId,
      SettingsPayload.write(existing: existing, settings: settings).payload,
      [allGroup],
    );
  }

  Stream<List<(String, MemberProfile)>> watchProfiles() => _watchReadable(
    ObjectKind.memberProfile,
  ).map((rows) => [for (final (id, p) in rows) (id, MemberProfile.read(p))]);

  Stream<List<(String, Payload)>> _watchReadable(ObjectKind kind) {
    final query = _cache.select(_cache.cachedObjects)
      ..where(
        (o) =>
            o.kind.equals(kind.wire) &
            o.deleted.equals(false) &
            o.payload.isNotNull(),
      );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          if (_tryDecode(row.payload!) case final payload?) (row.id, payload),
      ],
    );
  }

  /// Objects this device holds but can't open, by reason. A non-zero
  /// `noAccess` count on a parent's device means a grant is missing.
  Future<Map<String, int>> unreadableCounts() async {
    final rows = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.unreadable.isNotNull())).get();
    final counts = <String, int>{};
    for (final r in rows) {
      counts.update(r.unreadable!, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  // ---- writes ---------------------------------------------------------------

  /// Creates or edits an event; returns its id. Parents-only events are sealed
  /// to `adults` alone, so child devices never receive a readable copy.
  Future<String> saveEvent(EventPayload event, {String? id}) async =>
      _put(ObjectKind.event, id, event.payload, await _eventGroups(event));

  /// Cancels, moves or changes one occurrence; returns the exception's id.
  /// Sealed to the same audience as its event ([visibility]), so a
  /// parents-only event's exceptions stay parents-only too.
  Future<String> saveException(
    EventExceptionPayload exception, {
    required EventVisibility visibility,
  }) async => _put(
    ObjectKind.eventException,
    EventExceptionPayload.idFor(exception.eventId, exception.originalStart!),
    exception.payload,
    await _exceptionGroups(exception, fallback: visibility),
  );

  /// How long a deleted event can be restored (spec §11: a deleted season
  /// is the worst support case there is).
  static const restoreWindow = Duration(days: 30);

  /// Moves an event to the family's recently deleted list: hidden everywhere,
  /// restorable for [restoreWindow], exceptions kept for a restore.
  Future<void> softDeleteEvent(String id, {DateTime? now}) =>
      _markDeleted(id, now ?? DateTime.now().toUtc());

  Future<void> restoreEvent(String id) => _markDeleted(id, null);

  Future<void> _markDeleted(String id, DateTime? when) async {
    final payload = await payloadOf(id);
    if (payload == null) return;
    final event = EventPayload.read(payload)..setDeletedAt(when);
    await saveEvent(event, id: id);
  }

  /// Deletes for good every event deleted more than [restoreWindow] ago.
  /// Any device may do it; the second to try finds nothing left.
  Future<int> purgeDeleted({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(restoreWindow);
    var purged = 0;
    final now_ = now ?? DateTime.now().toUtc();
    for (final (id, e) in await watchEvents().first) {
      // A feed's event stays until the feed can no longer bring it back.
      if (e.payload.nested('source') != null && !_pastImport(e, now_)) {
        continue;
      }
      if (e.deletedAt case final at? when at.isBefore(cutoff)) {
        await deleteEvent(id);
        purged++;
      }
    }
    return purged;
  }

  /// Deletes an event and every exception to it this device can read, so
  /// none are left behind pointing at nothing.
  Future<void> deleteEvent(String id) async {
    final exceptions = await watchExceptions().first;
    for (final (exceptionId, e) in exceptions) {
      if (e.eventId == id) await delete(ObjectKind.eventException, exceptionId);
    }
    await delete(ObjectKind.event, id);
  }

  /// Creates or edits a place; returns its id. Places are the whole family's,
  /// so they're sealed to `all`: a child's device needs to know where
  /// training is too.
  Future<String> savePlace(PlacePayload place, {String? id}) async => _put(
    ObjectKind.place,
    id,
    place.payload,
    [allGroup, ...await _helperGroups()],
  );

  /// Saves a password for the family or for this member alone. Sealed to
  /// the group its scope names, so a device without that key holds
  /// something it cannot open however it asks.
  ///
  /// Throws [MissingPasswordKey] when this device hasn't got that key yet:
  /// the caller makes the group, grants it, and tries again.
  // Async so a missing key comes back as a failed future like every other
  // failure here, rather than escaping before the call returns.
  Future<String> saveCredential(
    CredentialPayload credential, {
    String? id,
  }) async {
    final group = passwordGroup(credential.scope);
    if (_keyring().latestEpoch(group: group) == null) {
      throw MissingPasswordKey(group);
    }
    return _put(ObjectKind.credential, id, credential.payload, [group]);
  }

  /// The saved passwords this device can open: the family's, and this
  /// member's own. What it can't open never arrives here.
  Stream<List<(String, CredentialPayload)>> watchCredentials() =>
      _watchReadable(ObjectKind.credential).map(
        (rows) => [for (final (id, p) in rows) (id, CredentialPayload.read(p))]
          ..sort(
            (a, b) =>
                a.$2.title.toLowerCase().compareTo(b.$2.title.toLowerCase()),
          ),
      );

  /// Sets where a place is, or clears it (spec §7 geofence).
  Future<void> setPlaceLocation(
    String id,
    GeoPoint? at, {
    double radiusMeters = 100,
  }) async {
    final existing = await payloadOf(id);
    if (existing == null) return;
    await savePlace(
      PlacePayload.read(existing).withLocation(at, radiusMeters: radiusMeters),
      id: id,
    );
  }

  static String locationShareId(String memberId) =>
      const Uuid().v5(_importNamespace, 'location-share/$memberId');

  /// A member's sharing choice, or a parent's floor on it; sealed to the
  /// whole family, so everyone on the map sees who sees them.
  Future<void> saveLocationShare(LocationShare share) async {
    final id = locationShareId(share.memberId);
    await _put(
      ObjectKind.locationShare,
      id,
      LocationSharePayload.write(
        existing: await payloadOf(id),
        share: share,
      ).payload,
      [allGroup],
    );
  }

  /// Everyone's sharing choices, by member.
  Stream<Map<String, LocationShare>> watchLocationShares() =>
      _watchReadable(ObjectKind.locationShare).map(
        (rows) => {
          for (final share in [
            for (final (_, p) in rows) ?LocationSharePayload.read(p).toDomain(),
          ])
            share.memberId: share,
        },
      );

  /// Writes a member's profile, keyed by their member id. Helpers read the
  /// names too: a calendar of strangers is no calendar.
  Future<void> saveProfile(String memberId, MemberProfile profile) async =>
      _put(ObjectKind.memberProfile, memberId, profile.payload, [
        allGroup,
        ...await _helperGroups(),
      ]);

  /// Erases a member who has left (spec §9 per-member deletion, anonymised):
  /// their profile keeps only its id, events only about them are deleted,
  /// shared ones lose them as participant or driver, and feeds linked to
  /// them go. What they wrote stays, as a former member's.
  Future<void> eraseMember(String memberId, {DateTime? now}) async {
    if (await payloadOf(memberId) case final existing?) {
      final profile = MemberProfile.read(existing);
      final erased = MemberProfile.write(
        existing: existing,
        displayName: '',
        role: profile.role,
        endedAt: profile.endedAt ?? now ?? DateTime.now().toUtc(),
      );
      erased.payload.setBoolean('erased', true);
      await saveProfile(memberId, erased);
    }
    if (await payloadOf(locationShareId(memberId)) != null) {
      await delete(ObjectKind.locationShare, locationShareId(memberId));
    }
    for (final (id, e) in await watchEvents().first) {
      final going = e.participantIds;
      if (going.isNotEmpty && going.every((m) => m == memberId)) {
        await deleteEvent(id);
        continue;
      }
      if (!going.contains(memberId) && e.responsibleMemberId != memberId) {
        continue;
      }
      final copy = Payload.decode(e.payload.encode())
        ..setTexts('participants', [
          for (final m in going)
            if (m != memberId) m,
        ]);
      if (e.responsibleMemberId == memberId) copy.setText('responsible', null);
      await saveEvent(EventPayload.read(copy), id: id);
    }
    for (final (_, x) in await watchExceptions().first) {
      if (x.overrideResponsibleMemberId != memberId) continue;
      final copy = Payload.decode(x.payload.encode())
        ..setText('responsible', null);
      final event = await payloadOf(x.eventId);
      await saveException(
        EventExceptionPayload.read(copy),
        visibility: event == null
            ? EventVisibility.family
            : EventPayload.read(event).visibility,
      );
    }
    for (final (id, link) in await watchCalendarLinks().first) {
      if (link.memberId == memberId) await delete(ObjectKind.calendarLink, id);
    }
  }

  // ---- shopping (spec §4) -------------------------------------------------------
  // The whole family's, children included: everyone adds to the list.

  Future<String> saveShoppingList(ShoppingListPayload list, {String? id}) =>
      _put(ObjectKind.shoppingList, id, list.payload, [allGroup]);

  Stream<List<(String, ShoppingListPayload)>> watchShoppingLists() =>
      _watchReadable(ObjectKind.shoppingList).map(
        (rows) => [
          for (final (id, p) in rows) (id, ShoppingListPayload.read(p)),
        ],
      );

  Future<String> saveShoppingItem(ShoppingItemPayload item, {String? id}) =>
      _put(ObjectKind.shoppingListItem, id, item.payload, [allGroup]);

  Stream<List<(String, ShoppingItemPayload)>> watchShoppingItems() =>
      _watchReadable(ObjectKind.shoppingListItem).map(
        (rows) => [
          for (final (id, p) in rows) (id, ShoppingItemPayload.read(p)),
        ],
      );

  Future<String> saveRecipe(RecipePayload recipe, {String? id}) =>
      _put(ObjectKind.recipe, id, recipe.payload, [allGroup]);

  Stream<List<(String, RecipePayload)>> watchRecipes() => _watchReadable(
    ObjectKind.recipe,
  ).map((rows) => [for (final (id, p) in rows) (id, RecipePayload.read(p))]);

  /// Puts [lines] on list [listId], each from [source] (spec §4
  /// "Generation"): into an item still needed of the same ingredient when
  /// the amounts add up, as a new line otherwise. Bought items are never
  /// brought back; free text always gets its own line.
  Future<void> addToList(
    String listId,
    List<ShoppingLine> lines, {
    required ItemSource Function(ShoppingLine) source,
  }) async {
    final items = [
      for (final (id, i) in await watchShoppingItems().first)
        if (i.listId == listId && i.state == ItemState.needed) (id, i),
    ];
    for (final line in lines) {
      final from = source(line);
      final match = line.key == null
          ? null
          : items.where((e) {
              final (_, i) = e;
              if (i.key != line.key) return false;
              if (i.quantity == null || line.quantity == null) {
                return i.quantity == null && line.quantity == null;
              }
              return i.unit?.mergeKey == line.unit?.mergeKey;
            }).firstOrNull;
      if (match case (final id, final item)) {
        final sum = item.quantity == null
            ? null
            : sumAmounts([
                (item.quantity!, item.unit!),
                (line.quantity!, line.unit!),
              ]);
        final updated = item.copyWith(
          quantity: sum?.$1,
          unit: sum?.$2,
          sources: [...item.sources, from],
        );
        await saveShoppingItem(updated, id: id);
        items[items.indexWhere((e) => e.$1 == id)] = (id, updated);
      } else {
        final item = ShoppingItemPayload.write(
          listId: listId,
          name: line.name,
          key: line.key,
          quantity: line.quantity,
          unit: line.unit,
          category: line.category,
          sources: [from],
        );
        final id = await saveShoppingItem(item);
        if (line.key != null) items.add((id, item));
      }
    }
  }

  /// Empties list [listId]: everything bought, or everything on it.
  ///
  /// The everyday one is [boughtOnly], after a shop — the ticked items go
  /// and what nobody found stays on the list, which is what you want on
  /// the way home. Clearing the lot is for starting a week again.
  ///
  /// Items are deleted rather than unticked, so the menu and staples that
  /// put them there can put them back cleanly; a deleted object is
  /// recoverable for the restore window like any other.
  Future<int> clearShoppingList(String listId, {bool boughtOnly = true}) async {
    var cleared = 0;
    for (final (id, item) in await watchShoppingItems().first) {
      if (item.listId != listId) continue;
      if (boughtOnly && item.state != ItemState.bought) continue;
      await delete(ObjectKind.shoppingListItem, id);
      cleared++;
    }
    return cleared;
  }

  /// Takes what [sourceId] put on list [listId] back off: each item loses
  /// that share, and goes once nothing else wants it. Bought items stay.
  Future<void> removeFromList(String listId, String sourceId) async {
    for (final (id, item) in await watchShoppingItems().first) {
      if (item.listId != listId || item.state == ItemState.bought) continue;
      final gone = item.sources.where((s) => s.id == sourceId).toList();
      if (gone.isEmpty) continue;
      final left = item.sources.where((s) => s.id != sourceId).toList();
      if (left.isEmpty) {
        await delete(ObjectKind.shoppingListItem, id);
        continue;
      }
      final amounts = [
        for (final s in left)
          if (s.quantity != null && s.unit != null) (s.quantity!, s.unit!),
      ];
      final sum = amounts.length == left.length ? sumAmounts(amounts) : null;
      await saveShoppingItem(
        item.copyWith(
          quantity: sum?.$1,
          unit: sum?.$2,
          clearQuantity: sum == null,
          sources: left,
        ),
        id: id,
      );
    }
  }

  Future<String> saveMeal(MealPayload meal, {String? id}) =>
      _put(ObjectKind.meal, id, meal.payload, [allGroup]);

  Stream<List<(String, MealPayload)>> watchMeals() => _watchReadable(
    ObjectKind.meal,
  ).map((rows) => [for (final (id, p) in rows) (id, MealPayload.read(p))]);

  /// The source id a meal's recipe contributes under, so taking the salad
  /// off Thursday takes only the salad's share.
  static String mealSource(String mealId, String recipeId) =>
      'meal:$mealId:$recipeId';

  /// Brings list [listId] in step with the menu from [from] to [until]
  /// (dates): each meal's recipes go on at the meal's portions, and what a
  /// meal no longer has comes off. Running it again changes only what
  /// changed; bought items are left alone.
  Future<void> menuToList(
    String listId, {
    required DateTime from,
    required DateTime until,
    required int defaultServings,
  }) async {
    final recipes = {for (final (id, r) in await watchRecipes().first) id: r};
    final wanted = <String, (String, RecipePayload, int?)>{};
    for (final (mealId, meal) in await watchMeals().first) {
      final date = meal.date;
      if (date == null || date.isBefore(from) || !date.isBefore(until)) {
        continue;
      }
      for (final r in meal.recipes) {
        final recipe = recipes[r.recipeId];
        if (recipe == null) continue;
        wanted[mealSource(mealId, r.recipeId)] = (
          r.recipeId,
          recipe,
          r.servings ?? meal.servings ?? defaultServings,
        );
      }
    }
    final present = <String>{
      for (final (_, item) in await watchShoppingItems().first)
        if (item.listId == listId)
          for (final s in item.sources)
            if (s.id case final id? when id.startsWith('meal:')) id,
    };
    for (final gone in present.difference(wanted.keys.toSet())) {
      await removeFromList(listId, gone);
    }
    for (final MapEntry(key: source, value: (id, recipe, servings))
        in wanted.entries) {
      if (present.contains(source)) continue;
      await addRecipeToList(
        listId,
        id,
        recipe,
        servings: servings,
        sourceId: source,
      );
    }
  }

  // ---- people and celebrations (spec §3) --------------------------------------

  Stream<List<(String, PersonPayload)>> watchPeople() => _watchReadable(
    ObjectKind.person,
  ).map((rows) => [for (final (id, p) in rows) (id, PersonPayload.read(p))]);

  /// The celebration event that belongs to person [personId].
  static String celebrationId(String personId) =>
      const Uuid().v5(_importNamespace, 'celebration/$personId');

  /// Saves someone, and keeps their celebration in step: a yearly event
  /// while they have a day, none once they don't. The event is theirs,
  /// titled with their name; the app shows what they turn.
  Future<String> savePerson(
    PersonPayload person, {
    String? id,
    required String timeZone,
  }) async {
    final personId = await _put(ObjectKind.person, id, person.payload, [
      allGroup,
    ]);
    final eventId = celebrationId(personId);
    final date = person.date;
    if (date == null) {
      if (await payloadOf(eventId) != null) await deleteEvent(eventId);
      return personId;
    }
    final c = Celebrations.event(
      eventId: eventId,
      title: person.name,
      date: date,
      timeZone: timeZone,
      leadDays: person.leadDays,
      participantIds: [?person.memberId],
    );
    final event = EventPayload.write(
      existing: await payloadOf(eventId),
      title: c.title,
      kind: c.kind,
      localStart: c.series.localStart,
      duration: c.series.duration,
      timeZone: timeZone,
      rule: c.series.rule,
      participantIds: c.participantIds,
      reminders: c.reminders,
    );
    event.payload.setText('person', personId);
    await saveEvent(event, id: eventId);
    return personId;
  }

  /// Removes someone and their celebration.
  Future<void> deletePerson(String id) async {
    final eventId = celebrationId(id);
    if (await payloadOf(eventId) != null) await deleteEvent(eventId);
    await delete(ObjectKind.person, id);
  }

  // ---- "Can I…?" (spec §3 `approval_request`) ------------------------------------

  /// A question from this device's member to the parents.
  Future<String> ask(String message, {DateTime? now}) => _put(
    ObjectKind.approvalRequest,
    null,
    RequestPayload.write(
      requestedBy: memberId ?? '',
      message: message,
      at: now ?? DateTime.now(),
    ).payload,
    [allGroup],
  );

  Stream<List<(String, RequestPayload)>> watchRequests() => _watchReadable(
    ObjectKind.approvalRequest,
  ).map((rows) => [for (final (id, p) in rows) (id, RequestPayload.read(p))]);

  /// The asker clears an answered question away.
  Future<void> acknowledgeRequest(String id) async {
    final payload = await payloadOf(id);
    if (payload == null) return;
    await _put(
      ObjectKind.approvalRequest,
      id,
      RequestPayload.read(payload).acknowledge().payload,
      [allGroup],
    );
  }

  /// A parent's answer.
  Future<void> answer(
    String id, {
    required bool approved,
    String? note,
    DateTime? now,
  }) async {
    final request = RequestPayload.read((await payloadOf(id))!);
    await _put(
      ObjectKind.approvalRequest,
      id,
      request
          .decided(
            approved: approved,
            by: memberId ?? '',
            at: now ?? DateTime.now(),
            answer: note,
          )
          .payload,
      [allGroup],
    );
  }

  // ---- photos (spec §3 "Attachments") ---------------------------------------------

  /// Seals a photo (already downscaled and stripped of its metadata on this
  /// phone) to [groups], the audience of what it belongs to, and queues it
  /// for upload. Shown from this phone's cache at once. Returns its id.
  Future<String> addPhoto(
    Uint8List jpeg, {
    required List<String> groups,
  }) async {
    final id = _uuid.v4();
    final envelope = seal(
      payload: jpeg,
      object: ObjectSlot(objectType: 'blob', id: id, familyId: familyId),
      audiences: _latest(groups),
      keyring: _keyring(),
    );
    await _queue
        .into(_queue.pendingBlobs)
        .insert(
          PendingBlobsCompanion.insert(
            id: id,
            envelope: envelope,
            createdAt: DateTime.now().toUtc(),
          ),
        );
    await _cache
        .into(_cache.cachedBlobs)
        .insertOnConflictUpdate(
          CachedBlobsCompanion.insert(id: id, bytes: jpeg),
        );
    unawaited(uploadPhotos().catchError((_) => 0));
    return id;
  }

  Future<int>? _uploading;
  var _uploadAgain = false;

  /// Uploads photos waiting in the queue; returns how many went. One run at
  /// a time: a caller during a run joins it, and the run goes round again
  /// for anything added meanwhile.
  Future<int> uploadPhotos() {
    if (_uploading case final running?) {
      _uploadAgain = true;
      return running;
    }
    return _uploading = () async {
      var sent = 0;
      try {
        do {
          _uploadAgain = false;
          sent += await _uploadPhotos();
        } while (_uploadAgain);
      } finally {
        _uploading = null;
      }
      return sent;
    }();
  }

  Future<int> _uploadPhotos() async {
    var sent = 0;
    for (final p in await _queue.select(_queue.pendingBlobs).get()) {
      await _api.putBlob(asDevice: deviceId, id: p.id, envelope: p.envelope);
      await (_queue.delete(
        _queue.pendingBlobs,
      )..where((b) => b.id.equals(p.id))).go();
      sent++;
    }
    return sent;
  }

  /// A photo's bytes: from the cache, or fetched and opened. Null if it
  /// isn't there or this device may not see it.
  Future<Uint8List?> photo(String id) async {
    final cached = await (_cache.select(
      _cache.cachedBlobs,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (cached != null) return cached.bytes;
    final envelope = await _api.getBlob(asDevice: deviceId, id: id);
    if (envelope == null) return null;
    try {
      final opened = open(envelope: envelope, keyring: _keyring());
      final slot = opened.header.object;
      if (slot.id != id ||
          slot.familyId != familyId ||
          slot.objectType != 'blob') {
        return null;
      }
      await _cache
          .into(_cache.cachedBlobs)
          .insertOnConflictUpdate(
            CachedBlobsCompanion.insert(id: id, bytes: opened.payload),
          );
      return opened.payload;
    } on CryptoException {
      return null;
    }
  }

  /// The audience a photo on [kind] object [ownerId] should be sealed to:
  /// that object's own, so a photo on a parents-only event is parents-only.
  Future<List<String>> groupsForPhotoOn(
    ObjectKind kind,
    String? ownerId,
  ) async {
    if (ownerId != null) {
      if (await payloadOf(ownerId) case final p?) {
        return await _groupsFor(kind, p) ?? [allGroup];
      }
    }
    return [allGroup];
  }

  // ---- custody (spec §3) ---------------------------------------------------------

  /// The parents here, and the co-parent through their own group.
  Future<List<String>> _custodyGroups(CustodyPayload c) async => [
    adultsGroup,
    if (c.coParentId case final co?)
      if (_keyring().latestEpoch(group: helperGroup(co)) != null)
        helperGroup(co),
  ];

  Stream<List<(String, CustodyPayload)>> watchCustody() => _watchReadable(
    ObjectKind.custody,
  ).map((rows) => [for (final (id, p) in rows) (id, CustodyPayload.read(p))]);

  /// Saves an arrangement and keeps its changeover events in step (spec §3:
  /// "changeover is itself an event"), titled [toUs] and [toThem].
  Future<String> saveCustody(
    CustodyPayload custody, {
    String? id,
    required String timeZone,
    required String toUs,
    required String toThem,
  }) async {
    final custodyId = await _put(
      ObjectKind.custody,
      id,
      custody.payload,
      await _custodyGroups(custody),
    );
    final arrangement = custody.toDomain();
    if (arrangement == null) return custodyId;
    for (final c in arrangement.changeoverEvents(
      timeZone: timeZone,
      toUs: toUs,
      toThem: toThem,
      idFor: (direction) =>
          const Uuid().v5(_importNamespace, 'changeover/$custodyId/$direction'),
    )) {
      final existing = await payloadOf(c.id);
      final before = existing == null ? null : EventPayload.read(existing);
      await saveEvent(
        EventPayload.write(
          existing: existing,
          title: c.title,
          kind: c.kind,
          localStart: c.series.localStart,
          duration: c.series.duration,
          timeZone: timeZone,
          rule: c.series.rule,
          participantIds: c.participantIds,
          // Who drives is the family's to decide, and stays decided.
          responsibleMemberId: before?.responsibleMemberId,
          location: before?.location,
          placeId: before?.placeId,
        ),
        id: c.id,
      );
    }
    return custodyId;
  }

  /// Ends an arrangement and its changeovers.
  Future<void> deleteCustody(String id) async {
    for (final direction in ['in', 'out']) {
      final eventId = const Uuid().v5(
        _importNamespace,
        'changeover/$id/$direction',
      );
      if (await payloadOf(eventId) != null) await deleteEvent(eventId);
    }
    await delete(ObjectKind.custody, id);
  }

  // ---- kit lists (spec §3 equipment) ---------------------------------------------

  Future<String> saveEquipmentSet(EquipmentSetPayload set, {String? id}) =>
      _put(ObjectKind.equipmentSet, id, set.payload, [allGroup]);

  Stream<List<(String, EquipmentSetPayload)>> watchEquipmentSets() =>
      _watchReadable(ObjectKind.equipmentSet).map(
        (rows) => [
          for (final (id, p) in rows) (id, EquipmentSetPayload.read(p)),
        ],
      );

  /// Sets which kit lists event [eventId] carries.
  Future<void> setEventEquipment(String eventId, List<String> setIds) async {
    final payload = await payloadOf(eventId);
    if (payload == null) return;
    final copy = Payload.decode(payload.encode())
      ..setTexts('equipment', setIds);
    await saveEvent(EventPayload.read(copy), id: eventId);
  }

  // ---- away mode (spec §3 `absence`) ---------------------------------------------

  Future<String> saveAbsence(AbsencePayload absence, {String? id}) =>
      _put(ObjectKind.absence, id, absence.payload, [allGroup]);

  Stream<List<(String, AbsencePayload)>> watchAbsences() => _watchReadable(
    ObjectKind.absence,
  ).map((rows) => [for (final (id, p) in rows) (id, AbsencePayload.read(p))]);

  // ---- homework (spec §3) ------------------------------------------------------

  Future<String> saveSubject(SubjectPayload subject, {String? id}) =>
      _put(ObjectKind.subject, id, subject.payload, [allGroup]);

  Stream<List<(String, SubjectPayload)>> watchSubjects() => _watchReadable(
    ObjectKind.subject,
  ).map((rows) => [for (final (id, p) in rows) (id, SubjectPayload.read(p))]);

  Future<String> saveHomework(HomeworkPayload homework, {String? id}) =>
      _put(ObjectKind.homework, id, homework.payload, [allGroup]);

  Stream<List<(String, HomeworkPayload)>> watchHomework() => _watchReadable(
    ObjectKind.homework,
  ).map((rows) => [for (final (id, p) in rows) (id, HomeworkPayload.read(p))]);

  Future<String> saveHomeworkTemplate(
    HomeworkTemplatePayload template, {
    String? id,
  }) => _put(ObjectKind.homeworkTemplate, id, template.payload, [allGroup]);

  Stream<List<(String, HomeworkTemplatePayload)>> watchHomeworkTemplates() =>
      _watchReadable(ObjectKind.homeworkTemplate).map(
        (rows) => [
          for (final (id, p) in rows) (id, HomeworkTemplatePayload.read(p)),
        ],
      );

  /// The id of the homework a template plans for one week.
  static String plannedHomeworkId(PlannedHomework planned) =>
      const Uuid().v5(_importNamespace, 'homework/${planned.key}');

  /// Writes the homework that weekly arrangements call for over the next
  /// [window]. Any device may run it: the ids are derived from the week, so
  /// two phones planning the same Friday write the same object rather than
  /// two.
  ///
  /// It only ever creates. A week already planned is left exactly as it is,
  /// because by then it may be half done, rewritten by a parent, or have
  /// sessions booked against it — none of which a planner should touch.
  Future<int> planHomeworkAhead({
    DateTime? now,
    Duration window = const Duration(days: 28),
  }) async {
    final at = now ?? DateTime.now().toUtc();
    final existing = {for (final (id, _) in await watchHomework().first) id};
    var written = 0;
    for (final (id, t) in await watchHomeworkTemplates().first) {
      if (t.paused) continue;
      final template = t.toDomain(id);
      if (template == null) continue;
      for (final planned in planHomework(
        template: template,
        from: at,
        until: at.add(window),
      )) {
        final homeworkId = plannedHomeworkId(planned);
        if (existing.contains(homeworkId)) continue;
        await saveHomework(
          HomeworkPayload.write(
            memberId: template.memberId,
            title: template.title,
            subjectId: template.subjectId,
            description: template.description,
            type: template.type,
            dueAt: planned.dueAt,
            estimatedMinutes: template.estimatedMinutes,
          ),
          id: homeworkId,
        );
        written++;
      }
    }
    return written;
  }

  /// A session for homework [homeworkId] at [start]: a `homework` event for
  /// its child, so it shows in the calendar, clashes are seen and reminders
  /// come the usual way (spec §3: no parallel scheduling system).
  Future<void> planHomeworkSession(
    String homeworkId, {
    required DateTime localStart,
    required int minutes,
    required String timeZone,
  }) async {
    final homework = HomeworkPayload.read((await payloadOf(homeworkId))!);
    final eventId = await saveEvent(
      EventPayload.write(
        title: homework.title,
        kind: EventKind.homework,
        localStart: localStart,
        duration: Duration(minutes: minutes),
        timeZone: timeZone,
        participantIds: [homework.memberId],
      ),
    );
    await saveHomework(
      homework.withSessions([
        ...homework.sessions,
        HomeworkSession(eventId: eventId, minutes: minutes),
      ]),
      id: homeworkId,
    );
  }

  /// Done or handed in: its sessions still to come go from the calendar.
  Future<void> setHomeworkState(
    String id,
    HomeworkState state, {
    DateTime? now,
  }) async {
    final homework = HomeworkPayload.read((await payloadOf(id))!);
    final at = now ?? DateTime.now().toUtc();
    if (state == HomeworkState.done || state == HomeworkState.handedIn) {
      for (final s in homework.sessions) {
        final e = await payloadOf(s.eventId);
        if (e == null) continue;
        final start = EventPayload.read(e).toDomain(s.eventId);
        final begins = start == null
            ? null
            : const RecurrenceExpander()
                  .expand(start.series, DateTime.utc(1970), DateTime.utc(3000))
                  .firstOrNull
                  ?.start;
        if (begins != null && begins.isAfter(at)) await deleteEvent(s.eventId);
      }
    }
    await saveHomework(homework.withState(state), id: id);
  }

  // ---- wishlists (spec §3) -----------------------------------------------------

  Future<String> saveWishlist(WishlistPayload list, {String? id}) =>
      _put(ObjectKind.wishlist, id, list.payload, [allGroup]);

  Stream<List<(String, WishlistPayload)>> watchWishlists() => _watchReadable(
    ObjectKind.wishlist,
  ).map((rows) => [for (final (id, p) in rows) (id, WishlistPayload.read(p))]);

  Future<String> saveWishlistItem(WishlistItemPayload item, {String? id}) =>
      _put(ObjectKind.wishlistItem, id, item.payload, [allGroup]);

  Stream<List<(String, WishlistItemPayload)>> watchWishlistItems() =>
      _watchReadable(ObjectKind.wishlistItem).map(
        (rows) => [
          for (final (id, p) in rows) (id, WishlistItemPayload.read(p)),
        ],
      );

  static String _claimId(String itemId, String memberId) =>
      const Uuid().v5(_importNamespace, 'claim/$itemId/$memberId');

  /// This device's member will buy [itemId], which is on
  /// [ownerMemberId]'s list. Sealed to everyone but them, so their own
  /// device can't read it however it asks; a list for someone who isn't a
  /// member (a grandparent) has nobody to hide from and reaches everyone.
  ///
  /// Throws [MissingObserversKey] when this device hasn't got that group's
  /// key yet: the caller makes the group, grants it, and tries again.
  Future<void> claimWish(String itemId, {String? ownerMemberId}) async {
    if (ownerMemberId != null &&
        _keyring().latestEpoch(group: wishlistObserversGroup(ownerMemberId)) ==
            null) {
      throw MissingObserversKey(ownerMemberId);
    }
    await _put(
      ObjectKind.wishlistClaim,
      _claimId(itemId, memberId ?? ''),
      WishlistClaimPayload.write(
        itemId: itemId,
        claimedBy: memberId ?? '',
        ownerMemberId: ownerMemberId,
        at: DateTime.now(),
      ).payload,
      _claimGroups(ownerMemberId),
    );
  }

  static List<String> _claimGroups(String? ownerMemberId) =>
      ownerMemberId == null || ownerMemberId.isEmpty
      ? [allGroup]
      : [wishlistObserversGroup(ownerMemberId)];

  Future<void> unclaimWish(String itemId) =>
      delete(ObjectKind.wishlistClaim, _claimId(itemId, memberId ?? ''));

  /// Claims as [viewer] may see them (spec §3: "claims are visible to
  /// everyone except the list's owner", a rule of this query, not of the
  /// screen): none on the viewer's own lists.
  Stream<List<(String, WishlistClaimPayload)>> watchClaimsFor(String viewer) =>
      _watchReadable(ObjectKind.wishlistClaim).asyncMap((rows) async {
        final people = {
          for (final (id, p) in await watchPeople().first) id: p.memberId,
        };
        final owners = {
          for (final (id, l) in await watchWishlists().first)
            id: people[l.personId],
        };
        final itemOwner = {
          for (final (id, i) in await watchWishlistItems().first)
            id: owners[i.wishlistId],
        };
        return [
          for (final (id, p) in rows)
            if (WishlistClaimPayload.read(p) case final c
                when itemOwner[c.itemId] != viewer)
              (id, c),
        ];
      });

  /// Next year's list from [fromId]: the items not received, copied, and
  /// the new list saying where they came from (spec §3: carried forward on
  /// purpose, never silently).
  Future<String> carryForward(String fromId, {required String name}) async {
    final from = WishlistPayload.read((await payloadOf(fromId))!);
    final toId = await saveWishlist(
      WishlistPayload.write(
        personId: from.personId,
        name: name,
        occasion: from.occasion,
        carriedFrom: fromId,
      ),
    );
    await saveWishlist(
      WishlistPayload.write(
        existing: from.payload,
        personId: from.personId,
        name: from.name,
        occasion: from.occasion,
        carriedFrom: from.carriedFrom,
        active: false,
      ),
      id: fromId,
    );
    for (final (_, item) in await watchWishlistItems().first) {
      if (item.wishlistId != fromId || item.received) continue;
      await saveWishlistItem(
        WishlistItemPayload.write(
          wishlistId: toId,
          title: item.title,
          url: item.url,
          note: item.note,
          size: item.size,
        ),
      );
    }
    return toId;
  }

  // ---- actions (spec §3) -------------------------------------------------------

  Future<String> saveAction(ActionPayload action, {String? id}) =>
      _put(ObjectKind.action, id, action.payload, [allGroup]);

  Stream<List<(String, ActionPayload)>> watchActions() => _watchReadable(
    ObjectKind.action,
  ).map((rows) => [for (final (id, p) in rows) (id, ActionPayload.read(p))]);

  Future<String> saveActionTemplate(
    ActionTemplatePayload template, {
    String? id,
  }) => _put(ObjectKind.actionTemplate, id, template.payload, [allGroup]);

  Stream<List<(String, ActionTemplatePayload)>> watchActionTemplates() =>
      _watchReadable(ObjectKind.actionTemplate).map(
        (rows) => [
          for (final (id, p) in rows) (id, ActionTemplatePayload.read(p)),
        ],
      );

  /// The id of the action a template plans for one occurrence.
  static String plannedActionId(PlannedAction planned) =>
      const Uuid().v5(_importNamespace, 'action/${planned.key}');

  /// Creates the actions templates call for over the next [window] (spec §3:
  /// a rolling window, never the whole season), moves open ones whose
  /// occurrence moved, and cancels open ones whose occurrence was. Any
  /// device may run it: ids are the same everywhere. Returns how many
  /// actions it wrote.
  Future<int> planActionsAhead(
    List<CalendarEvent> events, {
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) async {
    final at = now ?? DateTime.now().toUtc();
    final byEvent = {for (final e in events) e.id: e};
    final existing = {for (final (id, a) in await watchActions().first) id: a};
    var written = 0;
    for (final (id, t) in await watchActionTemplates().first) {
      if (t.paused) continue;
      final template = t.toDomain(id);
      for (final planned in planActions(
        template: template,
        event: template.eventId == null ? null : byEvent[template.eventId],
        from: at,
        until: at.add(window),
      )) {
        final actionId = plannedActionId(planned);
        final action = existing[actionId];
        if (action == null) {
          if (planned.cancelled) continue;
          await saveAction(
            ActionPayload.write(
              title: t.title,
              kind: t.kind,
              eventId: t.eventId,
              occurrenceStart: planned.occurrenceStart,
              templateId: id,
              assignedTo: planned.assignee,
              dueAt: planned.dueAt,
              blocking: t.blocking,
              requiresApproval: t.requiresApproval,
            ),
            id: actionId,
          );
          written++;
        } else if (action.isOpen && planned.cancelled) {
          await saveAction(
            action.next(
              ActionStep(what: 'cancelled', by: memberId ?? '', at: at),
              state: ActionState.cancelled,
            ),
            id: actionId,
          );
          written++;
        } else if (action.isOpen && action.dueAt != planned.dueAt) {
          await saveAction(
            action.next(
              ActionStep(what: 'moved', by: memberId ?? '', at: at),
              dueAt: planned.dueAt,
            ),
            id: actionId,
          );
          written++;
        }
      }
    }
    return written;
  }

  Future<ActionPayload?> _action(String id) async =>
      switch (await payloadOf(id)) {
        final p? => ActionPayload.read(p),
        null => null,
      };

  Future<void> _step(
    String id,
    ActionPayload Function(
      ActionPayload a,
      ActionStep Function(String, {String? to, String? note}) step,
    )
    change,
  ) async {
    final a = await _action(id);
    if (a == null) return;
    final now = DateTime.now().toUtc();
    ActionStep step(String what, {String? to, String? note}) =>
        ActionStep(what: what, by: memberId ?? '', at: now, to: to, note: note);
    await saveAction(change(a, step), id: id);
  }

  /// Takes it from the family pool (spec §3: "claiming is a single tap").
  Future<void> claimAction(String id) => _step(
    id,
    (a, step) => a.next(step('claimed', to: memberId), assignedTo: memberId),
  );

  /// Back to the family pool.
  Future<void> unclaimAction(String id) =>
      _step(id, (a, step) => a.next(step('unclaimed'), unassign: true));

  /// A parent's decision: it's [to]'s now, no asking (spec §3).
  Future<void> assignAction(String id, String? to) => _step(
    id,
    (a, step) => to == null
        ? a.next(step('unclaimed'), unassign: true)
        : a.next(step('assigned', to: to), assignedTo: to),
  );

  /// Done by this device's member; with approval required, it waits for
  /// a parent.
  Future<void> completeAction(String id) => _step(
    id,
    (a, step) => a.next(
      step('done'),
      state: ActionState.done,
      completedBy: memberId,
      completedAt: DateTime.now(),
      clearDelegation: true,
    ),
  );

  Future<void> approveAction(String id) => _step(
    id,
    (a, step) => a.next(step('approved'), state: ActionState.approved),
  );

  /// Not done after all: open again.
  Future<void> reopenAction(String id) => _step(
    id,
    (a, step) => a.next(
      step('reopened'),
      state: ActionState.open,
      clearCompletion: true,
    ),
  );

  Future<void> skipAction(String id) => _step(
    id,
    (a, step) => a.next(step('skipped'), state: ActionState.skipped),
  );

  /// Asks [to] to take it over (spec §3 "Delegation"): it stays with the
  /// asker until they accept. Anyone may ask anyone, upwards included.
  Future<void> delegateAction(String id, String to, {String? note}) => _step(
    id,
    (a, step) => a.next(
      step('delegated', to: to, note: note),
      delegation: Delegation(
        from: a.assignedTo ?? memberId ?? '',
        to: to,
        note: note,
      ),
    ),
  );

  /// The answer to a delegation: accepted, it's theirs; declined, it goes
  /// back to whoever asked, never to the pool, so it can't become nobody's.
  Future<void> answerDelegation(
    String id, {
    required bool accept,
    String? note,
  }) => _step(id, (a, step) {
    final d = a.delegation;
    if (d == null) return a;
    return accept
        ? a.next(
            step('accepted', note: note),
            assignedTo: d.to,
            clearDelegation: true,
          )
        : a.next(
            step('declined', to: d.from, note: note),
            assignedTo: d.from,
            clearDelegation: true,
          );
  });

  // ---- meal suggestions and polls (spec §4) -----------------------------------

  Future<String> saveSuggestion(MealSuggestionPayload s, {String? id}) =>
      _put(ObjectKind.mealSuggestion, id, s.payload, [allGroup]);

  Stream<List<(String, MealSuggestionPayload)>> watchSuggestions() =>
      _watchReadable(ObjectKind.mealSuggestion).map(
        (rows) => [
          for (final (id, p) in rows) (id, MealSuggestionPayload.read(p)),
        ],
      );

  Future<String> savePoll(MealPollPayload poll, {String? id}) =>
      _put(ObjectKind.mealPoll, id, poll.payload, [allGroup]);

  Stream<List<(String, MealPollPayload)>> watchPolls() => _watchReadable(
    ObjectKind.mealPoll,
  ).map((rows) => [for (final (id, p) in rows) (id, MealPollPayload.read(p))]);

  Stream<List<(String, MealVotePayload)>> watchVotes() => _watchReadable(
    ObjectKind.mealVote,
  ).map((rows) => [for (final (id, p) in rows) (id, MealVotePayload.read(p))]);

  /// [memberId]'s ticks in poll [pollId], replacing any before.
  Future<void> castVote(String pollId, String memberId, Set<String> options) =>
      _put(
        ObjectKind.mealVote,
        const Uuid().v5(_importNamespace, 'vote/$pollId/$memberId'),
        MealVotePayload.write(
          pollId: pollId,
          memberId: memberId,
          options: options,
        ).payload,
        [allGroup],
      );

  /// Closes poll [pollId] (spec §4): the approval tally decides, unless a
  /// parent, [overriddenBy], picks [override], which the poll then shows
  /// beside what the vote said. The winner becomes that day's dinner, and a
  /// suggestion that won is scheduled.
  Future<void> closePoll(
    String pollId, {
    DateTime? now,
    String? override,
    String? overriddenBy,
  }) async {
    final at = now ?? DateTime.now().toUtc();
    final payload = await payloadOf(pollId);
    if (payload == null) return;
    final poll = MealPollPayload.read(payload);
    if (poll.state != PollState.open) return;
    final polls = await watchPolls().first;
    final lastWin = <String, DateTime>{};
    for (final (id, p) in polls) {
      if (id == pollId || p.state != PollState.closed) continue;
      final won = p.options.where((o) => o.id == p.winner).firstOrNull;
      final when = p.closedAt;
      if (won == null || when == null) continue;
      if (lastWin[won.proposer]?.isAfter(when) ?? false) continue;
      lastWin[won.proposer] = when;
    }
    final result = tallyPoll(
      options: [
        for (final o in poll.options)
          PollOption(id: o.id, proposer: o.proposer),
      ],
      eligible: poll.eligible.toSet(),
      votes: {
        for (final (_, v) in await watchVotes().first)
          if (v.pollId == pollId) v.memberId: v.options,
      },
      lastWin: lastWin,
    );
    final winnerId = override ?? result.winner;
    await savePoll(
      poll.closed(
        winner: winnerId,
        votedWinner: result.winner,
        at: at,
        overriddenBy: override == null ? null : overriddenBy,
      ),
      id: pollId,
    );
    final winner = poll.options.where((o) => o.id == winnerId).firstOrNull;
    final date = poll.date;
    if (winner == null || date == null) return;
    // That day's dinner: the one already planned, if any, takes the result.
    final planned = (await watchMeals().first)
        .where((m) => m.$2.date == date && m.$2.slot == 'dinner')
        .firstOrNull;
    final meal = planned?.$2;
    await saveMeal(
      MealPayload.write(
        existing: meal?.payload,
        date: date,
        title: winner.recipeId == null ? winner.title : meal?.title,
        servings: meal?.servings,
        cookMemberId: meal?.cookMemberId,
        chosenBy: meal?.chosenBy,
        recipes: [if (winner.recipeId case final r?) MealRecipe(recipeId: r)],
      ),
      id: planned?.$1 ?? const Uuid().v5(_importNamespace, 'poll/$pollId'),
    );
    if (winner.suggestionId case final s?) {
      if (await payloadOf(s) case final p?) {
        await saveSuggestion(
          MealSuggestionPayload.read(p).withState(SuggestionState.scheduled),
          id: s,
        );
      }
    }
  }

  /// Closes every open poll whose time is up; returns how many.
  Future<int> closeDuePolls({DateTime? now}) async {
    final at = now ?? DateTime.now().toUtc();
    var closed = 0;
    for (final (id, p) in await watchPolls().first) {
      if (p.state == PollState.open &&
          p.closesAt != null &&
          !p.closesAt!.isAfter(at)) {
        await closePoll(id, now: at);
        closed++;
      }
    }
    return closed;
  }

  /// The family's staples (spec §4: the `template` list of milk, bread and
  /// coffee that seeds every new list), made on first use.
  Future<String> staplesList({required String name}) async {
    for (final (id, l) in await watchShoppingLists().first) {
      if (l.state == ShoppingListState.template) return id;
    }
    return saveShoppingList(
      ShoppingListPayload.write(name: name, state: ShoppingListState.template),
    );
  }

  /// Puts the staples on [listId], each once: one already there, bought or
  /// not, isn't added again.
  Future<void> staplesToList(String listId, String staplesId) async {
    final items = await watchShoppingItems().first;
    final present = {
      for (final (_, i) in items)
        if (i.listId == listId)
          for (final s in i.sources) ?s.id,
    };
    final staples = [
      for (final (id, i) in items)
        if (i.listId == staplesId && !present.contains('staple:$id')) (id, i),
    ];
    for (final (id, staple) in staples) {
      await addToList(
        listId,
        [
          ShoppingLine(
            name: staple.name,
            key: staple.key,
            quantity: staple.quantity,
            unit: staple.unit,
            category: staple.category,
          ),
        ],
        source: (l) => ItemSource(
          type: 'staple',
          id: 'staple:$id',
          quantity: l.quantity,
          unit: l.unit,
        ),
      );
    }
  }

  /// A recipe's ingredients on a list, scaled from its portions to
  /// [servings], contributed under [sourceId] (the recipe's id unless
  /// said).
  Future<void> addRecipeToList(
    String listId,
    String recipeId,
    RecipePayload recipe, {
    int? servings,
    String? sourceId,
  }) {
    final factor = servings == null || recipe.servings == null
        ? 1.0
        : servings / recipe.servings!;
    return addToList(
      listId,
      [
        for (final text in recipe.ingredients)
          ShoppingLine.fromIngredient(
            IngredientLine.parse(text),
            IngredientCatalogue.swedish,
          ).scaled(factor),
      ],
      source: (l) => ItemSource(
        type: sourceId == null ? 'recipe' : 'meal',
        id: sourceId ?? recipeId,
        quantity: l.quantity,
        unit: l.unit,
        label: recipe.title,
      ),
    );
  }

  /// Grants a helper access (sealed to `adults`); returns the grant's id.
  /// Rewrap afterwards so they aren't looking at an empty calendar.
  Future<String> saveHelperGrant(HelperGrantPayload grant, {String? id}) =>
      _put(ObjectKind.helperGrant, id, grant.payload, [adultsGroup]);

  Stream<List<(String, HelperGrantPayload)>> watchHelperGrants() =>
      _watchReadable(ObjectKind.helperGrant).map(
        (rows) => [
          for (final (id, p) in rows) (id, HelperGrantPayload.read(p)),
        ],
      );

  // ---- calendar feeds (docs/roadmap.md "Integrations") -----------------------

  Future<String> saveCalendarLink(CalendarLinkPayload link, {String? id}) =>
      _put(ObjectKind.calendarLink, id, link.payload, [adultsGroup]);

  Stream<List<(String, CalendarLinkPayload)>> watchCalendarLinks() =>
      _watchReadable(ObjectKind.calendarLink).map(
        (rows) => [
          for (final (id, p) in rows) (id, CalendarLinkPayload.read(p)),
        ],
      );

  /// Removes the link and the events it brought that haven't happened yet;
  /// past ones stay, as history.
  Future<void> unlinkFeed(String linkId, {DateTime? now}) async {
    final cutoff = now ?? DateTime.now().toUtc();
    for (final (id, e) in await watchEvents().first) {
      if (e.payload.nested('source')?.text('link') != linkId) continue;
      final start = e.localStart;
      if (start != null && !start.isBefore(cutoff)) await deleteEvent(id);
    }
    await delete(ObjectKind.calendarLink, linkId);
  }

  /// Feed events that ended longer ago than this aren't brought in.
  static const importPast = Duration(days: 7);

  static bool _pastImport(EventPayload e, DateTime now) {
    final start = e.localStart;
    return e.rule == null &&
        start != null &&
        start.add(e.duration).isBefore(now.subtract(importPast));
  }

  /// Moves feed [linkId]'s events from member [from] to [to], when a parent
  /// changes whose calendar it is. Others the family added stay.
  Future<void> relinkFeed(
    String linkId, {
    required String from,
    required String to,
  }) async {
    for (final (id, e) in await watchEvents().first) {
      final source = e.payload.nested('source');
      if (source?.text('link') != linkId) continue;
      final copy = Payload.decode(e.payload.encode())
        ..setTexts(
          'participants',
          {for (final m in e.participantIds) m == from ? to : m}.toList(),
        )
        ..setNested('source', source!..setText('member', to));
      await saveEvent(EventPayload.read(copy), id: id);
    }
  }

  /// The event id for [uid] in feed [linkId]: the same on every fetch and
  /// every device, so a re-fetch updates rather than duplicates.
  static String importedEventId(String linkId, String uid) =>
      const Uuid().v5(_importNamespace, '$linkId/$uid');

  /// Brings the feed's events into the calendar for its member. What the
  /// feed owns (title, time, place, status, notes) follows the feed; what
  /// the family added (who drives, reminders, more people) stays. The link's
  /// usual driver, [responsibleMemberId], fills in only where no one is. A future
  /// event gone from the feed is marked cancelled. Returns how many events
  /// it wrote.
  Future<int> importFeed({
    required String linkId,
    required String memberId,
    required String timeZone,
    required List<ImportedEvent> events,
    String? responsibleMemberId,
    DateTime? now,
  }) async {
    final cutoff = now ?? DateTime.now().toUtc();
    var written = 0;
    final seen = <String>{};
    for (final e in events) {
      final id = importedEventId(linkId, e.uid);
      seen.add(id);
      final existing = await payloadOf(id);
      final before = existing == null ? null : EventPayload.read(existing);
      // Long over: not worth adding, and it may be one the family deleted.
      if (before == null &&
          e.rule == null &&
          e.localStart.add(e.duration).isBefore(cutoff.subtract(importPast))) {
        continue;
      }
      // Deleted here stays deleted: the family chose not to see it.
      if (before != null && before.isDeleted) continue;
      final source = existing?.nested('source');
      if (before != null &&
          (source?.integer('seq') ?? -1) >= e.sequence &&
          before.title == e.title &&
          before.localStart == e.localStart &&
          before.duration == e.duration &&
          before.location == e.location &&
          before.notes == e.description &&
          before.meetMinutesBefore == e.meetMinutesBefore &&
          source?.text('member') == memberId &&
          (before.responsibleMemberId != null || responsibleMemberId == null) &&
          (before.status == EventStatus.cancelled) == e.cancelled) {
        continue;
      }
      final payload = EventPayload.write(
        existing: existing,
        title: e.title,
        kind: before?.kind ?? EventKind.activity,
        localStart: e.localStart,
        duration: e.duration,
        timeZone: timeZone,
        status: e.cancelled ? EventStatus.cancelled : EventStatus.confirmed,
        visibility: before?.visibility ?? EventVisibility.family,
        rule: e.rule,
        participantIds: switch ((before, source?.text('member'))) {
          (null, _) => [memberId],
          // The link now belongs to someone else: they take the old one's
          // place, and whoever the family added stays.
          (final b?, final was?) when was != memberId => {
            for (final m in b.participantIds) m == was ? memberId : m,
          }.toList(),
          (final b?, _) => b.participantIds,
        },
        responsibleMemberId: before?.responsibleMemberId ?? responsibleMemberId,
        location: e.location,
        placeId: before?.placeId,
        notes: e.description,
        reminders: before?.reminders ?? const [],
      );
      payload.payload.setInteger('meet', e.meetMinutesBefore);
      payload.payload.setNested(
        'source',
        Payload.map()
          ..setText('link', linkId)
          ..setText('uid', e.uid)
          ..setText('member', memberId)
          ..setInteger('seq', e.sequence),
      );
      await saveEvent(payload, id: id);
      written++;
    }
    // Gone from the feed: cancelled, if it hadn't happened yet.
    for (final (id, e) in await watchEvents().first) {
      if (seen.contains(id) ||
          e.payload.nested('source')?.text('link') != linkId) {
        continue;
      }
      final start = e.localStart;
      if (start == null ||
          start.isBefore(cutoff) ||
          e.isDeleted ||
          e.status == EventStatus.cancelled) {
        continue;
      }
      final copy = Payload.decode(e.payload.encode())
        ..setText('status', EventStatus.cancelled.name);
      await saveEvent(EventPayload.read(copy), id: id);
      written++;
    }
    return written;
  }

  // ---- audiences (crypto doc §6) ---------------------------------------------

  /// Helpers whose access is live and whose key this device holds: only a
  /// parent's device writes helper wraps.
  Future<List<HelperGrantPayload>> _activeHelpers() async {
    final now = DateTime.now().toUtc();
    final keyring = _keyring();
    return [
      for (final (_, g) in await watchHelperGrants().first)
        if (g.activeAt(now) && keyring.latestEpoch(group: g.group) != null) g,
    ];
  }

  // A set: one helper with two grants (say, a co-parent who also babysat)
  // is one audience, and sealing refuses duplicates.
  Future<List<String>> _helperGroups({List<String>? participants}) async => {
    for (final g in await _activeHelpers())
      // An event for the whole family involves their children too.
      if (participants == null ||
          participants.isEmpty ||
          participants.any(g.childIds.contains))
        g.group,
  }.toList();

  /// Parents-only events reach `adults` alone; the rest reach everyone, and
  /// any helper covering a child it involves.
  Future<List<String>> _eventGroups(EventPayload event) async =>
      event.visibility == EventVisibility.parentsOnly
      ? [adultsGroup]
      : [allGroup, ...await _helperGroups(participants: event.participantIds)];

  /// The same audience as the exception's event.
  Future<List<String>> _exceptionGroups(
    EventExceptionPayload exception, {
    EventVisibility? fallback,
  }) async {
    final event = await payloadOf(exception.eventId);
    if (event != null) return _eventGroups(EventPayload.read(event));
    return [fallback == EventVisibility.parentsOnly ? adultsGroup : allGroup];
  }

  /// Who an object should reach, by kind; null for a kind this client
  /// doesn't know, whose audience it leaves alone.
  Future<List<String>?> _groupsFor(ObjectKind kind, Payload payload) async =>
      switch (kind) {
        ObjectKind.event => _eventGroups(EventPayload.read(payload)),
        ObjectKind.eventException => _exceptionGroups(
          EventExceptionPayload.read(payload),
        ),
        ObjectKind.memberProfile ||
        ObjectKind.place => [allGroup, ...await _helperGroups()],
        ObjectKind.settings ||
        ObjectKind.action ||
        ObjectKind.person ||
        ObjectKind.absence ||
        ObjectKind.locationShare ||
        ObjectKind.approvalRequest ||
        ObjectKind.equipmentSet ||
        ObjectKind.homework ||
        ObjectKind.homeworkTemplate ||
        ObjectKind.subject ||
        ObjectKind.wishlist ||
        ObjectKind.wishlistItem ||
        ObjectKind.actionTemplate ||
        ObjectKind.meal ||
        ObjectKind.mealSuggestion ||
        ObjectKind.mealPoll ||
        ObjectKind.mealVote ||
        ObjectKind.recipe ||
        ObjectKind.shoppingList ||
        ObjectKind.shoppingListItem => [allGroup],
        ObjectKind.wishlistClaim => _claimGroups(
          WishlistClaimPayload.read(payload).ownerMemberId,
        ),
        ObjectKind.credential => [
          passwordGroup(CredentialPayload.read(payload).scope),
        ],
        ObjectKind.helperGrant || ObjectKind.calendarLink => [adultsGroup],
        ObjectKind.custody => _custodyGroups(CustodyPayload.read(payload)),
      };

  /// The stored payload of an object, to edit it without losing fields this
  /// client doesn't know (crypto doc §5 rule 2).
  Future<Payload?> payloadOf(String id) async {
    final row = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    return row?.payload == null ? null : _tryDecode(row!.payload!);
  }

  Future<void> delete(ObjectKind kind, String id) async {
    await _enqueue(
      type: 'object.delete',
      kind: kind,
      id: id,
      envelope: Uint8List(0),
    );
    await (_cache.update(_cache.cachedObjects)..where((o) => o.id.equals(id)))
        .write(const CachedObjectsCompanion(deleted: Value(true)));
  }

  Future<String> _put(
    ObjectKind kind,
    String? id,
    Payload payload,
    List<String> groups,
  ) async {
    final objectId = id ?? _uuid.v4();
    if (memberId case final me?) {
      // Who made it, once: "own" events (spec §2) are the ones a member made.
      if (!payload.has('createdBy')) payload.setText('createdBy', me);
      payload
        ..setText('editedBy', me)
        ..setText('editedAt', DateTime.now().toUtc().toIso8601String());
    }
    final bytes = payload.encode();
    final envelope = seal(
      payload: bytes,
      object: ObjectSlot(
        objectType: kind.slotType,
        id: objectId,
        familyId: familyId,
      ),
      audiences: _latest(groups),
      keyring: _keyring(),
    );

    await _enqueue(
      type: 'object.upsert',
      kind: kind,
      id: objectId,
      envelope: envelope,
    );
    // Shown at once: local-first.
    await _cache
        .into(_cache.cachedObjects)
        .insert(
          CachedObjectsCompanion.insert(
            id: objectId,
            kind: kind.wire,
            scope: _scope,
            version: 0,
            envelope: Value(envelope),
            payload: Value(bytes),
          ),
          onConflict: DoUpdate(
            (_) => CachedObjectsCompanion(
              envelope: Value(envelope),
              payload: Value(bytes),
              deleted: const Value(false),
              unreadable: const Value(null),
            ),
          ),
        );
    return objectId;
  }

  /// [groups] at the newest epoch this device holds for each: after a
  /// rotation, new writes reach only the devices still in the group.
  List<Audience> _latest(Iterable<String> groups) {
    final keyring = _keyring();
    return [
      for (final g in groups)
        Audience(
          group: g,
          epoch: keyring.latestEpoch(group: g) ?? currentEpoch,
        ),
    ];
  }

  /// Moves up to [limit] readable objects, newest first, to the audiences
  /// they should have now, at the newest epochs, without re-encrypting their
  /// content. Run after a rotation (crypto doc §9: rewrap recent objects
  /// eagerly, and a removed device reads nothing written from here on) and
  /// after granting a helper (so they aren't looking at an empty calendar).
  /// Only groups this device holds keys for are wrapped to. Returns how many
  /// it rewrapped.
  Future<int> rewrapToLatest({int limit = 500}) async {
    final rows =
        await (_cache.select(_cache.cachedObjects)
              ..where(
                (o) =>
                    o.deleted.equals(false) &
                    o.payload.isNotNull() &
                    o.envelope.isNotNull(),
              )
              ..orderBy([(o) => OrderingTerm.desc(o.version)])
              ..limit(limit))
            .get();
    final keyring = _keyring();
    var count = 0;
    for (final row in rows) {
      final kind = ObjectKind.fromWire(row.kind);
      final payload = _tryDecode(row.payload!);
      if (kind == null || payload == null) continue;
      final EnvelopeHeader header;
      try {
        header = inspect(envelope: row.envelope!);
      } on CryptoException {
        continue;
      }
      final groups = [
        for (final g
            in await _groupsFor(kind, payload) ??
                [for (final a in header.audiences) a.group])
          if (keyring.latestEpoch(group: g) != null) g,
      ];
      if (groups.isEmpty) continue;
      final target = _latest(groups);
      final wanted = {for (final a in target) '${a.group}@${a.epoch}'};
      final current = {
        for (final a in header.audiences) '${a.group}@${a.epoch}',
      };
      if (wanted.length == current.length && wanted.containsAll(current)) {
        continue;
      }
      final Uint8List envelope;
      try {
        envelope = rewrap(
          envelope: row.envelope!,
          audiences: target,
          keyring: keyring,
        );
      } on CryptoException {
        continue;
      }
      await _enqueue(
        type: _rewrapType,
        kind: kind,
        id: row.id,
        envelope: envelope,
      );
      await (_cache.update(_cache.cachedObjects)
            ..where((o) => o.id.equals(row.id)))
          .write(CachedObjectsCompanion(envelope: Value(envelope)));
      count++;
    }
    return count;
  }

  Future<void> _enqueue({
    required String type,
    required ObjectKind kind,
    required String id,
    required Uint8List envelope,
  }) async {
    await _queue.transaction(() async {
      await _queue
          .into(_queue.queuedCommands)
          .insert(
            QueuedCommandsCompanion.insert(
              clientCommandId: _uuid.v4(),
              type: type,
              targetId: id,
              targetKind: kind.wire,
              scope: _scope,
              envelope: envelope,
              expectedVersion: Value(await _expectedVersion(id)),
              issuedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  /// The version the server should hold when this write lands. Earlier writes
  /// to the same object still in the queue each add one, so a string of
  /// offline edits doesn't conflict with itself.
  Future<int?> _expectedVersion(String id) async {
    final row = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    final pending = await (_queue.select(
      _queue.queuedCommands,
    )..where((c) => c.targetId.equals(id) & c.state.equals('pending'))).get();
    final base = row?.version ?? 0;
    if (pending.isEmpty) return row == null || base == 0 ? null : base;
    return base + pending.length;
  }

  // ---- sync -----------------------------------------------------------------

  Future<SyncReport>? _syncing;

  /// Pushes queued writes, then pulls what changed. Concurrent calls share one
  /// run.
  Future<SyncReport> sync() {
    return _syncing ??= _sync(resendRebased: true)
        .whenComplete(() => _syncing = null);
  }

  Future<SyncReport> _sync({required bool resendRebased}) async {
    // Photos first, so what points at them never arrives before them.
    try {
      await uploadPhotos();
    } on Object {
      // Offline: they wait in the queue for the next sync.
    }
    var pushed = 0;
    var rebased = 0;
    var rejected = 0;

    final queued =
        await (_queue.select(_queue.queuedCommands)
              ..where((c) => c.state.equals('pending'))
              ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
            .get();
    if (queued.isNotEmpty) {
      final results = await _api.submitCommands(
        asDevice: deviceId,
        commands: [
          for (final c in queued)
            OutgoingCommand(
              clientCommandId: c.clientCommandId,
              type: c.type == _rewrapType ? 'object.upsert' : c.type,
              targetId: c.targetId,
              targetKind: c.targetKind,
              scope: c.scope,
              envelope: c.envelope,
              expectedVersion: c.expectedVersion,
              issuedAt: c.issuedAt,
            ),
        ],
      );
      for (final r in results) {
        final where = _queue.update(_queue.queuedCommands)
          ..where((c) => c.clientCommandId.equals(r.clientCommandId));
        switch (r.status) {
          case 'applied' || 'duplicate':
            await (_queue.delete(
              _queue.queuedCommands,
            )..where((c) => c.clientCommandId.equals(r.clientCommandId))).go();
            pushed++;
          case 'conflict'
              when queued.any(
                (c) =>
                    c.clientCommandId == r.clientCommandId &&
                    c.type == _rewrapType,
              ):
            // Someone wrote since; their version stands. It moves to the new
            // epoch on its next write.
            await (_queue.delete(
              _queue.queuedCommands,
            )..where((c) => c.clientCommandId.equals(r.clientCommandId))).go();
          case 'conflict':
            // Last writer wins, for now: whole-object upserts are rebased on
            // the server's version and resent. The server can't merge; a
            // field-level merge on the client can replace this later.
            await where.write(
              QueuedCommandsCompanion(
                expectedVersion: Value(r.sequence),
                attempts: const Value.absent(),
                lastError: Value('conflict at version ${r.sequence}'),
              ),
            );
            rebased++;
          default:
            await where.write(
              QueuedCommandsCompanion(
                state: const Value('rejected'),
                lastError: Value(r.reason ?? r.status),
              ),
            );
            rejected++;
        }
      }
    }

    final pulled = await _pull();
    await _overlayPending();
    if (rebased > 0 && resendRebased) {
      // Resend the rebased edits now rather than on the next sync. Once only:
      // if another device keeps winning, the next sync tries again.
      final again = await _sync(resendRebased: false);
      pushed += again.pushed;
    }
    return SyncReport(
      pushed: pushed,
      pulled: pulled,
      rebased: rebased,
      rejected: rejected,
    );
  }

  Future<int> _pull() async {
    var cursor = int.tryParse(await _state(_cursorKey) ?? '') ?? 0;
    var count = 0;
    while (true) {
      final page = await _api.pull(asDevice: deviceId, since: cursor);
      await _cache.transaction(() async {
        for (final change in page.changes) {
          await _store(change);
        }
        await _setState(_cursorKey, '${page.cursor}');
      });
      count += page.changes.length;
      cursor = page.cursor;
      if (!page.hasMore) return count;
    }
  }

  Future<void> _store(RemoteObject change) async {
    Uint8List? payload;
    String? unreadable;
    if (!change.deleted && change.envelope != null) {
      (payload, unreadable) = _open(change.envelope!, change.id, change.kind);
    }
    await _cache
        .into(_cache.cachedObjects)
        .insertOnConflictUpdate(
          CachedObjectsCompanion.insert(
            id: change.id,
            kind: change.kind,
            scope: change.scope,
            version: change.version,
            deleted: Value(change.deleted),
            envelope: Value(change.envelope),
            payload: Value(payload),
            unreadable: Value(unreadable),
          ),
        );
  }

  /// Decrypts an envelope the server says belongs to object [id] of [kind],
  /// checking the envelope agrees: its slot is authenticated, the server's
  /// claim is not. Without this check the server could serve one object's
  /// valid envelope under another's id.
  (Uint8List?, String?) _open(Uint8List envelope, String id, int kind) {
    try {
      final opened = open(envelope: envelope, keyring: _keyring());
      final slot = opened.header.object;
      final expected = ObjectKind.fromWire(kind);
      if (slot.id != id ||
          slot.familyId != familyId ||
          expected == null ||
          slot.objectType != expected.slotType) {
        return (null, 'damaged');
      }
      return (opened.payload, null);
    } on CryptoException catch (e) {
      return (
        null,
        e.kind == CryptoErrorKind.noAccess ? 'noAccess' : 'damaged',
      );
    }
  }

  /// Shows queued writes on top of the server state just pulled, so a pull
  /// never hides an edit that hasn't uploaded yet.
  Future<void> _overlayPending() async {
    final pending =
        await (_queue.select(_queue.queuedCommands)
              ..where((c) => c.state.equals('pending'))
              ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
            .get();
    for (final c in pending) {
      // Same content under new wraps: nothing to show that isn't shown.
      if (c.type == _rewrapType) continue;
      final companion = c.type == 'object.delete'
          ? const CachedObjectsCompanion(deleted: Value(true))
          : CachedObjectsCompanion(
              payload: Value(_open(c.envelope, c.targetId, c.targetKind).$1),
              envelope: Value(c.envelope),
              deleted: const Value(false),
            );
      await (_cache.update(
        _cache.cachedObjects,
      )..where((o) => o.id.equals(c.targetId))).write(companion);
    }
  }

  /// Tries again to open objects this device couldn't read, e.g. after a new
  /// grant arrived. Returns how many became readable.
  Future<int> reopenUnreadable() async {
    final rows = await (_cache.select(
      _cache.cachedObjects,
    )..where((o) => o.unreadable.isNotNull() & o.envelope.isNotNull())).get();
    var opened = 0;
    for (final row in rows) {
      final (payload, unreadable) = _open(row.envelope!, row.id, row.kind);
      if (payload != null) opened++;
      await (_cache.update(
        _cache.cachedObjects,
      )..where((o) => o.id.equals(row.id))).write(
        CachedObjectsCompanion(
          payload: Value(payload),
          unreadable: Value(unreadable),
        ),
      );
    }
    return opened;
  }

  /// Commands the server refused or that failed, for a person to see.
  Future<List<QueuedCommand>> stuckCommands() => (_queue.select(
    _queue.queuedCommands,
  )..where((c) => c.state.equals('rejected'))).get();

  /// A setting for this device only, never synced: which calendar filter it
  /// shows, say (spec §5). Kept in the encrypted cache beside sync state.
  Future<String?> devicePreference(String name) => _state('pref.$name');

  Future<void> setDevicePreference(String name, String value) =>
      _setState('pref.$name', value);

  Future<String?> _state(String key) async => (await (_cache.select(
    _cache.syncState,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setState(String key, String value) => _cache
      .into(_cache.syncState)
      .insertOnConflictUpdate(SyncStateEntry(key: key, value: value));

  static Payload? _tryDecode(Uint8List bytes) {
    try {
      return Payload.decode(bytes);
    } on FormatException {
      return null;
    }
  }
}
