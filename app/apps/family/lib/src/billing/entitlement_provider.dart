import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/family_api_provider.dart';
import '../data/store_providers.dart';
import '../membership/membership.dart';

/// What this family has paid for (docs/going-public.md).
///
/// The server decides, and a device only ever asks: a client that could
/// declare itself paid would not be a paywall. But the answer is kept, in
/// this device's own preferences, so that the family calendar does not
/// depend on a network — and so that a family who has paid is never told
/// otherwise by a tunnel. [Entitlement] holds the rule for how long a
/// cached answer is worth trusting.
///
/// Refreshed on the ordinary sync, like everything else the outside world
/// tells this app. A failure is silent by design: nothing about a fetch
/// that did not happen should reach a person.
final entitlementProvider =
    AsyncNotifierProvider<EntitlementController, Entitlement>(
      EntitlementController.new,
    );

class EntitlementController extends AsyncNotifier<Entitlement> {
  static const _key = 'billing.entitlement.v1';
  static const _billingKey = 'billing.id.v1';

  @override
  Future<Entitlement> build() async {
    // The cache, not the server: this runs at start-up, where a network
    // round trip would hold up the first screen for no good reason.
    if (await ref.watch(membershipProvider.future) == null) {
      return const Entitlement.unknown();
    }
    final prefs = await ref.watch(devicePreferencesProvider.future);
    final cached = await prefs.read(_key);
    if (cached == null) return const Entitlement.unknown();
    try {
      return Entitlement.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } on Object catch (e) {
      debugPrint('Cached entitlement unreadable: $e');
      return const Entitlement.unknown();
    }
  }

  /// Asks the server, and keeps what it says. Called from the sync cycle.
  Future<void> refresh() async {
    final membership = await ref.read(membershipProvider.future);
    if (membership == null) return;
    try {
      final answer = await ref
          .read(familyApiProvider)
          .fetchEntitlement(asDevice: membership.deviceId);
      final prefs = await ref.read(devicePreferencesProvider.future);
      await prefs.write(_key, jsonEncode(answer.entitlement.toJson()));
      // Kept for the billing provider's SDK, which registers under this and
      // never learns the family id — see the Subscription entity for why.
      await prefs.write(_billingKey, answer.billingId);
      state = AsyncData(answer.entitlement);
    } on Object catch (e) {
      // A server that cannot be reached says nothing about whether anyone
      // has paid. The cached answer stands, with its grace.
      debugPrint('Entitlement not refreshed: $e');
    }
  }

  /// What the billing provider knows this family as, once known.
  Future<String?> billingId() async =>
      (await ref.read(devicePreferencesProvider.future)).read(_billingKey);
}

/// Whether [feature] may be used right now.
///
/// Null while nothing is known yet — a fresh install that has not synced.
/// A screen should wait rather than show a paywall to someone who may well
/// have paid.
bool? premiumAllows(WidgetRef ref, PaidFeature feature) {
  final entitlement = ref.watch(entitlementProvider).value;
  if (entitlement == null || !entitlement.known) return null;
  return entitlement.allows(feature, DateTime.now().toUtc());
}
