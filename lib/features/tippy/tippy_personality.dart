import '../gamification/models/user_progress_bundle.dart';
import 'tippy_identity.dart';
import 'tippy_tier.dart' show resolveTippyFeatureTier;

/// Tier-aware Tippy UI copy — constants live in [TippyIdentity].
class TippyPersonality {
  TippyPersonality._();

  static String get tagline => TippyIdentity.tagline;

  static String get oneLiner => TippyIdentity.tippyOneLiner;

  static List<String> get introCapabilities =>
      TippyIdentity.tippyIntroCapabilities;

  static List<String> quickPromptsForTier(TippyFeatureTier tier) {
    switch (tier) {
      case TippyFeatureTier.studio:
        return const <String>[
          'Audit my stream setup (OBS, bitrate, audio)',
          'What should I post after my next stream?',
          'Turn this into a content plan in my planner',
          'How can I improve hooks on my last clips?',
        ];
      case TippyFeatureTier.pro:
        return const <String>[
          'Suggest captions and hashtags for my next clip',
          'What should I post today to keep my streak?',
          'Turn this conversation into a content plan',
          'How do I grow engagement this week?',
        ];
      case TippyFeatureTier.starter:
        return const <String>[
          'What should I post today?',
          'Give me 5 short-form hook ideas',
          'How do I write a better caption?',
          'Tips to stay consistent this week',
        ];
    }
  }

  static List<String> quickPromptsForBundle(UserProgressBundle bundle) {
    return quickPromptsForTier(resolveTippyFeatureTier(bundle));
  }

  static String welcomeSubtitle(TippyFeatureTier tier) {
    switch (tier) {
      case TippyFeatureTier.studio:
        return 'Full creator-OS coaching — streams, clips, growth, and tech.';
      case TippyFeatureTier.pro:
        return 'Strategy, captions, scheduling, and stream tips.';
      case TippyFeatureTier.starter:
        return 'Quick guidance to post smarter and stay consistent.';
    }
  }
}
