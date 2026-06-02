import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_models.dart';
import 'package:streamers_tip/components/onboarding/onboarding_service.dart';

void main() {
  group('OnboardingService', () {
    test('new user has initial onboarding state', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      final state = await service.fetchOnboarding('new-user');

      expect(state.hasSeenIntro, isFalse);
      expect(state.hasCompletedProductTour, isFalse);
      expect(state.completedMissions, isEmpty);
      expect(state.xp, 0);
      expect(state.level, 1);
    });

    test('completeIntro stores selected creator goal', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      await service.completeIntro('user-1', 'grow_audience');
      final state = await service.fetchOnboarding('user-1');

      expect(state.hasSeenIntro, isTrue);
      expect(state.currentOnboardingStep, 0);
      expect(state.creatorGoal, 'grow_audience');
    });

    test('mission completion adds XP only once', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      final first =
          await service.completeMission('user-1', 'upload_first_post');
      final second =
          await service.completeMission('user-1', 'upload_first_post');
      final state = await service.fetchOnboarding('user-1');

      expect(first.wasAlreadyComplete, isFalse);
      expect(second.wasAlreadyComplete, isTrue);
      expect(state.completedMissions, contains('upload_first_post'));
      expect(state.xp, 50);
    });

    test('level one completes when all missions are done', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      for (final mission in levelOneMissions) {
        await service.completeMission('user-1', mission.id);
      }
      final state = await service.fetchOnboarding('user-1');

      expect(state.hasCompletedLevelOne, isTrue);
      expect(state.xp, 250);
      expect(state.level, 1);
      expect(state.creatorStatus, 'new_creator');
    });

    test('product tour and full onboarding completion are separate gates',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      await service.completeIntro('user-1', 'grow_audience');
      await service.completeProductTour('user-1');
      var state = await service.fetchOnboarding('user-1');

      expect(state.hasSeenIntro, isTrue);
      expect(state.hasCompletedProductTour, isTrue);
      expect(state.hasCompletedOnboarding, isFalse);

      await service.completeOnboarding('user-1');
      state = await service.fetchOnboarding('user-1');

      expect(state.hasCompletedOnboarding, isTrue);
    });

    test('developer tester reset restores first-launch onboarding state',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      await service.completeIntro('tester', 'grow_audience');
      await service.completeProductTour('tester');
      await service.completeMission('tester', 'upload_first_post');
      await service.resetForDeveloperTesterInstall('tester');

      final state = await service.fetchOnboarding('tester');
      expect(state.hasSeenIntro, isFalse);
      expect(state.hasCompletedProductTour, isFalse);
      expect(state.completedMissions, isEmpty);
      expect(state.xp, 0);
      expect(state.level, 1);
      expect(state.creatorStatus, 'new_creator');
    });

    test(
        'syncLevelOneMissionsFromAccountEvidence checks completed account work',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = OnboardingService(firestore: firestore);

      await firestore.collection('users').doc('user-1').set({
        'displayName': 'Stream Tester',
        'username': 'streamtester',
        'bio': 'Building a creator workflow.',
        'avatarURL': 'https://example.com/avatar.jpg',
        'platforms': [
          {'type': 'twitch'},
        ],
        'hasSharedCreatorCard': true,
        'onboarding': {
          'hasCompletedProductTour': true,
          'completedMissions': <String>[],
        },
      });
      await firestore.collection('videos').doc('video-1').set({
        'authorId': 'user-1',
      });
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('contentPlans')
          .doc('plan-1')
          .set({'title': 'Launch plan'});

      await service.syncLevelOneMissionsFromAccountEvidence('user-1');

      final state = await service.fetchOnboarding('user-1');
      expect(state.completedMissions, contains('complete_profile'));
      expect(state.completedMissions, contains('upload_first_post'));
      expect(state.completedMissions, contains('connect_platform'));
      expect(state.completedMissions, contains('create_content_plan'));
      expect(state.completedMissions, contains('share_creator_card'));
      expect(state.hasCompletedLevelOne, isTrue);
      expect(state.hasCompletedOnboarding, isTrue);
      expect(state.xp, 0);
    });
  });
}
