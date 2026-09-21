import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/server_address.dart';
import '../../billing/entitlement_provider.dart';
import '../../billing/purchases.dart';
import '../../common/l10n.dart';

/// More > Premium: what the subscription covers, and the way to buy it.
///
/// Every line the stores insist on is here and is meant to stay: what is
/// being sold, for how long, at what price, that it renews by itself until
/// cancelled, how to restore one bought elsewhere, and where the terms and
/// the privacy policy are. Apps are turned away for missing any of them,
/// and a person deciding whether to pay is owed all of them anyway.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  static const segment = 'premium';

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Offering? _offering;
  String? _billingId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final offering = await ref.read(purchasesProvider).offering();
    final billingId = await ref.read(entitlementProvider.notifier).billingId();
    if (!mounted) return;
    setState(() {
      _offering = offering;
      _billingId = billingId;
      _loading = false;
    });
  }

  Future<void> _buy(Package package) async {
    setState(() => _busy = true);
    final outcome = await ref.read(purchasesProvider).buy(package);
    if (!mounted) return;
    setState(() => _busy = false);
    _say(outcome);
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final outcome = await ref.read(purchasesProvider).restore();
    if (!mounted) return;
    setState(() => _busy = false);
    _say(outcome);
  }

  void _say(PurchaseOutcome outcome) {
    final l10n = context.l10n;
    // Cancelling at the store sheet is the most ordinary thing a person
    // does there, and saying anything about it would be nagging.
    if (outcome == PurchaseOutcome.cancelled) return;
    final message = switch (outcome) {
      PurchaseOutcome.bought => l10n.premiumThanks,
      PurchaseOutcome.boughtButNotYetArrived => l10n.premiumOnItsWay,
      PurchaseOutcome.nothingToRestore => l10n.premiumNothingToRestore,
      PurchaseOutcome.unavailable => l10n.premiumUnavailable,
      PurchaseOutcome.failed => l10n.premiumFailed,
      PurchaseOutcome.cancelled => '',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entitlement =
        ref.watch(entitlementProvider).value ?? const Entitlement.unknown();
    final premium = entitlement.isPremiumAt(DateTime.now().toUtc());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premium)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (premium) _Current(entitlement: entitlement) else _Pitch(),
          const SizedBox(height: 24),

          if (!premium) ...[
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_offering == null)
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    Billing.available
                        ? l10n.premiumNoOffers
                        : l10n.premiumUnavailable,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              for (final package in _offering!.availablePackages)
                _PackageTile(
                  package: package,
                  onTap: _busy ? null : () => _buy(package),
                ),
            const SizedBox(height: 16),
            // Required wording, and true: the store charges again each
            // period until someone stops it, and only the store can.
            Text(
              l10n.premiumRenews,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _restore,
            child: Text(l10n.premiumRestore),
          ),
          if (premium)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  Platform.isIOS || Platform.isMacOS
                      ? 'https://apps.apple.com/account/subscriptions'
                      : 'https://play.google.com/store/account/subscriptions',
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(l10n.premiumManage),
            ),

          const Divider(height: 32),
          // For support: the only name this family has at the billing
          // provider, and what a grant is made against. Opaque, so it
          // gives away nothing if someone reads it over a shoulder.
          if (_billingId != null)
            Center(
              child: SelectableText(
                l10n.premiumBillingId(_billingId!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => launchUrl(
                  // The family's own server serves it, so a self-hosted
                  // household reads its own copy rather than ours.
                  ref.read(serverProvider).replace(path: '/privacy'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(l10n.privacyPolicy),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_termsUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(l10n.termsOfUse),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Apple's standard EULA, which is what applies when an app does not
  /// supply its own, and which Apple expects to be linked from here.
  static String get _termsUrl => Platform.isIOS || Platform.isMacOS
      ? 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'
      : 'https://play.google.com/about/play-terms/';
}

/// What premium covers, in the order someone would care about it.
class _Pitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.premiumHeadline, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          l10n.premiumFreeStays,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final (icon, text) in [
          (Icons.school_outlined, l10n.premiumIntegrations),
          (Icons.map_outlined, l10n.premiumMap),
          (Icons.restaurant_outlined, l10n.premiumFood),
          (Icons.lock_outline, l10n.premiumPasswords),
          (Icons.kitchen_outlined, l10n.premiumKitchen),
          (Icons.home_outlined, l10n.premiumTwoHomes),
          (Icons.photo_library_outlined, l10n.premiumPhotos),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// What a family that already has premium is told: what they have, until
/// when, and — when it was given rather than sold — that nobody is paying.
class _Current extends StatelessWidget {
  const _Current({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final until = entitlement.until;
    // The open-ended grant is stored as a date far enough away to mean
    // "no end"; showing the year 9999 to a person would be absurd.
    final endless =
        entitlement.source == EntitlementSource.granted ||
        until == null ||
        until.year > 9000;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.premiumActive,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              endless
                  ? l10n.premiumGranted
                  : l10n.premiumUntil(
                      MaterialLocalizations.of(
                        context,
                      ).formatFullDate(until.toLocal()),
                    ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package, this.onTap});

  final Package package;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final product = package.storeProduct;
    final free = product.introductoryPrice;

    // How long a period lasts, said here rather than trusted to whatever
    // someone typed into the store's display name. Apple requires the
    // duration on screen, and a listing's title is easy to get wrong in
    // one language and not another.
    final period = switch (package.packageType) {
      PackageType.monthly => l10n.premiumPerMonth,
      PackageType.annual => l10n.premiumPerYear,
      PackageType.weekly => l10n.premiumPerWeek,
      _ => null,
    };

    return Card(
      child: ListTile(
        onTap: onTap,
        // The store's own title and price: already in the person's
        // currency and format, and never a number worked out here.
        title: Text(product.title),
        subtitle: Text(
          [
            // That there is a trial, said here; exactly how long it runs
            // is on the store's own purchase sheet, which is the one place
            // it is guaranteed to be right in every language and region.
            if (free != null && free.price == 0) l10n.premiumFreeFirst,
            product.description,
          ].where((line) => line.isNotEmpty).join('\n'),
        ),
        isThreeLine: free != null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              product.priceString,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (period != null)
              Text(period, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
