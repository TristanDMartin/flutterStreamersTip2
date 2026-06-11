import '../gamification/models/subscription_plan.dart';
import 'models/subscription_snapshot.dart';

/// Limits view built from API [ApiEntitlements] — not a local tier table.
class BillingTierLimits {
  const BillingTierLimits({
    required this.connectedPlatforms,
    required this.contentPlans,
    required this.schedulingEnabled,
    required this.analyticsWindowDays,
    required this.aiCreditsPerMonth,
    required this.teamMembers,
    required this.crossPostWeeklyLimit,
  });

  final int connectedPlatforms;
  final int contentPlans;
  final bool schedulingEnabled;
  final int analyticsWindowDays;
  final int aiCreditsPerMonth;
  final int teamMembers;
  final int crossPostWeeklyLimit;

  factory BillingTierLimits.fromApiEntitlements(ApiEntitlements e) {
    return BillingTierLimits(
      connectedPlatforms: e.maxPlatforms,
      contentPlans: e.contentPlansLimit,
      schedulingEnabled: true,
      analyticsWindowDays: e.analyticsWindowDays,
      aiCreditsPerMonth: e.monthlyAiCredits,
      teamMembers: e.teamMembersLimit,
      crossPostWeeklyLimit: e.crossPostWeeklyLimit,
    );
  }

  static BillingTierLimits get starter =>
      BillingTierLimits.fromApiEntitlements(ApiEntitlements.fallbackStarter());

  static bool isUnlimited(int value) => value < 0;

  static BillingTierLimits forEffectivePlan(SubscriptionPlan plan) {
    return starter;
  }
}
