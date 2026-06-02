import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/features/tippy/tippy_identity.dart';
import 'package:streamers_tip/features/tippy/tippy_tier.dart';

void main() {
  group('TippyIdentity', () {
    test('one-liner and capabilities are defined', () {
      expect(TippyIdentity.tippyOneLiner, isNotEmpty);
      expect(TippyIdentity.tippyIntroCapabilities.length, greaterThan(3));
      expect(TippyIdentity.tippyCreatorSignals, isNotEmpty);
    });

    test('buildTippySystemPrompt includes canonical identity and tier', () {
      final String prompt = TippyIdentity.buildTippySystemPrompt(
        tier: TippyFeatureTier.pro,
        displayName: 'Nova',
      );
      expect(prompt, contains('Tippy'));
      expect(prompt, contains('StreamersTip'));
      expect(prompt, contains('Nova'));
      expect(prompt, contains('Subscription: Pro'));
      expect(prompt, contains(TippyIdentity.tippyOneLiner));
      expect(prompt, contains('never say you cannot'));
    });

    test('buildTippyCreatorContextBlock includes progression', () {
      final String block = TippyIdentity.buildTippyCreatorContextBlock(
        UserProgressBundle.fallback(),
      );
      expect(block, contains('Creator context'));
      expect(block, contains('level'));
    });

    test('deprecated top-level helpers delegate to TippyIdentity', () {
      final String prompt = buildTippySystemPrompt(
        tier: TippyFeatureTier.starter,
        displayName: 'Test',
      );
      expect(prompt, contains('Subscription: Starter'));
    });
  });
}
