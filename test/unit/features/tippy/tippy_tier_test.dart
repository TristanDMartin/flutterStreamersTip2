import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/features/tippy/tippy_personality.dart';
import 'package:streamers_tip/features/tippy/tippy_tier.dart';

void main() {
  group('buildTippySystemPrompt', () {
    test('includes creator OS identity and tier depth', () {
      final String prompt = buildTippySystemPrompt(
        tier: TippyFeatureTier.pro,
        displayName: 'Nova',
      );
      expect(prompt, contains('Tippy'));
      expect(prompt, contains('StreamersTip'));
      expect(prompt, contains('Nova'));
      expect(prompt, contains('Pro'));
    });
  });

  group('buildTippyCreatorContextBlock', () {
    test('includes progression fields from bundle', () {
      final UserProgressBundle bundle = UserProgressBundle.fallback();
      final String block = buildTippyCreatorContextBlock(bundle);
      expect(block, contains('Creator context'));
      expect(block, contains('level'));
    });
  });

  group('TippyPersonality', () {
    test('studio tier has stream optimization prompt', () {
      final List<String> prompts =
          TippyPersonality.quickPromptsForTier(TippyFeatureTier.studio);
      expect(
        prompts.any((String p) => p.toLowerCase().contains('stream')),
        isTrue,
      );
    });
  });
}
