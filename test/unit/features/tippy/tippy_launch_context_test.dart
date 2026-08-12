import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/tippy/models/tippy_launch_context.dart';

void main() {
  group('TippyLaunchContext.forAcademyGuideExplain', () {
    test('builds visible explain prompt without hidden context on send', () {
      final TippyLaunchContext actual = TippyLaunchContext.forAcademyGuideExplain(
        guideId: 'obs-setup',
        title: 'OBS Setup',
        description: 'Configure OBS for streaming.',
        webUrl: 'https://streamerstip.com/obs-setup',
        categoryId: 'beginner',
        difficulty: 'Beginner',
      );
      expect(actual.surface, 'academy_guide');
      expect(actual.hasAcademyContext, isTrue);
      expect(actual.academyContextLabel, 'Guide: OBS Setup');
      expect(actual.prefilledPrompt, contains('Explain the Streamer Academy guide'));
      expect(actual.prefilledPrompt, contains('OBS Setup'));
      expect(actual.prefilledPrompt, contains('Guide summary:'));
      expect(actual.prefilledPrompt, contains('Configure OBS for streaming.'));
      expect(actual.prefilledPrompt, contains('Guide URL:'));
      expect(actual.prefilledPrompt, contains('Category: beginner'));
      expect(actual.prefilledPrompt, contains('Difficulty: Beginner'));
      final String? block = actual.buildFrontendContextBlock();
      expect(block, isNotNull);
      expect(block, contains('page_context: academy'));
      expect(block, contains('academy_guide_id: obs-setup'));
      expect(block, contains('academy_guide_url: https://streamerstip.com/obs-setup'));
      final String outbound = actual.composeOutboundMessage(
        actual.prefilledPrompt!,
      );
      expect(outbound, isNot(contains('TIPPY_FRONTEND_CONTEXT')));
      expect(outbound, contains('Explain the Streamer Academy guide'));
      expect(outbound, contains('Guide summary:'));
      final String stripped = actual.composeOutboundMessage(
        '${actual.buildFrontendContextBlock()}\n\nKeep this visible ask.',
      );
      expect(stripped, isNot(contains('TIPPY_FRONTEND_CONTEXT')));
      expect(stripped, contains('Keep this visible ask.'));
    });
  });
}
