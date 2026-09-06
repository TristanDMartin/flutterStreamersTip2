import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/growth/creator_growth_contract.dart';
import 'package:streamers_tip/features/tippy/tippy_brain_contract.dart';

void main() {
  group('Tippy Brain contract', () {
    test('uses creatorMemory/main and does not invent a second collection', () {
      expect(kTippyBrainPath, 'users/{uid}/creatorMemory/main');
      expect(kTippyBrainPath, CreatorGrowthContract.tippyBrainPath);
      expect(kTippyBrainPath, CreatorGrowthContract.creatorMemoryPath);
      expect(kTippyBrainForbiddenPaths, isNot(contains(kTippyBrainPath)));
      expect(kTippyBrainForbiddenPaths, contains('users/{uid}/tippyBrain'));
    });

    test('deleted UID cannot inherit guest Checkup', () {
      final TippyBrainMergeDecision actual = canMergeGuestCheckupIntoBrain(
        const TippyBrainGuestMergeInput(
          targetUid: 'uid_deleted',
          guestKey: 'guest_1',
          currentGuestKey: 'guest_1',
          deletedUids: <String>['uid_deleted'],
        ),
      );
      expect(actual.ok, isFalse);
      expect(actual.reason, 'deleted_uid');
    });

    test('inference type is not confirmed', () {
      const TippyBrainInsight inferred = TippyBrainInsight(
        id: 'inferred_creator_type',
        statement: 'Appears to be a streamer',
        type: 'inference',
        source: 'checkup_presence_analysis',
        confidence: 0.55,
        createdAt: '2026-08-31T16:00:00.000Z',
      );
      expect(inferred.type, isNot('confirmed'));
      expect(kTippyBrainInsightTypes.contains(inferred.type), isTrue);
    });

    test('skips platform re-ask when Brain has confirmed platforms', () {
      final TippyBrainLayers brain = TippyBrainLayers(
        confirmedFacts: const <TippyBrainInsight>[
          TippyBrainInsight(
            id: 'confirmed_platforms',
            statement: 'Platforms: twitch',
            type: 'confirmed',
            source: 'checkup_submitted_profiles',
            confidence: 1,
            createdAt: '2026-08-31T16:00:00.000Z',
          ),
        ],
        platformIntelligence: const TippyBrainPlatformIntelligence(
          platforms: <String>['twitch'],
        ),
      );
      expect(hasConfirmedPlatformsInBrain(brain), isTrue);
      expect(shouldSkipPlatformsQuestion(brain: brain, answers: <String, dynamic>{}), isTrue);
      expect(
        shouldSkipPlatformsQuestion(answers: <String, dynamic>{}),
        isFalse,
      );
      final Map<String, dynamic> hydrated = applyConfirmedPlatformsToAnswers(
        <String, dynamic>{},
        confirmedPlatformIdsFromBrain(brain),
      );
      expect(hydrated['platforms'], <String>['twitch']);
      expect(tippyKnowsSetupLine(<String>['twitch']), contains('Twitch first'));
    });

    test('projects Creator Read from Brain checkup context and never fakes empty Brain', () {
      expect(projectCreatorReadFromBrain(TippyBrainLayers.empty()), isNull);
      expect(hasCheckupDerivedLayer(TippyBrainLayers.empty()), isFalse);
      expect(
        shouldRedirectCheckupToMissionControl(
          isAuthenticated: true,
          isActivated: true,
          brain: TippyBrainLayers.empty(),
        ),
        isFalse,
      );
      final TippyBrainLayers brain = TippyBrainLayers(
        confirmedFacts: const <TippyBrainInsight>[
          TippyBrainInsight(
            id: 'confirmed_platforms',
            statement: 'Platforms: twitch',
            type: 'confirmed',
            source: 'checkup_submitted_profiles',
            confidence: 1,
            createdAt: '2026-08-31T16:00:00.000Z',
          ),
          TippyBrainInsight(
            id: 'confirmed_creator_type',
            statement: 'Creator type: streamer',
            type: 'confirmed',
            source: 'checkup_correction_or_yes',
            confidence: 1,
            createdAt: '2026-08-31T16:00:00.000Z',
          ),
        ],
        observations: const <TippyBrainInsight>[
          TippyBrainInsight(
            id: 'observed_twitch_0',
            statement: 'Public Twitch channel is listed as Demo.',
            type: 'observation',
            source: 'checkup_public_twitch',
            confidence: 0.6,
            createdAt: '2026-08-31T16:00:00.000Z',
          ),
        ],
        inferences: const <TippyBrainInsight>[
          TippyBrainInsight(
            id: 'inferred_presence_summary',
            statement: 'Looks like a Twitch-first live streamer.',
            type: 'inference',
            source: 'checkup_presence_analysis',
            confidence: 0.55,
            createdAt: '2026-08-31T16:00:00.000Z',
          ),
        ],
        platformIntelligence: const TippyBrainPlatformIntelligence(
          platforms: <String>['twitch'],
        ),
        currentStrategy: const TippyBrainCurrentStrategy(
          recommendedFocus: 'Clip Twitch highlights before adding another live day.',
          primaryOpportunity: 'Distribution, not more hours live.',
        ),
      );
      final TippyCreatorRead? read = projectCreatorReadFromBrain(brain);
      expect(read, isNotNull);
      expect(read!.continuityCopy, kCreatorReadContinuityCopy);
      expect(read.openingRead, contains('Twitch-first'));
      expect(read.platforms, contains('twitch'));
      expect(read.creatorType, 'streamer');
      expect(read.biggestOpportunity, contains('Distribution'));
      expect(read.notices, isNotEmpty);
      expect(read.notices.length, lessThanOrEqualTo(3));
      expect(
        shouldRedirectCheckupToMissionControl(
          isAuthenticated: true,
          isActivated: true,
          brain: brain,
        ),
        isTrue,
      );
      expect(
        shouldRedirectCheckupToMissionControl(
          isAuthenticated: true,
          isActivated: false,
          brain: brain,
        ),
        isFalse,
      );
    });

    test('projects legacy MemoryItem platforms', () {
      final TippyBrainLayers brain = TippyBrainLayers.fromJson(
        <String, dynamic>{
          'platforms': <String, dynamic>{
            'primary': <String, dynamic>{
              'value': <String>['youtube'],
              'sourceType': 'user_declared',
            },
          },
        },
      );
      expect(brain.platformIntelligence.platforms, <String>['youtube']);
      expect(shouldSkipPlatformsQuestion(brain: brain), isTrue);
    });
  });
}
