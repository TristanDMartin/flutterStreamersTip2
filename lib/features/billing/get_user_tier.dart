import '../gamification/gamification_firestore_utils.dart';
import '../gamification/models/subscription_plan.dart';

/// Canonical billing tier from Firestore — mirrors website `getUserTier`.
///
/// Reads root `subscriptionTier` + `subscriptionStatus`.
/// Effective paid tier only when [subscriptionStatus] is `active` or `trialing`;
/// otherwise behaves as [SubscriptionPlan.starter].
class BillingTierAccess {
  const BillingTierAccess({
    required this.effectivePlan,
    required this.usedCanonicalFields,
    this.rawSubscriptionTier,
    this.subscriptionStatusForDisplay,
    this.isProTrialing = false,
    this.subscriptionTrialEndAt,
  });

  /// True when root `subscriptionTier` was present and valid (`starter`|`pro`|`studio`).
  final bool usedCanonicalFields;

  /// Tier for limits / gating when [usedCanonicalFields]; else [SubscriptionPlan.unknown].
  final SubscriptionPlan effectivePlan;

  final String? rawSubscriptionTier;
  final String? subscriptionStatusForDisplay;

  /// Pro subscription in Stripe trial (`tier == pro` && `status == trialing`).
  final bool isProTrialing;

  final DateTime? subscriptionTrialEndAt;

  /// No usable canonical `subscriptionTier` at root — fall back to legacy field merge.
  factory BillingTierAccess.fallbackLegacy() {
    return const BillingTierAccess(
      effectivePlan: SubscriptionPlan.unknown,
      usedCanonicalFields: false,
    );
  }

  factory BillingTierAccess.fromUserDocument(Map<String, dynamic> raw) {
    final String? rootTier = raw['subscriptionTier'] as String?;
    if (rootTier == null || rootTier.trim().isEmpty) {
      return BillingTierAccess.fallbackLegacy();
    }
    final String tl = rootTier.trim().toLowerCase();
    const Set<String> valid = <String>{'starter', 'pro', 'studio'};
    if (!valid.contains(tl)) {
      return BillingTierAccess.fallbackLegacy();
    }
    final String? rootStatus = raw['subscriptionStatus'] as String?;
    final String sl = (rootStatus ?? '').trim().toLowerCase();
    const Set<String> paidStatuses = <String>{
      'active',
      'trialing',
      'grace_period',
    };
    final SubscriptionPlan effective = paidStatuses.contains(sl)
        ? subscriptionPlanFromString(tl)
        : SubscriptionPlan.starter;
    final DateTime? trialEnd = readFirestoreDate(raw['subscriptionTrialEndAt']);
    return BillingTierAccess(
      effectivePlan: effective,
      usedCanonicalFields: true,
      rawSubscriptionTier: rootTier.trim(),
      subscriptionStatusForDisplay: rootStatus,
      isProTrialing: tl == 'pro' && sl == 'trialing',
      subscriptionTrialEndAt: trialEnd,
    );
  }
}
