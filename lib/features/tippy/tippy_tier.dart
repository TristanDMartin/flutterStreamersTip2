import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';
import 'tippy_identity.dart';

export 'tippy_identity.dart'
    show
        TippyFeatureTier,
        TippyIdentity,
        buildTippyCreatorContextBlock,
        buildTippySystemPrompt;

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

String openAiModelForTier(TippyFeatureTier tier) {
  switch (tier) {
    case TippyFeatureTier.studio:
      return 'gpt-4o';
    case TippyFeatureTier.pro:
      return 'gpt-4o-mini';
    case TippyFeatureTier.starter:
      return 'gpt-4o-mini';
  }
}

int maxReplyTokensForTier(TippyFeatureTier tier) {
  switch (tier) {
    case TippyFeatureTier.studio:
      return 2048;
    case TippyFeatureTier.pro:
      return 1536;
    case TippyFeatureTier.starter:
      return 1024;
  }
}
