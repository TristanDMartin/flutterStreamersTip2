import 'api_feature_gate.dart';
import 'models/billing_tier.dart';
import 'models/subscription_snapshot.dart';

export 'api_feature_gate.dart' show ApiBillingFeature, hasApiBillingFeature;

/// String-tier helpers for legacy call sites without a snapshot.
bool isBillingTierStarter(String resolvedTier) {
  return billingTierFromApi(resolvedTier) == BillingTier.starter;
}

bool needsProForCrossPostOrScheduling(String resolvedTier) {
  return isBillingTierStarter(resolvedTier);
}

bool needsProForAdvancedAnalytics(String resolvedTier) {
  return billingTierFromApi(resolvedTier) == BillingTier.starter;
}

bool canShowStudioUpsell(String resolvedTier) {
  return resolvedTier.trim().toLowerCase() == 'pro';
}

bool hasBillingFeatureForTierApi(String tierApi, ApiBillingFeature feature) {
  final SubscriptionSnapshot stub = SubscriptionSnapshot(
    tier: billingTierFromApi(tierApi),
    effectiveTier: billingTierFromApi(tierApi),
    storedTier: billingTierFromApi(tierApi),
    subscriptionStatus: 'active',
    isPaid: !isBillingTierStarter(tierApi),
    isStarter: isBillingTierStarter(tierApi),
    isPro: tierApi == 'pro',
    isStudio: tierApi == 'studio',
    isOwnerAccount: false,
    isUnlimited: false,
    creditsUsed: 0,
    creditsLimit: 0,
    creditsRemaining: 0,
    entitlements: ApiEntitlements.fallbackStarter(),
    usage: const UsageSnapshot(
      periodKey: '',
      monthlyCreditsUsed: 0,
      monthlyCreditsRemaining: 0,
    ),
    aiCreditCosts: const AiCreditCosts(costs: <String, int>{}),
  );
  return hasApiBillingFeature(stub, feature);
}
