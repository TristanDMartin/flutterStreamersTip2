import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../features/billing/entitlement_feature_bullets.dart';
import '../../features/billing/iap_billing_coordinator.dart';
import '../../features/billing/iap_billing_facade.dart';
import '../../features/billing/store_product_catalog.dart';
import '../../features/billing/subscription_provider.dart';
import '../../features/gamification/models/subscription_plan.dart';
import 'onboarding_style.dart';

Future<void> showOnboardingPremiumModal(
  BuildContext context, {
  required String userId,
  required OnboardingServiceDismissCallback onDismissed,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    pageBuilder: (
      BuildContext ctx,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return OnboardingPremiumModal(
        userId: userId,
        onDismissed: onDismissed,
      );
    },
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

typedef OnboardingServiceDismissCallback = Future<void> Function();

class OnboardingPremiumModal extends ConsumerStatefulWidget {
  const OnboardingPremiumModal({
    super.key,
    required this.userId,
    required this.onDismissed,
  });

  final String userId;
  final OnboardingServiceDismissCallback onDismissed;

  @override
  ConsumerState<OnboardingPremiumModal> createState() =>
      _OnboardingPremiumModalState();
}

class _OnboardingPremiumModalState extends ConsumerState<OnboardingPremiumModal> {
  bool _isPurchasing = false;
  String? _error;

  IapBillingFacade get _iap => IapBillingCoordinator.instance.facade;

  Future<void> _buyPlan(SubscriptionPlan plan) async {
    if (_isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
      _error = null;
    });
    try {
      await IapBillingCoordinator.instance.refreshStoreCatalog();
      final String productId = storeProductIdForPlanAndPeriod(
        plan: plan,
        isYearly: false,
      );
      final ProductDetails? product = _iap.productsById[productId];
      if (product == null) {
        setState(() {
          _error = 'Trial is not available from the store right now.';
        });
        return;
      }
      await _iap.buySubscription(product);
      invalidateSubscriptionEntitlements(ref);
      if (mounted) {
        Navigator.of(context).pop();
        await widget.onDismissed();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not start trial. Try again from Settings.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _continueFree() async {
    Navigator.of(context).pop();
    await widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> proBullets =
        entitlementFeatureBullets(catalogEntitlementsForTier('pro'));
    final List<String> studioBullets =
        entitlementFeatureBullets(catalogEntitlementsForTier('studio'));
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
            child: DecoratedBox(
              decoration: OnboardingStyle.cardDecoration(context: context),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Unlock Your Creator Growth Trial',
                      style: TextStyle(
                        color: OnboardingStyle.textPrimaryFor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try premium creator tools free for 7 days.',
                      style: TextStyle(
                        color: OnboardingStyle.textSecondaryFor(context),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TierFeatureCard(
                      title: 'Pro',
                      bullets: proBullets,
                      accent: const Color(0xFF4897D2),
                    ),
                    const SizedBox(height: 12),
                    _TierFeatureCard(
                      title: 'Studio',
                      bullets: studioBullets,
                      accent: const Color(0xFF9248D2),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: GradientPillButton(
                        label: _isPurchasing
                            ? 'Starting trial...'
                            : 'Start Pro Trial',
                        onPressed:
                            _isPurchasing ? null : () => _buyPlan(SubscriptionPlan.pro),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isPurchasing
                            ? null
                            : () => _buyPlan(SubscriptionPlan.studio),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              OnboardingStyle.textPrimaryFor(context),
                          side: BorderSide(
                            color: OnboardingStyle.borderFor(context),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Start Studio Trial',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isPurchasing ? null : _continueFree,
                        child: Text(
                          'Continue Free',
                          style: TextStyle(
                            color: OnboardingStyle.textSecondaryFor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TierFeatureCard extends StatelessWidget {
  const _TierFeatureCard({
    required this.title,
    required this.bullets,
    required this.accent,
  });

  final String title;
  final List<String> bullets;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: OnboardingStyle.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...bullets.take(4).map(
                (String bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.check_rounded, color: accent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            color: OnboardingStyle.textSecondaryFor(context),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
