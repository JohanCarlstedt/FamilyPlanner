import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'entitlement_provider.dart';

/// Buying premium, through the platform's own store.
///
/// Both stores require it: a subscription to something used inside the app
/// is sold by Apple or Google or not at all. RevenueCat sits in front of
/// both so there is one set of products, one notion of an entitlement, and
/// one webhook — rather than two store APIs, two notification formats, and
/// every edge of grace periods and refunds written twice.
///
/// **What it is told about this family is a random id and nothing else**
/// (see the `Subscription` entity): no name, no email, no content. Our
/// server, not this class, decides whether the family has premium — the
/// purchase here is what causes that, through the store's notification,
/// never a claim this device makes.
///
/// Unconfigured is a supported state. Without a key — a development build,
/// a self-hosted family, a build made before the store products existed —
/// nothing initialises and [available] is false. The same shape as the
/// Google Maps key: a missing key changes what is offered, never whether
/// the app runs.
class Billing {
  const Billing(this._ref);

  final Ref _ref;

  /// Public SDK keys, per platform. They ship inside the binary by design
  /// — RevenueCat's public key can only read and buy for one app — but
  /// they still arrive by --dart-define so that a build without them is
  /// the default rather than an accident.
  static const _appleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const _googleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

  /// The entitlement as RevenueCat knows it. Named the same on both
  /// stores, so one string is the whole mapping.
  static const entitlementId = 'premium';

  static String get _key => Platform.isIOS || Platform.isMacOS
      ? _appleKey
      : Platform.isAndroid
      ? _googleKey
      : '';

  /// Whether anything can be bought in this build at all.
  static bool get available => _key.isNotEmpty;

  /// The id the SDK is currently running as, or null before it has been
  /// configured at all. Kept so that starting again is free: this is
  /// called from the sync cycle, and logging in once an hour to say the
  /// same thing would be a network call for nothing.
  static String? _runningAs;

  /// Starts the SDK under this family's billing id.
  ///
  /// Called before the paywall is shown rather than at launch: it is a
  /// network-backed SDK, and a family that never opens the paywall should
  /// not pay for it in start-up time. Safe to call repeatedly.
  Future<bool> start() async {
    if (!available) return false;
    final billingId = await _ref
        .read(entitlementProvider.notifier)
        .billingId();
    // Before the first sync there is no id, and buying under an anonymous
    // one would attach the purchase to nothing our server can find.
    if (billingId == null) return false;

    if (_runningAs == billingId) return true;

    try {
      if (_runningAs == null) {
        await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.warn,
        );
        await Purchases.configure(
          PurchasesConfiguration(_key)..appUserID = billingId,
        );
      } else {
        // The same device, a different family: unbound and set up again.
        await Purchases.logIn(billingId);
      }
      _runningAs = billingId;
      return true;
    } on Object catch (e) {
      debugPrint('Purchases could not start: $e');
      return false;
    }
  }

  /// What may be bought, or null when there is nothing to offer — no key,
  /// no products configured yet, or no network.
  Future<Offering?> offering() async {
    if (!await start()) return null;
    try {
      return (await Purchases.getOfferings()).current;
    } on Object catch (e) {
      debugPrint('No offerings: $e');
      return null;
    }
  }

  /// Buys [package], and waits for our own server to agree.
  ///
  /// The store's notification reaches the server in about a second, but
  /// "about" is doing work there, so this asks a few times before giving
  /// up. It never decides the family is premium on its own: a device that
  /// could would not be a paywall, and the receipt is safe with the store
  /// either way.
  Future<PurchaseOutcome> buy(Package package) async {
    if (!await start()) return PurchaseOutcome.unavailable;
    try {
      await Purchases.purchase(PurchaseParams.package(package));
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      debugPrint('Purchase failed: $code');
      return PurchaseOutcome.failed;
    } on Object catch (e) {
      debugPrint('Purchase failed: $e');
      return PurchaseOutcome.failed;
    }
    return await _waitForTheServer()
        ? PurchaseOutcome.bought
        : PurchaseOutcome.boughtButNotYetArrived;
  }

  /// Restores a subscription bought on another device, or before a
  /// reinstall. Both stores require this to exist and to be reachable
  /// without buying anything.
  Future<PurchaseOutcome> restore() async {
    if (!await start()) return PurchaseOutcome.unavailable;
    try {
      final info = await Purchases.restorePurchases();
      if (!info.entitlements.active.containsKey(entitlementId)) {
        return PurchaseOutcome.nothingToRestore;
      }
    } on Object catch (e) {
      debugPrint('Restore failed: $e');
      return PurchaseOutcome.failed;
    }
    return await _waitForTheServer()
        ? PurchaseOutcome.bought
        : PurchaseOutcome.boughtButNotYetArrived;
  }

  /// Asks our server until it has heard from the store, or we give up.
  ///
  /// Backs off rather than hammering: the webhook usually lands before the
  /// first ask, and a server that has not heard in fifteen seconds will
  /// not hear in the sixteenth either. Giving up is not a failure — the
  /// ordinary sync collects it later, on every device.
  Future<bool> _waitForTheServer() async {
    const waits = [
      Duration(milliseconds: 400),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];
    final entitlement = _ref.read(entitlementProvider.notifier);
    for (final wait in waits) {
      await Future<void>.delayed(wait);
      await entitlement.refresh();
      final now = _ref.read(entitlementProvider).value;
      if (now != null && now.isPremiumAt(DateTime.now().toUtc())) return true;
    }
    return false;
  }
}

/// What came of asking to buy. Cancelled is not an error and must not be
/// reported as one: changing your mind at the store sheet is the most
/// ordinary thing a person does there.
enum PurchaseOutcome {
  bought,

  /// Paid for, and the store has not told our server yet. The family will
  /// have it shortly, on every device, without doing anything.
  boughtButNotYetArrived,

  cancelled,
  nothingToRestore,
  failed,

  /// No store in this build: a development or self-hosted one.
  unavailable,
}

final purchasesProvider = Provider<Billing>(Billing.new);
