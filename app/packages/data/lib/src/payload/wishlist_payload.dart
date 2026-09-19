import 'payload.dart';

/// A wishlist for one person and one occasion (spec §3 `wishlist`, kind
/// 10). It doesn't recur with the birthday: last year's list is carried
/// forward on purpose, never by itself.
class WishlistPayload {
  WishlistPayload._(this.payload);

  static const version = 1;

  factory WishlistPayload.read(Payload payload) => WishlistPayload._(payload);

  factory WishlistPayload.write({
    Payload? existing,
    required String personId,
    required String name,
    String occasion = 'birthday',
    String? carriedFrom,
    bool active = true,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('person', personId)
      ..setText('name', name)
      ..setText('occasion', occasion)
      ..setText('carriedFrom', carriedFrom)
      ..setBoolean('active', active);
    return WishlistPayload._(p);
  }

  final Payload payload;

  /// Whose list: a person, who may be a member.
  String get personId => payload.text('person') ?? '';
  String get name => payload.text('name') ?? '';

  /// `birthday`, `christmas` or `none`.
  String get occasion => payload.text('occasion') ?? 'none';
  String? get carriedFrom => payload.text('carriedFrom');
  bool get active => payload.boolean('active') ?? true;
}

/// Something wished for (spec §3 `wishlist_item`, kind 11).
class WishlistItemPayload {
  WishlistItemPayload._(this.payload);

  static const version = 1;

  factory WishlistItemPayload.read(Payload payload) =>
      WishlistItemPayload._(payload);

  factory WishlistItemPayload.write({
    Payload? existing,
    required String wishlistId,
    required String title,
    String? url,
    String? note,
    String? size,
    bool received = false,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('wishlist', wishlistId)
      ..setText('title', title)
      ..setText('url', url)
      ..setText('note', note)
      ..setText('size', size)
      ..setBoolean('received', received);
    return WishlistItemPayload._(p);
  }

  final Payload payload;

  String get wishlistId => payload.text('wishlist') ?? '';
  String get title => payload.text('title') ?? '';
  String? get url => payload.text('url');
  String? get note => payload.text('note');
  String? get size => payload.text('size');
  bool get received => payload.boolean('received') ?? false;
}

/// Everyone but [ownerMemberId]: the group a claim on their list is sealed
/// to, so hiding claims from the person they're for is a fact about the
/// keys, not a rule of a query (crypto doc §3).
String wishlistObserversGroup(String ownerMemberId) =>
    'wishlist:$ownerMemberId:observers';

/// "I'll buy this" (spec §3 `wishlist_claim`, kind 22).
class WishlistClaimPayload {
  WishlistClaimPayload._(this.payload);

  static const version = 1;

  factory WishlistClaimPayload.read(Payload payload) =>
      WishlistClaimPayload._(payload);

  factory WishlistClaimPayload.write({
    required String itemId,
    required String claimedBy,
    required DateTime at,
    String? ownerMemberId,
    bool purchased = false,
  }) => WishlistClaimPayload._(
    Payload.create(version)
      ..setText('item', itemId)
      ..setText('by', claimedBy)
      ..setText('owner', ownerMemberId)
      ..setText('at', at.toUtc().toIso8601String())
      ..setBoolean('purchased', purchased),
  );

  final Payload payload;

  String get itemId => payload.text('item') ?? '';
  String get claimedBy => payload.text('by') ?? '';

  /// The member whose list it is, when the list is a member's: the claim is
  /// sealed to everyone but them (crypto doc §3 `wishlist:{…}:observers`).
  String? get ownerMemberId => payload.text('owner');
  bool get purchased => payload.boolean('purchased') ?? false;
}
