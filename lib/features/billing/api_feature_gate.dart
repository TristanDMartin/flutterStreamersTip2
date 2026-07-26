import 'entitlement_sentinel.dart';
import 'models/subscription_snapshot.dart';

/// Feature authorization from API [ApiEntitlements] — never hardcode tier limits.
bool hasApiBillingFeature(
  SubscriptionSnapshot snapshot,
  ApiBillingFeature feature,
) {
  if (snapshot.hasFullAccess) {
    return true;
  }
  final ApiEntitlements e = snapshot.entitlements;
  switch (feature) {
    case ApiBillingFeature.bulkPublish:
      return e.canBulkPublish;
    case ApiBillingFeature.advancedAnalytics:
      return e.canUseAdvancedAnalytics;
    case ApiBillingFeature.aiCaptionRewrite:
      return e.canUseAICaptionRewrite;
    case ApiBillingFeature.growthReports:
      return e.canUseGrowthReports;
    case ApiBillingFeature.teamMembers:
      return e.canUseTeamMembers;
    case ApiBillingFeature.automation:
      return e.canUseAutomation;
    case ApiBillingFeature.exportAnalytics:
      return e.canExportAnalytics;
    case ApiBillingFeature.contentPlanner:
      return e.canUseContentPlanner;
    case ApiBillingFeature.crossPost:
      return e.canCrossPost;
    case ApiBillingFeature.scheduling:
      return true;
  }
}

enum ApiBillingFeature {
  bulkPublish,
  advancedAnalytics,
  aiCaptionRewrite,
  growthReports,
  teamMembers,
  automation,
  exportAnalytics,
  contentPlanner,
  crossPost,
  scheduling,
}

bool needsProForCrossPostOrSchedulingApi(SubscriptionSnapshot snapshot) {
  if (snapshot.hasFullAccess) {
    return false;
  }
  return !snapshot.isPaid || snapshot.isStarter;
}

bool needsProForAdvancedAnalyticsApi(SubscriptionSnapshot snapshot) {
  return !hasApiBillingFeature(snapshot, ApiBillingFeature.advancedAnalytics);
}

int maxPlatformsFromSnapshot(SubscriptionSnapshot snapshot) {
  return snapshot.entitlements.effectiveMaxPlatforms();
}

bool isContentPlansUnlimited(SubscriptionSnapshot snapshot) {
  return isEntitlementUnlimited(snapshot.entitlements.contentPlansLimit);
}

bool canCreateContentPlan(
  SubscriptionSnapshot snapshot,
  int existingPlanCount,
) {
  if (snapshot.hasFullAccess) {
    return true;
  }
  final int limit = snapshot.entitlements.contentPlansLimit;
  if (isEntitlementUnlimited(limit)) {
    return true;
  }
  if (limit < 1) {
    return true;
  }
  return existingPlanCount < limit;
}

int aiCreditCostFromSnapshot(
  SubscriptionSnapshot snapshot,
  String action, {
  int fallback = 1,
}) {
  return snapshot.aiCreditCosts.costFor(action, fallback: fallback);
}

bool canAffordAiAction(SubscriptionSnapshot snapshot, String action) {
  final int cost = aiCreditCostFromSnapshot(snapshot, action);
  final int remaining = snapshot.usage.monthlyCreditsRemaining > 0
      ? snapshot.usage.monthlyCreditsRemaining
      : snapshot.creditsRemaining;
  return remaining >= cost;
}

bool canUploadFromSnapshot(
  SubscriptionSnapshot snapshot, {
  required int uploadsThisMonth,
}) {
  if (snapshot.hasFullAccess) {
    return true;
  }
  return canUploadVideo(
    videoUploadsPerMonth: snapshot.entitlements.videoUploadsPerMonth,
    uploadsThisMonth: uploadsThisMonth,
  );
}
