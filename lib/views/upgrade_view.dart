import 'dart:async';
import 'dart:math' as math;

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

/// Route args for [UpgradeView] (Tippy trialIntent auto-start).
class UpgradeRouteArgs {
  const UpgradeRouteArgs({this.autoStartPro = false});

  final bool autoStartPro;
}

/// Duolingo-inspired subscription surface for StreamersTip tiers.
class UpgradeView extends ConsumerStatefulWidget {
  const UpgradeView({
    super.key,
    this.autoStartPro = false,
  });

  /// When true (Tippy trialIntent), open Pro period picker after catalog load.
  final bool autoStartPro;

  @override
  ConsumerState<UpgradeView> createState() => _UpgradeViewState();
}

class _UpgradeViewState extends ConsumerState<UpgradeView> {
  static const Color _pageBg = Color(0xFF0B1220);
  static const Color _cardBg = Color(0xFF131B2B);
  static const Color _cardBorder = Color(0xFF2A3548);
  static const Color _checkBlue = Color(0xFF49C0F8);
  static const Color _ctaBlue = Color(0xFF49C0F8);
  static const Color _muted = Color(0xFF9AA6B8);

  Color get _on => Colors.white;

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
      if (widget.autoStartPro) {
        unawaited(_autoStartProTrialCheckout());
      }
    });
  }

  Future<void> _autoStartProTrialCheckout() async {
    final IapBillingCoordinator coordinator = IapBillingCoordinator.instance;
    if (_iap.productsById.isEmpty) {
      await coordinator.refreshStoreCatalog();
    }
    if (!mounted) {
      return;
    }
    await _pickProProductThenBuy();
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
          backgroundColor: _cardBg,
          title: Text(
            'Choose your Pro plan',
            style: TextStyle(color: _on, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Start with monthly to build trust — or save with yearly. '
            'Checkout runs in the App Store or Google Play on this device.',
            style: TextStyle(color: _on.withValues(alpha: 0.78)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(storeProMonthlyId()),
              child: const Text(
                'Monthly · \$12.99',
                style: TextStyle(color: _ctaBlue),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(storeProYearlyId()),
              child: Text(
                'Yearly · \$120',
                style: TextStyle(color: _on.withValues(alpha: 0.85)),
              ),
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
          backgroundColor: _cardBg,
          title: Text(
            'Studio billing period',
            style: TextStyle(color: _on, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Choose monthly or yearly Studio. Apple or Google will '
            'run checkout; entitlements unlock after server verification.',
            style: TextStyle(color: _on.withValues(alpha: 0.78)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(storeStudioMonthlyId()),
              child: const Text('Monthly', style: TextStyle(color: _ctaBlue)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(storeStudioYearlyId()),
              child: const Text('Yearly', style: TextStyle(color: _ctaBlue)),
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

  String _tryCtaLabel(ProductDetails? monthly, String fallbackPrice) {
    final String price = formatStorePrice(monthly, fallbackPrice);
    return 'TRY FOR $price';
  }

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
      backgroundColor: _pageBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF1A1035),
              Color(0xFF0B1220),
              Color(0xFF080D16),
            ],
            stops: <double>[0.0, 0.28, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _buildTopBar(context)),
              SliverToBoxAdapter(child: _buildHero()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      _buildCurrentPlanChip(),
                      if (entitlements != null &&
                          _isGraceOrPastDue(entitlements)) ...<Widget>[
                        const SizedBox(height: 12),
                        _buildGracePeriodBanner(entitlements),
                      ],
                      if (_iap.lastError != null &&
                          _iap.lastError!.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        _buildInlineAlert(_iap.lastError!, isError: true),
                      ] else if (_iap.lastRecoverableHint != null &&
                          _iap.lastRecoverableHint!
                              .trim()
                              .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        _buildInlineAlert(_iap.lastRecoverableHint!),
                      ],
                      const SizedBox(height: 18),
                      _buildPlanCard(
                        tierKey: 'pro',
                        title: 'Creator Pro',
                        subtitle: formatStorePrice(proMonthly, '\$12.99') +
                            (storeCadenceLabel(proMonthly) ?? '/month'),
                        secondaryPrice: proYearly != null
                            ? '${formatStorePrice(proYearly, '\$120')}/year'
                            : '\$120/year',
                        features: UpgradeTierMarketing.proBullets,
                        illustration: Icons.auto_awesome_rounded,
                        isRecommended: true,
                        isCurrent: !isLoadingTier && resolvedTier == 'pro',
                        ctaLabel: _tryCtaLabel(proMonthly, '\$12.99'),
                        onCta: !isLoadingTier &&
                                !blockStorePurchase &&
                                resolvedTier == 'starter'
                            ? _pickProProductThenBuy
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildPlanCard(
                        tierKey: 'studio',
                        title: 'Creator Studio',
                        subtitle: formatStorePrice(studioMonthly, '\$29.99') +
                            (storeCadenceLabel(studioMonthly) ?? '/month'),
                        secondaryPrice: studioYearly != null
                            ? '${formatStorePrice(studioYearly, '\$300')}/year'
                            : '\$300/year',
                        features: UpgradeTierMarketing.studioBullets,
                        illustration: Icons.workspace_premium_rounded,
                        isCurrent: !isLoadingTier && resolvedTier == 'studio',
                        ctaLabel: _tryCtaLabel(studioMonthly, '\$29.99'),
                        onCta: !isLoadingTier &&
                                !blockStorePurchase &&
                                (resolvedTier == 'starter' ||
                                    resolvedTier == 'pro')
                            ? _pickStudioProductThenBuy
                            : null,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'MORE OPTIONS',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPlanCard(
                        tierKey: 'starter',
                        title: 'Creator (free)',
                        subtitle: 'Get started with cross-posting basics',
                        features: UpgradeTierMarketing.starterBullets,
                        illustration: Icons.bolt_rounded,
                        isCurrent:
                            !isLoadingTier && resolvedTier == 'starter',
                        ctaLabel: 'STAY ON CREATOR',
                        onCta: null,
                        forceDisabledCta: true,
                      ),
                      if (entitlements != null) ...<Widget>[
                        const SizedBox(height: 14),
                        _buildBillingChannelCard(entitlements),
                      ],
                      const SizedBox(height: 16),
                      _buildRestorePurchasesRow(),
                      const SizedBox(height: 18),
                      Text(
                        _subscriptionFootnote(
                          entitlements: entitlements,
                          blockStorePurchase: blockStorePurchase,
                          storeLabel: storeLabel,
                        ),
                        style: TextStyle(
                          color: _on.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 18, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_rounded, color: _on, size: 24),
          ),
          Expanded(
            child: Text(
              'Subscription',
              style: TextStyle(
                color: _on,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Column(
        children: <Widget>[
          const Text(
            'COMPARE PLANS',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ...List<Widget>.generate(6, (int i) {
                  final double angle = (i / 6) * math.pi * 2;
                  return Transform.translate(
                    offset: Offset(
                      math.cos(angle) * 58,
                      math.sin(angle) * 42,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: i.isEven ? 14 : 10,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  );
                }),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF66FCF1),
                        Color(0xFF7768DF),
                        Color(0xFF9248D2),
                        Color(0xFFFF6BCB),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const Icon(
                        Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 48,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanChip() {
    final ({String tier, String? status, bool isLoading}) tierSnapshot =
        _readTierSnapshot();
    final SubscriptionSnapshot? snap = _readEntitlementsSnapshot();
    final int creditsRemaining = snap?.creditsRemaining ?? 0;
    final int creditsLimit = snap?.creditsLimit ?? 0;
    final String label = tierSnapshot.isLoading
        ? 'Checking plan…'
        : 'Current · ${_tierLabel(tierSnapshot.tier)} · '
            '${_statusLabel(tierSnapshot.status)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (tierSnapshot.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _ctaBlue,
                  ),
                )
              else
                const Icon(Icons.verified_rounded, color: _ctaBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _on,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (!tierSnapshot.isLoading && creditsLimit > 0) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '$creditsRemaining of $creditsLimit AI credits this month',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineAlert(String message, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isError ? Colors.red : Colors.orange).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? Colors.red.shade200 : _on.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isGraceOrPastDue(SubscriptionSnapshot snap) {
    final String status = snap.subscriptionStatus.trim().toLowerCase();
    return status == 'grace_period' || status == 'past_due';
  }

  Widget _buildGracePeriodBanner(SubscriptionSnapshot snap) {
    final bool isGrace =
        snap.subscriptionStatus.trim().toLowerCase() == 'grace_period';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isGrace ? 'Billing grace period' : 'Payment past due',
            style: TextStyle(
              color: _on,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isGrace
                ? 'Your ${snap.tierDisplayName} benefits stay active while '
                    'the store retries payment. Update your payment method '
                    'in ${_manageService.manageDestinationHint(snap)}'
                : 'Update payment in the store to keep ${snap.tierDisplayName}. '
                    '${_manageService.manageDestinationHint(snap)}',
            style: TextStyle(
              color: _on.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String tierKey,
    required String title,
    required String subtitle,
    required List<String> features,
    required IconData illustration,
    required String ctaLabel,
    String? secondaryPrice,
    bool isRecommended = false,
    bool isCurrent = false,
    bool forceDisabledCta = false,
    VoidCallback? onCta,
  }) {
    final bool ctaEnabled =
        !forceDisabledCta && !isCurrent && onCta != null && !_iap.purchaseBusy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended
              ? AppColors.primary.withValues(alpha: 0.55)
              : _cardBorder,
          width: isRecommended ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF7B3FE4),
                    Color(0xFF2BB8C8),
                  ],
                ),
              ),
              child: const Text(
                'RECOMMENDED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (isCurrent) ...<Widget>[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _checkBlue.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _checkBlue.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Text(
                                'CURRENT PLAN',
                                style: TextStyle(
                                  color: _checkBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                          Text(
                            title,
                            style: TextStyle(
                              color: _on,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: _on.withValues(alpha: 0.72),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (secondaryPrice != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              secondaryPrice,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isRecommended
                              ? const <Color>[
                                  Color(0xFF66FCF1),
                                  Color(0xFF9248D2),
                                ]
                              : const <Color>[
                                  Color(0xFF2A3548),
                                  Color(0xFF1A2233),
                                ],
                        ),
                      ),
                      child: Icon(
                        illustration,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...features.map(
                  (String feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.check_rounded,
                            color: _checkBlue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: _on.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                    child: OutlinedButton(
                    onPressed: ctaEnabled
                        ? onCta
                        : (isCurrent || forceDisabledCta
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext ctx) =>
                                        const ContactSupportView(),
                                  ),
                                );
                              }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ctaBlue,
                      side: BorderSide(
                        color: _on.withValues(alpha: 0.22),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                    child: Text(
                      isCurrent ? 'CURRENT PLAN' : ctaLabel,
                      style: TextStyle(
                        color: ctaEnabled || isCurrent || forceDisabledCta
                            ? _ctaBlue
                            : _ctaBlue.withValues(alpha: 0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        decoration: TextDecoration.underline,
                        decorationColor: _ctaBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestorePurchasesRow() {
    final bool busy = _iap.purchaseBusy;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: busy || kIsWeb
            ? null
            : () {
                unawaited(_restorePurchases());
              },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _on.withValues(alpha: 0.18), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _ctaBlue,
                ),
              )
            : const Text(
                'RESTORE PURCHASES',
                style: TextStyle(
                  color: _ctaBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  decoration: TextDecoration.underline,
                  decorationColor: _ctaBlue,
                ),
              ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _iap.lastError = null;
    });
    await _iap.restorePurchases();
    if (!mounted) {
      return;
    }
    invalidateSubscriptionEntitlements(ref);
    try {
      await refreshSubscriptionEntitlements(ref, forceRefresh: true);
    } catch (e) {
      debugPrint('UpgradeView: restore entitlements refresh failed: $e');
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildBillingChannelCard(SubscriptionSnapshot snap) {
    final bool canOpenManage = !snap.shouldBlockInAppStorePurchase &&
        (snap.isPaidViaMobileStore || snap.isPaid);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'BILLING',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
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
                style: const TextStyle(
                  color: _ctaBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
