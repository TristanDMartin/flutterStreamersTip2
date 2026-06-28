import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants/app_colors.dart';
import '../features/billing/debug_studio_bypass.dart';
import '../features/billing/models/subscription_billing_source.dart';
import '../features/billing/models/subscription_snapshot.dart';
import '../features/billing/subscription_manage_service.dart';
import '../features/billing/subscription_provider.dart';
import '../features/billing/tier_display_names.dart';
import '../features/billing/upgrade_tier_marketing.dart';
import '../features/billing/iap_billing_coordinator.dart';
import '../features/billing/iap_billing_facade.dart';
import '../features/billing/store_product_catalog.dart';
import '../features/billing/store_product_ids.dart';
import '../services/creator_intelligence_analytics_service.dart';
import 'contact_support_view.dart';

class UpgradeView extends ConsumerStatefulWidget {
  const UpgradeView({super.key});

  @override
  ConsumerState<UpgradeView> createState() => _UpgradeViewState();
}

class _UpgradeViewState extends ConsumerState<UpgradeView> {
  Color get _on => Theme.of(context).colorScheme.onSurface;
  Color get _onP => Theme.of(context).colorScheme.onPrimary;

  IapBillingFacade get _iap => IapBillingCoordinator.instance.facade;
  final SubscriptionManageService _manageService =
      const SubscriptionManageService();

  void _onIapUi() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPurchaseVerified() {
    unawaited(_handlePurchaseVerified());
  }

  Future<void> _handlePurchaseVerified() async {
    if (!mounted) {
      return;
    }
    invalidateSubscriptionEntitlements(ref);
    try {
      final SubscriptionSnapshot snapshot =
          await refreshSubscriptionEntitlements(ref, forceRefresh: true);
      unawaited(
        CreatorIntelligenceAnalyticsService().trackSubscriptionStarted(
          tier: snapshot.tierApi,
        ),
      );
    } catch (e) {
      debugPrint('UpgradeView: post-purchase entitlements refresh failed: $e');
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final IapBillingCoordinator coordinator = IapBillingCoordinator.instance;
    coordinator.setEntitlementsRefreshHandler(
      () => refreshSubscriptionEntitlements(ref, forceRefresh: true),
    );
    coordinator.addListener(_onIapUi);
    coordinator.addVerifiedHandler(_onPurchaseVerified);
    unawaited(coordinator.refreshStoreCatalog());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || kIsWeb) {
        return;
      }
      unawaited(refreshSubscriptionEntitlements(ref));
      unawaited(
        CreatorIntelligenceAnalyticsService().trackSubscriptionGateSeen(
          feature: 'upgrade_view',
        ),
      );
    });
  }

  @override
  void dispose() {
    final IapBillingCoordinator coordinator = IapBillingCoordinator.instance;
    coordinator.setEntitlementsRefreshHandler(null);
    coordinator.removeListener(_onIapUi);
    coordinator.removeVerifiedHandler(_onPurchaseVerified);
    super.dispose();
  }

  Future<void> _buyProduct(String productId) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _iap.lastRecoverableHint = null;
    });
    final ProductDetails? details = _iap.productsById[productId];
    if (details == null) {
      return;
    }
    await _iap.buySubscription(details);
  }

  Future<void> _pickProProductThenBuy() async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Pro billing period'),
          content: const Text(
            'Choose monthly or yearly Pro. Checkout runs in the '
            'App Store or Google Play app on this device.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(storeProMonthlyId()),
              child: const Text('Monthly'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(storeProYearlyId()),
              child: const Text('Yearly'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (picked != null) {
      await _buyProduct(picked);
    }
  }

  Future<void> _pickStudioProductThenBuy() async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Studio billing period'),
          content: const Text(
            'Choose monthly or yearly Studio. Apple or Google will '
            'run checkout; entitlements unlock after server verification.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(storeStudioMonthlyId()),
              child: const Text('Monthly'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(storeStudioYearlyId()),
              child: const Text('Yearly'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (picked != null) {
      await _buyProduct(picked);
    }
  }

  SubscriptionSnapshot? _readEntitlementsSnapshot() {
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user != null && DebugStudioBypass.grantsStudio(user.uid)) {
      return null;
    }
    return ref.watch(subscriptionSnapshotProvider).valueOrNull ??
        readCachedSubscriptionSnapshot(ref);
  }

  ({String tier, String? status, bool isLoading}) _readTierSnapshot() {
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user != null && DebugStudioBypass.grantsStudio(user.uid)) {
      return (tier: 'studio', status: 'active', isLoading: false);
    }
    final AsyncValue<SubscriptionSnapshot> tierAsync =
        ref.watch(subscriptionSnapshotProvider);
    return tierAsync.when(
      data: (SubscriptionSnapshot snap) => (
        tier: snap.tierApi,
        status: snap.subscriptionStatus,
        isLoading: false,
      ),
      loading: () => (tier: 'starter', status: null, isLoading: true),
      error: (_, __) => (tier: 'starter', status: null, isLoading: false),
    );
  }

  String _tierLabel(String tier) => tierDisplayNameForApi(tier);

  String _subscriptionFootnote({
    required SubscriptionSnapshot? entitlements,
    required bool blockStorePurchase,
    required String storeLabel,
  }) {
    if (blockStorePurchase) {
      return 'You already have an active plan from the website. '
          'Manage billing at streamerstip.com — $storeLabel checkout is '
          'not used for that subscription.';
    }
    if (entitlements != null &&
        entitlements.isPaid &&
        !entitlements.isStarter &&
        entitlements.isPaidViaMobileStore &&
        entitlements.billingSource !=
            (defaultTargetPlatform == TargetPlatform.iOS
                ? SubscriptionBillingSource.apple
                : SubscriptionBillingSource.google)) {
      return 'Your ${entitlements.tierDisplayName} plan is active on this '
          'account (purchased via ${entitlements.billingSourceDisplayLabel}). '
          'This device shows $storeLabel products only; your features unlock '
          'from your StreamersTip account everywhere.';
    }
    return 'Subscriptions on this device use $storeLabel only (not Stripe). '
        'After purchase, StreamersTip verifies your receipt and updates your '
        'account; features unlock on iOS, Android, and the web via your '
        'StreamersTip account.';
  }

  String _statusLabel(String? status) => subscriptionStatusDisplayLabel(status);

  @override
  Widget build(BuildContext context) {
    final ({String tier, String? status, bool isLoading}) tierSnapshot =
        _readTierSnapshot();
    final SubscriptionSnapshot? entitlements = _readEntitlementsSnapshot();
    final String resolvedTier = tierSnapshot.tier;
    final bool isLoadingTier = tierSnapshot.isLoading;
    final bool blockStorePurchase =
        entitlements?.shouldBlockInAppStorePurchase ?? false;
    final ProductDetails? proMonthly =
        _iap.productsById[storeProMonthlyId()];
    final ProductDetails? proYearly =
        _iap.productsById[storeProYearlyId()];
    final ProductDetails? studioMonthly =
        _iap.productsById[storeStudioMonthlyId()];
    final ProductDetails? studioYearly =
        _iap.productsById[storeStudioYearlyId()];
    final String storeLabel = defaultTargetPlatform == TargetPlatform.iOS
        ? 'App Store'
        : 'Google Play';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildCurrentPlanCard(),
              if (entitlements != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildBillingChannelCard(entitlements),
              ],
              const SizedBox(height: 24),
              _buildTierCard(
                context,
                tierKey: 'starter',
                name: 'Creator',
                price: '\$0',
                cadence: '/month',
                description:
                    'A solid free plan for creators getting started with cross-posting and lightweight planning.',
                features: UpgradeTierMarketing.starterBullets,
              ),
              const SizedBox(height: 16),
              _buildTierCard(
                context,
                tierKey: 'pro',
                name: 'Creator Pro',
                price: formatStorePrice(
                  proMonthly,
                  '\$12.99',
                ),
                cadence: storeCadenceLabel(proMonthly) ?? '/month',
                secondaryPrice: proYearly != null
                    ? '${formatStorePrice(proYearly, '\$120')}/year'
                    : '\$120/year',
                description:
                    'For active creators who need more platforms, stronger publishing tools, and deeper growth support.',
                features: UpgradeTierMarketing.proBullets,
                isFeatured: true,
                storePrimaryAction: !isLoadingTier &&
                        !blockStorePurchase &&
                        resolvedTier == 'starter'
                    ? _pickProProductThenBuy
                    : null,
                storePrimaryLabel: 'Subscribe with $storeLabel',
              ),
              const SizedBox(height: 16),
              _buildTierCard(
                context,
                tierKey: 'studio',
                name: 'Creator Studio',
                price: formatStorePrice(
                  studioMonthly,
                  '\$29.99',
                ),
                cadence: storeCadenceLabel(studioMonthly) ?? '/month',
                secondaryPrice: studioYearly != null
                    ? '${formatStorePrice(studioYearly, '\$300')}/year'
                    : '\$300/year',
                description:
                    'For serious teams and power creators who need advanced analytics, automation, and team access.',
                features: UpgradeTierMarketing.studioBullets,
                storePrimaryAction: !isLoadingTier &&
                        !blockStorePurchase &&
                        (resolvedTier == 'starter' || resolvedTier == 'pro')
                    ? _pickStudioProductThenBuy
                    : null,
                storePrimaryLabel: 'Subscribe to Studio',
              ),
              const SizedBox(height: 20),
              Text(
                _subscriptionFootnote(
                  entitlements: entitlements,
                  blockStorePurchase: blockStorePurchase,
                  storeLabel: storeLabel,
                ),
                style: TextStyle(
                  color: _on.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingChannelCard(SubscriptionSnapshot snap) {
    final bool canOpenManage = !snap.shouldBlockInAppStorePurchase &&
        (snap.isPaidViaMobileStore || snap.isPaid);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _on.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _on.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Billing',
            style: TextStyle(
              color: _on.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snap.billingSourceDisplayLabel,
            style: TextStyle(
              color: _on,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _manageService.manageDestinationHint(snap),
            style: TextStyle(
              color: _on.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (canOpenManage) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final bool opened =
                    await _manageService.openManageSubscription(snap);
                if (!mounted) {
                  return;
                }
                if (!opened) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _manageService.manageDestinationHint(snap),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                snap.isPaidViaApple
                    ? 'Open App Store subscriptions'
                    : 'Open Google Play subscriptions',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final ({String tier, String? status, bool isLoading}) tierSnapshot =
        _readTierSnapshot();
    final SubscriptionSnapshot? snap = _readEntitlementsSnapshot();
    final bool isLoadingTier = tierSnapshot.isLoading;
    final String resolvedTier = tierSnapshot.tier;
    final String? subscriptionStatus = tierSnapshot.status;
    final int creditsRemaining = snap?.creditsRemaining ?? 0;
    final int creditsLimit = snap?.creditsLimit ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _on.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _on.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isLoadingTier
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _on,
                    ),
                  )
                : Icon(
                    Icons.verified_rounded,
                    color: _on,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current plan',
                  style: TextStyle(
                    color: _on.withValues(alpha: 0.64),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoadingTier
                      ? 'Checking your subscription...'
                      : '${_tierLabel(resolvedTier)} · ${_statusLabel(subscriptionStatus)}',
                  style: TextStyle(
                    color: _on,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!isLoadingTier && creditsLimit > 0) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '$creditsRemaining of $creditsLimit AI credits this month',
                    style: TextStyle(
                      color: _on.withValues(alpha: 0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: _on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _on.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _on.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _on.withValues(alpha: 0.12),
              ),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back,
                color: _on,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade',
                  style: TextStyle(
                    color: _on,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the tier that fits your creator journey',
                  style: TextStyle(
                    color: _on.withValues(alpha: 0.68),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context, {
    required String tierKey,
    required String name,
    required String price,
    required String cadence,
    required String description,
    required List<String> features,
    String? secondaryPrice,
    bool isFeatured = false,
    VoidCallback? storePrimaryAction,
    String? storePrimaryLabel,
  }) {
    final ({String tier, String? status, bool isLoading}) tierSnapshot =
        _readTierSnapshot();
    final bool isCurrentTier =
        !tierSnapshot.isLoading && tierSnapshot.tier == tierKey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _on.withValues(
          alpha: isCurrentTier ? 0.12 : (isFeatured ? 0.1 : 0.07),
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _on.withValues(
            alpha: isCurrentTier ? 0.26 : (isFeatured ? 0.18 : 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrentTier)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _on.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _on.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          'Current Plan',
                          style: TextStyle(
                            color: _on,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (isFeatured)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.supportAccentGradient,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Most Popular',
                          style: TextStyle(
                            color: _onP,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Text(
                      name,
                      style: TextStyle(
                        color: _on,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: TextStyle(
                              color: _on,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: cadence,
                            style: TextStyle(
                              color: _on.withValues(alpha: 0.68),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (secondaryPrice != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        secondaryPrice,
                        style: TextStyle(
                          color: _on.withValues(alpha: 0.66),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        color: _on.withValues(alpha: 0.74),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _on.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: _on,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _on.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: _on,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: _on.withValues(alpha: 0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentTier
                  ? null
                  : () {
                      if (_iap.purchaseBusy) {
                        return;
                      }
                      if (storePrimaryAction != null) {
                        storePrimaryAction();
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) =>
                              const ContactSupportView(),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFeatured
                    ? AppColors.supportAccent
                    : _on.withValues(alpha: 0.1),
                foregroundColor: isFeatured ? _onP : _on,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _on.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Text(
                isCurrentTier
                    ? 'Current Plan'
                    : (storePrimaryLabel ??
                        (name == 'Creator'
                            ? 'Stay on Creator'
                            : 'Subscribe to $name')),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
