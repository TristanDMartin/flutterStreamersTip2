import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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
  return showOnboardingPremiumSheet(
    context,
    userId: userId,
    onDismissed: onDismissed,
  );
}

Future<void> showOnboardingPremiumSheet(
  BuildContext context, {
  required String userId,
  required OnboardingServiceDismissCallback onDismissed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (
          BuildContext context,
          ScrollController scrollController,
        ) {
          return OnboardingPremiumModal(
            userId: userId,
            scrollController: scrollController,
            onDismissed: onDismissed,
          );
        },
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
    this.scrollController,
  });

  final String userId;
  final OnboardingServiceDismissCallback onDismissed;
  final ScrollController? scrollController;

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

  static const List<({String icon, String label})> _perkRows =
      <({String icon, String label})>[
    (icon: '⚡', label: '2x XP on missions'),
    (icon: '🤖', label: 'Tippy Pro coaching'),
    (icon: '📊', label: 'Advanced analytics'),
    (icon: '💸', label: 'Lower tip fees'),
  ];

  @override
  Widget build(BuildContext context) {
    final ScrollController? scrollController = widget.scrollController;
    return Material(
      color: OnboardingStyle.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: OnboardingStyle.borderFor(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                'You\'re on a roll 🔥',
                style: TextStyle(
                  color: OnboardingStyle.textPrimaryFor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You earned XP from your first mission. Premium unlocks '
                'faster growth tools.',
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              ..._perkRows.map((({String icon, String label}) row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Text(row.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.label,
                          style: TextStyle(
                            color: OnboardingStyle.textPrimaryFor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
                      : 'Upgrade to Premium',
                  onPressed:
                      _isPurchasing ? null : () => _buyPlan(SubscriptionPlan.pro),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isPurchasing ? null : _continueFree,
                  child: Text(
                    'Maybe later',
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
    );
  }
}
