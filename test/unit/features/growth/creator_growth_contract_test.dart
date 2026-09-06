import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/growth/creator_growth_contract.dart';

void main() {
  group('CreatorGrowthContract', () {
    test('rejects duplicate top-level growth collections', () {
      expect(
        CreatorGrowthContract.isForbiddenTopLevelCollection('creatorScores'),
        isTrue,
      );
      expect(
        CreatorGrowthContract.isForbiddenTopLevelCollection('users'),
        isFalse,
      );
      expect(
        CreatorGrowthContract.creatorScoreCurrentPath,
        'users/{uid}/creatorScore/current',
      );
      expect(
        CreatorGrowthContract.gamificationStatePath,
        'users/{uid}/gamification/state',
      );
      expect(
        CreatorGrowthContract.achievementsPath,
        'users/{uid}/gamificationAchievements/{key}',
      );
    });

    test('canonicalizes product event aliases to one name', () {
      expect(
        CreatorGrowthContract.canonicalizeProductEventName(
          'tippy_onboarding_started',
        ),
        'onboarding_started',
      );
      expect(
        CreatorGrowthContract.canonicalizeProductEventName(
          'upgrade_modal_viewed',
        ),
        'paywall_viewed',
      );
      expect(
        CreatorGrowthContract.isCanonicalProductEvent('weekly_report_opened'),
        isTrue,
      );
      expect(
        CreatorGrowthContract.isCanonicalProductEvent('page_refresh'),
        isFalse,
      );
    });
  });
}
