import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_profile_draft.dart';

void main() {
  group('TippyOnboardingContract v1', () {
    test('has exactly seven questions with stable ids', () {
      expect(kTippyOnboardingQuestions.length, kTippyOnboardingTotalQuestions);
      expect(
        kTippyOnboardingQuestions.map((TippyOnboardingQuestion q) => q.id),
        <String>[
          'creator_type',
          'platforms',
          'niche',
          'experience',
          'goals',
          'schedule',
          'content_formats',
        ],
      );
    });

    test('keeps guided profile stages in one persistent host path', () {
      for (final String stage in TippyOnboardingStages.guidedProfileStages) {
        expect(TippyOnboardingStages.isGuidedProfileStage(stage), isTrue);
      }
      expect(
        TippyOnboardingStages.isGuidedProfileStage(
          TippyOnboardingStages.displayName,
        ),
        isTrue,
      );
      expect(
        TippyOnboardingStages.isGuidedProfileStage(
          TippyOnboardingStages.welcome,
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.isGuidedProfileStage(
          TippyOnboardingStages.notifications,
        ),
        isFalse,
      );
    });

    test('validates single and multi answers', () {
      final TippyOnboardingQuestion creatorType =
          kTippyOnboardingQuestions.first;
      expect(isValidTippyOnboardingAnswer(creatorType, 'streamer'), isTrue);
      expect(isValidTippyOnboardingAnswer(creatorType, 'nope'), isFalse);
      final TippyOnboardingQuestion platforms =
          tippyOnboardingQuestionById('platforms')!;
      expect(
        isValidTippyOnboardingAnswer(platforms, <String>['twitch', 'youtube']),
        isTrue,
      );
      expect(
        isValidTippyOnboardingAnswer(platforms, <String>[]),
        isFalse,
      );
    });

    test('stage next advances through funnel', () {
      expect(
        TippyOnboardingStages.next(TippyOnboardingStages.welcome),
        TippyOnboardingStages.questions,
      );
      expect(
        TippyOnboardingStages.next(TippyOnboardingStages.landingChoice),
        isNull,
      );
    });

    test('keeps Back as a visible review without rewinding identity', () {
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.profileReview,
          emailVerified: true,
        ),
        TippyOnboardingStages.platformHandles,
      );
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.accountSecured,
          emailVerified: true,
        ),
        isNull,
      );
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.verifyEmail,
          isAuthenticated: true,
        ),
        isNull,
      );
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.twitchConnect,
          emailVerified: true,
        ),
        isNull,
      );
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.firstMission,
          emailVerified: true,
        ),
        TippyOnboardingStages.creatorSpaceReady,
      );
    });

    test('skips twitch_connect on Back from notifications when DNA omitted Twitch',
        () {
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.notifications,
          emailVerified: true,
          answers: <String, dynamic>{'platforms': <String>['youtube']},
        ),
        TippyOnboardingStages.profileReview,
      );
      expect(
        TippyOnboardingStages.reviewPrevious(
          stage: TippyOnboardingStages.notifications,
          emailVerified: true,
          answers: <String, dynamic>{'platforms': <String>['twitch']},
        ),
        TippyOnboardingStages.twitchConnect,
      );
    });

    test('never rewinds verify_email or signup to Meet Tippy', () {
      expect(
        TippyOnboardingStages.resumeStage(
          currentStage: TippyOnboardingStages.verifyEmail,
          proposedStage: TippyOnboardingStages.welcome,
        ),
        TippyOnboardingStages.accountSecured,
      );
      expect(
        TippyOnboardingStages.resumeStage(
          currentStage: TippyOnboardingStages.signup,
          proposedStage: TippyOnboardingStages.welcome,
        ),
        TippyOnboardingStages.accountSecured,
      );
      expect(
        TippyOnboardingStages.resumeStage(
          currentStage: TippyOnboardingStages.verifyEmail,
          proposedStage: TippyOnboardingStages.username,
        ),
        TippyOnboardingStages.username,
      );
      expect(
        TippyOnboardingStages.resumeStage(
          currentStage: TippyOnboardingStages.username,
          proposedStage: TippyOnboardingStages.accountSecured,
        ),
        TippyOnboardingStages.username,
      );
    });

    test('keeps signup→verify display monotonic after createUser', () {
      const String floor = TippyOnboardingStages.verifyEmail;
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.signup,
          signupClosedFloor: floor,
        ),
        TippyOnboardingStages.verifyEmail,
      );
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.signup,
          signupClosedFloor: floor,
          statusRoute: null,
        ),
        TippyOnboardingStages.verifyEmail,
      );
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.signup,
          signupClosedFloor: floor,
          statusHint: TippyOnboardingStages.welcome,
          statusRoute: 'onboarding',
        ),
        TippyOnboardingStages.verifyEmail,
      );
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.verifyEmail,
          signupClosedFloor: floor,
          statusRoute: 'verify-email',
        ),
        TippyOnboardingStages.verifyEmail,
      );
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.verifyEmail,
          signupClosedFloor: floor,
          statusHint: TippyOnboardingStages.accountSecured,
          statusRoute: 'onboarding',
          emailVerified: true,
        ),
        TippyOnboardingStages.accountSecured,
      );
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.username,
          signupClosedFloor: floor,
          statusHint: TippyOnboardingStages.signup,
          statusRoute: 'onboarding',
          emailVerified: true,
        ),
        TippyOnboardingStages.username,
      );
      expect(
        TippyOnboardingStages.resolveVisibleStage(
          storedStage: TippyOnboardingStages.signup,
          emailVerified: true,
        ),
        TippyOnboardingStages.accountSecured,
      );
    });
  });

  group('Tippy identity seed', () {
    test('uses status.canonicalUsername before username or reservation', () {
      expect(
        ownedUsernameFromAccountStatus(
          canonicalUsername: 'actual_creator',
          username: 'stale_creator',
          preferredUsername: 'reserved_creator',
          email: 'creator@example.com',
        ),
        'actual_creator',
      );
    });

    test('builds the same Creator DNA summary shape as web', () {
      expect(
        buildCreatorDnaSummary(<String, dynamic>{
          'creator_type': 'streamer',
          'platforms': <String>['twitch', 'youtube'],
          'niche': <String>['gaming', 'commentary'],
          'niche_description': 'late night ranked runs',
          'experience': 'growing',
          'goals': <String>['build_audience', 'monetize'],
          'schedule': 'weekly',
        }),
        <String>[
          'Live Streamer',
          'Twitch + YouTube',
          'Gaming · Commentary',
          '"late night ranked runs"',
          'Grow my audience',
          'Creates about once a week',
        ],
      );
    });

    test('prefers claimed signup username over email local-part draft', () {
      expect(
        selectTippyIdentitySeed(
          accountUsername: 'beacon16062',
          preferredUsername: 'beacon16062',
          draftUsername: 'beacon16062gmail',
          displayName: 'beacon16062',
          email: 'beacon16062@gmail.com',
        ),
        'beacon16062',
      );
      expect(isOwnedTippyUsername('beacon16062', 'Beacon16062'), isTrue);
      expect(isOwnedTippyUsername('othername', 'beacon16062'), isFalse);
      expect(
        selectTippyIdentitySeed(
          preferredUsername: 'beacon16062',
          draftUsername: 'beacon1606',
          email: 'beacon16062@example.com',
        ),
        'beacon16062',
      );
      expect(
        selectTippyIdentitySeed(
          draftUsername: '',
          displayName: 'beacon16062',
          email: 'beacon16062@gmail.com',
        ),
        '',
      );
      expect(
        selectTippyIdentitySeed(
          accountUsername: 'beacon160612',
          preferredUsername: 'actualusername',
          draftUsername: 'beacon160612',
          email: 'beacon160612@gmail.com',
        ),
        'actualusername',
      );
      expect(
        selectTippyIdentitySeed(
          accountUsername: 'beacon160612',
          preferredUsername: null,
          draftUsername: 'beacon160612',
          email: 'beacon160612@gmail.com',
        ),
        '',
      );
      expect(
        canonicalUsernameFromAccountFields(
          username: 'beacon160612',
          preferredUsername: 'actualusername',
          email: 'beacon160612@gmail.com',
        ),
        'actualusername',
      );
      expect(
        seedCreatorCallName(
          ownedUsername: '',
          draftDisplayName: '',
          authDisplayName: 'Tristan T3CHNICS Martin',
        ),
        'Tristan T3CHNICS Martin',
      );
      expect(
        seedCreatorCallName(
          ownedUsername: 'beacon1606',
          draftDisplayName: '',
          authDisplayName: 'Tristan T3CHNICS Martin',
        ),
        'beacon1606',
      );
      expect(
        ownedUsernameFromAccountStatus(
          canonicalUsername: '',
          username: null,
          preferredUsername: 'beacon1606',
          email: 'smove50@gmail.com',
        ),
        'beacon1606',
      );
      expect(
        ownedUsernameFromAccountStatus(
          canonicalUsername: 'claimedname',
          username: 'claimedname',
          preferredUsername: 'beacon1606',
        ),
        'claimedname',
      );
      expect(
        ownedUsernameFromAccountStatus(
          canonicalUsername: 'johnsmith',
          username: 'johnsmith',
          preferredUsername: 'tester0505',
          draftUsername: 'tester0505',
          email: 'john.smith@gmail.com',
        ),
        'tester0505',
      );
      expect(
        ownedUsernameFromAccountStatus(
          canonicalUsername: '',
          username: null,
          preferredUsername: null,
          draftUsername: 'tester0505',
          email: 'john.smith@gmail.com',
        ),
        'tester0505',
      );
      expect(
        resolveCreatorUsernameScreen(
          statusLoaded: true,
          canonicalUsername: 'testthiswork',
          provisioned: true,
        ),
        CreatorUsernameScreenState.canonical,
      );
      expect(
        resolveCreatorUsernameScreen(
          statusLoaded: true,
          canonicalUsername: '',
          preferredUsername: '',
          provisioned: true,
        ),
        CreatorUsernameScreenState.select,
      );
      expect(
        resolveCreatorUsernameScreen(
          statusLoaded: true,
          canonicalUsername: '',
          preferredUsername: 'testthiswork',
          provisioned: false,
        ),
        CreatorUsernameScreenState.select,
      );
      expect(
        resolveCreatorUsernameScreen(
          statusLoaded: false,
          canonicalUsername: '',
        ),
        CreatorUsernameScreenState.select,
      );
    });

    test('exposes the locked onboarding invariants', () {
      expect(
        kTippyOnboardingInvariants,
        contains('email_prefix_never_becomes_username'),
      );
      expect(
        kTippyOnboardingInvariants,
        contains('never_derive_username_from_email_after_signup'),
      );
      expect(
        kTippyOnboardingInvariants,
        contains('notifications_never_block_activation'),
      );
      expect(
        kTippyOnboardingInvariants,
        contains('verification_never_rewinds_onboarding'),
      );
      expect(
        kTippyOnboardingInvariants,
        contains('signup_success_never_reopens_signup'),
      );
      expect(
        kTippyOnboardingInvariants,
        contains('signup_visible_stage_is_monotonic'),
      );
      expect(
        kTippyOnboardingInvariants,
        contains('back_never_rewinds_lifecycle'),
      );
    });

    test('does not rewind signup or verify to Meet Tippy', () {
      expect(
        TippyOnboardingStages.shouldForceMeetTippyIntroForGuest(
          stage: TippyOnboardingStages.verifyEmail,
          isAuthenticated: true,
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.shouldForceMeetTippyIntroForGuest(
          stage: TippyOnboardingStages.accountSecured,
          isAuthenticated: false,
          hasCachedAuth: true,
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.shouldForceMeetTippyIntroForGuest(
          stage: TippyOnboardingStages.signup,
          isAuthenticated: false,
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.shouldForceMeetTippyIntroForGuest(
          stage: TippyOnboardingStages.verifyEmail,
          isAuthenticated: false,
          hasLiveVerificationIntent: true,
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.shouldForceMeetTippyIntroForGuest(
          stage: TippyOnboardingStages.accountSecured,
          isAuthenticated: false,
        ),
        isTrue,
      );
    });

    test('routes twitch oauth from DNA or persisted selectedPlatforms', () {
      expect(
        TippyOnboardingStages.hasSelectedTwitchInDna(
          <String, dynamic>{'platforms': <String>['twitch']},
        ),
        isTrue,
      );
      expect(
        TippyOnboardingStages.hasSelectedTwitchInDna(
          <String, dynamic>{},
          selectedPlatforms: <String>['twitch'],
        ),
        isTrue,
      );
      expect(
        TippyOnboardingStages.stageAfterCreatorCard(
          answers: <String, dynamic>{'platforms': <String>['twitch']},
        ),
        TippyOnboardingStages.twitchConnect,
      );
      expect(
        TippyOnboardingStages.resolvePostCreatorCardStage(
          localStage: TippyOnboardingStages.twitchConnect,
          serverStage: TippyOnboardingStages.notifications,
        ),
        TippyOnboardingStages.twitchConnect,
      );
    });

    test('resets empty leftover Tippy after account deletion', () {
      expect(
        TippyOnboardingStages.shouldResetSessionAfterAccountDeletion(
          hasDeleteFlag: true,
          isAuthenticated: false,
          stage: TippyOnboardingStages.welcome,
        ),
        isTrue,
      );
      expect(
        TippyOnboardingStages.shouldResetSessionAfterAccountDeletion(
          hasDeleteFlag: true,
          isAuthenticated: true,
          stage: TippyOnboardingStages.signup,
          answers: <String, dynamic>{'creator_type': 'streamer'},
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.shouldResetSessionAfterAccountDeletion(
          hasDeleteFlag: true,
          isAuthenticated: false,
          stage: TippyOnboardingStages.questions,
          questionIndex: 2,
          hasSeenTippyIntro: true,
        ),
        isFalse,
      );
      expect(
        TippyOnboardingStages.shouldResetSessionAfterAccountDeletion(
          hasDeleteFlag: false,
          isAuthenticated: false,
          stage: TippyOnboardingStages.welcome,
        ),
        isFalse,
      );
    });
  });

  group('suggestBioFromAnswers', () {
    test('matches website DNA copy from niche, type, and goal', () {
      final String actualX = suggestBioFromAnswers(<String, dynamic>{
        'creator_type': 'streamer',
        'niche': <String>['gaming', 'commentary'],
        'goals': <String>['build_audience', 'monetize'],
      });
      expect(
        actualX,
        'Gaming and Commentary live streamer focused on growing an audience. '
        'Building a community around consistent growth and good conversations.',
      );
    });

    test('prefers niche_description over category labels', () {
      final String actualX = suggestBioFromAnswers(<String, dynamic>{
        'creator_type': 'streamer',
        'niche': <String>['gaming'],
        'niche_description': 'horror fps nights',
        'goals': <String>['build_community'],
      });
      expect(
        actualX,
        'Horror fps nights live streamer focused on building community. '
        'Building a community around consistent growth and good conversations.',
      );
    });

    test('prefills identity socials from checkup profiles without skipping', () {
      expect(
        onboardingHandleFromCheckupInput('twitch', '@imdanewtech'),
        'imdanewtech',
      );
      expect(
        onboardingHandleFromCheckupInput(
          'twitch',
          'https://www.twitch.tv/imdanewtech',
        ),
        'imdanewtech',
      );
      final TippyProfileDraft actualX = applyCheckupProfilesToProfileDraft(
        draft: TippyProfileDraft(),
        checkupProfiles: <Map<String, String>>[
          <String, String>{
            'platform': 'twitch',
            'handleOrUrl': '@imdanewtech',
          },
        ],
      );
      expect(actualX.platformIds, <String>['twitch']);
      expect(actualX.platformHandles['twitch'], 'imdanewtech');
      final TippyProfileDraft fromDna = applyDnaAnswersToProfileDraft(
        draft: TippyProfileDraft(),
        answers: <String, dynamic>{
          'platforms': <String>['twitch'],
        },
        checkupProfiles: <Map<String, String>>[
          <String, String>{
            'platform': 'twitch',
            'handleOrUrl': '@imdanewtech',
          },
        ],
      );
      expect(fromDna.platformHandles['twitch'], 'imdanewtech');
      expect(
        applyCheckupProfilesToProfileDraft(
          draft: TippyProfileDraft(),
          checkupProfiles: const <Map<String, String>>[],
        ).platformIds,
        isEmpty,
      );
    });

    test('fills an empty profile draft from DNA answers', () {
      final TippyProfileDraft actualX = applyDnaAnswersToProfileDraft(
        draft: TippyProfileDraft(),
        answers: <String, dynamic>{
          'platforms': <String>['twitch'],
          'niche': <String>['gaming'],
          'creator_type': 'streamer',
          'goals': <String>['build_audience'],
        },
      );
      expect(actualX.platformIds, <String>['twitch']);
      expect(actualX.categoryIds, <String>['gaming']);
      expect(
        actualX.bio,
        'Gaming live streamer focused on growing an audience. '
        'Building a community around consistent growth and good conversations.',
      );
    });

    test('keeps an existing bio instead of regenerating', () {
      final TippyProfileDraft actualX = applyDnaAnswersToProfileDraft(
        draft: TippyProfileDraft(bio: 'Custom intro'),
        answers: <String, dynamic>{
          'creator_type': 'streamer',
          'niche': <String>['gaming'],
        },
      );
      expect(actualX.bio, 'Custom intro');
    });

    test('does not invent a bio when DNA answers are missing', () {
      final TippyProfileDraft actualX = applyDnaAnswersToProfileDraft(
        draft: TippyProfileDraft(),
        answers: <String, dynamic>{},
      );
      expect(actualX.bio, '');
    });

    test('username change preferDraft beats provisioned username', () {
      expect(
        resolveCanonicalOnboardingUsername(
          accountUsername: 'oldname',
          preferredUsername: 'oldname',
          draftUsername: 'newname',
          email: 'creator@example.com',
          preferDraft: true,
        ),
        'newname',
      );
      expect(
        canonicalUsernameFromAccountFields(
          username: 'newname',
          preferredUsername: 'oldname',
          email: 'creator@example.com',
        ),
        'newname',
      );
    });

    test('remix returns full replacement bios up to 3 times', () {
      final Map<String, dynamic> answers = <String, dynamic>{
        'creator_type': 'streamer',
        'niche': <String>['gaming'],
        'goals': <String>['build_audience'],
        'platforms': <String>['twitch'],
      };
      final String initial = suggestBioFromAnswers(answers);
      final ({String bio, int remixCount})? r1 = nextTippyRemixedBio(
        answers: answers,
        remixCount: 0,
        previousBios: <String>[initial],
      );
      final ({String bio, int remixCount})? r2 = nextTippyRemixedBio(
        answers: answers,
        remixCount: 1,
        previousBios: <String>[initial, r1!.bio],
      );
      final ({String bio, int remixCount})? r3 = nextTippyRemixedBio(
        answers: answers,
        remixCount: 2,
        previousBios: <String>[initial, r1.bio, r2!.bio],
      );
      final ({String bio, int remixCount})? r4 =
          nextTippyRemixedBio(answers: answers, remixCount: 3);
      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r3, isNotNull);
      expect(r1.bio, isNot(initial));
      expect(r2.bio, isNot(r1.bio));
      expect(r3!.bio, isNot(r2.bio));
      expect(tippyBioSimilarity(initial, r1.bio) < 0.55, isTrue);
      expect(r1.remixCount, 1);
      expect(r2.remixCount, 2);
      expect(r3.remixCount, 3);
      expect(r4, isNull);
    });
  });

  group('Checkup transferred context consume', () {
    test('skips confirmed platforms and still asks unknown DNA', () {
      expect(
        TippyOnboardingCopy.checkupBroughtOver,
        contains('brought over what I learned'),
      );
      expect(
        TippyOnboardingCopy.checkupBroughtOver,
        contains("picture of what you're creating"),
      );
      expect(
        TippyOnboardingCopy.checkupBroughtOverBody,
        contains("what you're making"),
      );
      expect(TippyOnboardingCopy.checkupLooksRight, 'LOOKS RIGHT');
      expect(TippyOnboardingCopy.welcomeHi, "Hey! I'm Tippy");
      final Map<String, dynamic> answers = <String, dynamic>{
        'platforms': <String>['twitch'],
        'creator_type': 'streamer',
      };
      expect(nextUnansweredOnboardingIndex(answers), 2);
      expect(kTippyOnboardingQuestions[2].id, 'niche');
      expect(kTippyOnboardingQuestions[3].id, 'experience');
      expect(kTippyOnboardingQuestions[4].id, 'goals');
      expect(kTippyOnboardingQuestions[5].id, 'schedule');
    });
  });
}
