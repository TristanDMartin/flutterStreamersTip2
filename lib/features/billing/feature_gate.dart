import 'api_feature_gate.dart';
import 'models/subscription_snapshot.dart';

export 'api_feature_gate.dart'
    show
        ApiBillingFeature,
        aiCreditCostFromSnapshot,
        canAffordAiAction,
        hasApiBillingFeature,
        isContentPlansUnlimited,
        maxPlatformsFromSnapshot,
        needsProForAdvancedAnalyticsApi,
        needsProForCrossPostOrSchedulingApi;

/// Prefer [hasApiBillingFeature] with [SubscriptionSnapshot] from the API.
@Deprecated('Use hasApiBillingFeature with SubscriptionSnapshot')
bool hasBillingFeature(
  SubscriptionSnapshot snapshot,
  ApiBillingFeature feature,
) {
  return hasApiBillingFeature(snapshot, feature);
}

@Deprecated('Use hasApiBillingFeature')
bool requireBillingFeature(
  SubscriptionSnapshot snapshot,
  ApiBillingFeature feature,
) {
  return hasApiBillingFeature(snapshot, feature);
}

bool needsProForCrossPostOrScheduling(SubscriptionSnapshot snapshot) {
  return needsProForCrossPostOrSchedulingApi(snapshot);
}

bool needsProForAdvancedAnalytics(SubscriptionSnapshot snapshot) {
  return needsProForAdvancedAnalyticsApi(snapshot);
}

bool canShowStudioUpsell(SubscriptionSnapshot snapshot) {
  return snapshot.isPro && !snapshot.isStudio;
}

bool isBillingTierStarter(SubscriptionSnapshot snapshot) {
  return snapshot.isStarter && !snapshot.hasFullAccess;
}
