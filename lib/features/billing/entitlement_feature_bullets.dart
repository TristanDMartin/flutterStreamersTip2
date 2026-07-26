import 'billing_tier_limits.dart';
import 'entitlement_sentinel.dart';
import 'models/subscription_snapshot.dart';

/// Builds human-readable feature bullets from API entitlements (not hardcoded tiers).
List<String> entitlementFeatureBullets(ApiEntitlements entitlements) {
  final BillingTierLimits limits =
      BillingTierLimits.fromApiEntitlements(entitlements);
  final List<String> bullets = <String>[];
  bullets.add('Unlimited content uploads');
  if (BillingTierLimits.isUnlimited(limits.connectedPlatforms)) {
    bullets.add('Unlimited connected platforms');
  } else if (limits.connectedPlatforms > 1) {
    bullets.add('${limits.connectedPlatforms} connected platforms');
  }
  if (BillingTierLimits.isUnlimited(limits.contentPlans)) {
    bullets.add('Unlimited content plans');
  } else if (limits.contentPlans >= 1) {
    bullets.add(
      limits.contentPlans == 1
          ? '1 active content plan'
          : '${limits.contentPlans} active content plans',
    );
  }
  if (entitlements.canCrossPost) {
    if (BillingTierLimits.isUnlimited(limits.crossPostWeeklyLimit)) {
      bullets.add('Unlimited weekly cross-posting');
    } else if (limits.crossPostWeeklyLimit > 0) {
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
  } else {
    bullets.add('${limits.analyticsWindowDays}-day analytics');
  }
  if (limits.aiCreditsPerMonth > 0) {
    bullets.add('${limits.aiCreditsPerMonth} monthly AI credits');
  }
  if (entitlements.canUseAICaptionRewrite) {
    bullets.add('Caption rewrite and hashtags');
  }
  if (entitlements.canUseGrowthReports) {
    bullets.add('Full weekly growth reports');
  } else {
    bullets.add('Basic weekly recap');
  }
  if (entitlements.canUseAdvancedAnalytics) {
    bullets.add('Advanced analytics');
  }
  if (entitlements.canUseTeamMembers) {
    bullets.add(
      limits.teamMembers > 0
          ? 'Up to ${limits.teamMembers} team members'
          : 'Team member access',
    );
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

/// Catalog mirror of website `lib/billing/entitlements.ts` for upgrade UI only.
/// Runtime gates must still use live `/api/user/entitlements`.
ApiEntitlements catalogEntitlementsForTier(String tierApi) {
  switch (tierApi) {
    case 'studio':
      return const ApiEntitlements(
        maxPlatforms: kEntitlementUnlimited,
        monthlyAiCredits: 2500,
        contentPlansLimit: kEntitlementUnlimited,
        analyticsWindowDays: 365,
        crossPostWeeklyLimit: kEntitlementUnlimited,
        videoUploadsPerMonth: kEntitlementUnlimited,
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
        maxPlatforms: 5,
        monthlyAiCredits: 500,
        contentPlansLimit: kEntitlementUnlimited,
        analyticsWindowDays: 90,
        crossPostWeeklyLimit: kEntitlementUnlimited,
        videoUploadsPerMonth: kEntitlementUnlimited,
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
