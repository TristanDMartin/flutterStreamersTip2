import 'billing_tier_limits.dart';
import 'models/subscription_snapshot.dart';

/// Builds human-readable feature bullets from API entitlements (not hardcoded tiers).
List<String> entitlementFeatureBullets(ApiEntitlements entitlements) {
  final BillingTierLimits limits =
      BillingTierLimits.fromApiEntitlements(entitlements);
  final List<String> bullets = <String>[];
  if (BillingTierLimits.isUnlimited(limits.connectedPlatforms)) {
    bullets.add('Unlimited connected platforms');
  } else if (limits.connectedPlatforms > 1) {
    bullets.add('${limits.connectedPlatforms} connected platforms');
  }
  if (BillingTierLimits.isUnlimited(limits.contentPlans)) {
    bullets.add('Unlimited content plans');
  } else if (limits.contentPlans > 1) {
    bullets.add('${limits.contentPlans} active content plans');
  }
  if (entitlements.canCrossPost) {
    if (BillingTierLimits.isUnlimited(limits.crossPostWeeklyLimit)) {
      bullets.add('Unlimited weekly cross-posting');
    } else {
      bullets.add('${limits.crossPostWeeklyLimit}x weekly cross-posting');
    }
  }
  if (entitlements.canBulkPublish) {
    bullets.add('Scheduled and bulk publishing');
  }
  if (limits.analyticsWindowDays >= 365) {
    bullets.add('Full-year analytics history');
  } else if (limits.analyticsWindowDays > 7) {
    bullets.add('${limits.analyticsWindowDays}-day analytics history');
  }
  if (limits.aiCreditsPerMonth > 0) {
    bullets.add('${limits.aiCreditsPerMonth} monthly AI credits');
  }
  if (entitlements.canUseAICaptionRewrite) {
    bullets.add('Caption rewrite and hashtags');
  }
  if (entitlements.canUseGrowthReports) {
    bullets.add('Growth reports');
  }
  if (entitlements.canUseAdvancedAnalytics) {
    bullets.add('Advanced analytics');
  }
  if (entitlements.canUseTeamMembers) {
    bullets.add('Team member access');
  }
  if (entitlements.canUseAutomation) {
    bullets.add('Publishing automation');
  }
  if (entitlements.canExportAnalytics) {
    bullets.add('Exportable analytics reports');
  }
  if (entitlements.canUseContentPlanner) {
    bullets.add('Content planner');
  }
  return bullets;
}

ApiEntitlements catalogEntitlementsForTier(String tierApi) {
  switch (tierApi) {
    case 'studio':
      return const ApiEntitlements(
        maxPlatforms: -1,
        monthlyAiCredits: 500,
        contentPlansLimit: -1,
        analyticsWindowDays: 365,
        crossPostWeeklyLimit: -1,
        videoUploadsPerMonth: 0,
        teamMembersLimit: 5,
        canCrossPost: true,
        canBulkPublish: true,
        canUseAdvancedAnalytics: true,
        canUseAICaptionRewrite: true,
        canUseGrowthReports: true,
        canUseTeamMembers: true,
        canUseAutomation: true,
        canExportAnalytics: true,
        canUseContentPlanner: true,
      );
    case 'pro':
      return const ApiEntitlements(
        maxPlatforms: 3,
        monthlyAiCredits: 150,
        contentPlansLimit: -1,
        analyticsWindowDays: 90,
        crossPostWeeklyLimit: -1,
        videoUploadsPerMonth: 0,
        teamMembersLimit: 0,
        canCrossPost: true,
        canBulkPublish: true,
        canUseAdvancedAnalytics: false,
        canUseAICaptionRewrite: true,
        canUseGrowthReports: true,
        canUseTeamMembers: false,
        canUseAutomation: false,
        canExportAnalytics: false,
        canUseContentPlanner: true,
      );
    default:
      return ApiEntitlements.fallbackStarter();
  }
}
