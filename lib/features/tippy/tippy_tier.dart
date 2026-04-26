import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';

enum TippyFeatureTier { starter, pro, studio }

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

String buildTippySystemPrompt({
  required TippyFeatureTier tier,
  required String displayName,
}) {
  final String tierLine = switch (tier) {
    TippyFeatureTier.studio =>
      'This user has Studio. Give full-depth strategy, calendars, '
          'multi-step plans, and advanced creative direction.',
    TippyFeatureTier.pro =>
      'This user has Pro. Give strong, actionable guidance with '
          'clear priorities; keep answers focused but thorough.',
    TippyFeatureTier.starter =>
      'This user has Starter access to Tippy. Be helpful and concise; '
          'suggest upgrades only when a paid feature would clearly help.',
  };
  return 'You are Tippy, the StreamersTip AI coach for live streamers '
      'and gaming creators. You help with content ideas, schedules, '
      'hooks, titles, short-form scripts, community growth, and '
      'gaming-adjacent questions (games, meta, events, collabs). '
      'Stay practical and creator-first. Prefer short paragraphs and '
      'bullet lists when useful.\n'
      'Creator display name: $displayName.\n'
      '$tierLine';
}
