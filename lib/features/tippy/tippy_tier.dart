import '../billing/models/billing_tier.dart';
import '../billing/models/subscription_snapshot.dart';
import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';
import 'tippy_identity.dart';

export 'tippy_identity.dart'
    show
        TippyFeatureTier,
        TippyIdentity,
        buildTippyCreatorContextBlock,
        buildTippySystemPrompt;

TippyFeatureTier resolveTippyFeatureTierFromSnapshot(
  SubscriptionSnapshot snapshot,
) {
  switch (snapshot.effectiveTier) {
    case BillingTier.studio:
      return TippyFeatureTier.studio;
    case BillingTier.pro:
      return TippyFeatureTier.pro;
    case BillingTier.starter:
      return TippyFeatureTier.starter;
  }
}

TippyFeatureTier resolveTippyFeatureTier(UserProgressBundle bundle) {
  final SubscriptionPlan plan =
      bundle.subscription?.plan ?? SubscriptionPlan.unknown;
  switch (plan) {
    case SubscriptionPlan.studio:
      return TippyFeatureTier.studio;
    case SubscriptionPlan.pro:
      return TippyFeatureTier.pro;
    case SubscriptionPlan.starter:
    case SubscriptionPlan.unknown:
      return TippyFeatureTier.starter;
  }
}
