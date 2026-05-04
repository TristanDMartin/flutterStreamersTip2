import '../gamification/models/subscription_plan.dart';

/// Mirrors website `BILLING_TIERS` / `lib/billing/plans.ts`.
/// Use [-1] as unlimited in UI logic.
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

  static const BillingTierLimits starter = BillingTierLimits(
    connectedPlatforms: 1,
    contentPlans: 1,
    schedulingEnabled: true,
    analyticsWindowDays: 7,
    aiCreditsPerMonth: 10,
    teamMembers: 0,
    crossPostWeeklyLimit: 1,
  );

  static const BillingTierLimits pro = BillingTierLimits(
    connectedPlatforms: 5,
    contentPlans: -1,
    schedulingEnabled: true,
    analyticsWindowDays: 90,
    aiCreditsPerMonth: 250,
    teamMembers: 0,
    crossPostWeeklyLimit: -1,
  );

  static const BillingTierLimits studio = BillingTierLimits(
    connectedPlatforms: -1,
    contentPlans: -1,
    schedulingEnabled: true,
    analyticsWindowDays: 365,
    aiCreditsPerMonth: 1000,
    teamMembers: 5,
    crossPostWeeklyLimit: -1,
  );

  static bool isUnlimited(int value) => value < 0;

  static BillingTierLimits forEffectivePlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
        return BillingTierLimits.starter;
      case SubscriptionPlan.pro:
        return BillingTierLimits.pro;
      case SubscriptionPlan.studio:
        return BillingTierLimits.studio;
      case SubscriptionPlan.unknown:
        return BillingTierLimits.starter;
    }
  }
}
