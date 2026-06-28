import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_models.dart';
import 'package:streamers_tip/components/onboarding/onboarding_service.dart';
import 'package:streamers_tip/components/onboarding/onboarding_v1_constants.dart';

void main() {
  group('OnboardingService V1', () {
    test('new user has initial onboarding state', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final OnboardingService service = OnboardingService(firestore: firestore);
      final OnboardingState state = await service.fetchOnboarding('new-user');
      expect(state.completed, isFalse);
      expect(state.status, OnboardingStatus.notStarted);
      expect(state.currentStep, 0);
      expect(state.creatorGoals, isEmpty);
      expect(state.platforms, isEmpty);
    });

    test('ensureMigrated does not auto-complete in-progress V1 users', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('in-progress').set(
        <String, dynamic>{
          'displayName': 'Creator',
          'username': 'creator',
          'xp': 50,
          'createdAt': Timestamp.now(),
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'status': OnboardingStatus.inProgress,
            'completed': false,
            'currentStep': 2,
            'hasSeenIntro': true,
            'creatorGoals': <String>['growth'],
          },
        },
      );
      final OnboardingService service = OnboardingService(firestore: firestore);
      final OnboardingState state =
          await service.ensureMigrated('in-progress');
      expect(state.completed, isFalse);
      expect(state.currentStep, 2);
      expect(state.creatorGoals, contains('growth'));
    });

    test('ensureMigrated clears stale completion flags for incomplete V1', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('stale-flags').set(
        <String, dynamic>{
          'hasCompletedOnboarding': true,
          'onboardingCompleted': true,
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'status': OnboardingStatus.inProgress,
            'completed': false,
            'currentStep': 3,
            'hasSeenIntro': true,
          },
        },
      );
      final OnboardingService service = OnboardingService(firestore: firestore);
      final OnboardingState state =
          await service.ensureMigrated('stale-flags');
      expect(state.completed, isFalse);
      expect(state.currentStep, 3);
      final Map<String, dynamic>? doc =
          (await firestore.collection('users').doc('stale-flags').get()).data();
      expect(doc?['hasCompletedOnboarding'], isFalse);
      expect(doc?['onboardingCompleted'], isFalse);
      expect((doc?['onboarding'] as Map?)?['completed'], isFalse);
    });

    test('fromUserMap treats V1 completion only from onboarding.completed', () {
      final OnboardingState state = OnboardingState.fromUserMap(
        <String, dynamic>{
          'hasCompletedOnboarding': true,
          'onboardingCompleted': true,
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'completed': false,
            'currentStep': 2,
          },
        },
      );
      expect(state.completed, isFalse);
      expect(state.currentStep, 2);
    });

    test('ensureMigrated does not auto-complete partial progress without V1', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('partial').set(
        <String, dynamic>{
          'displayName': 'Partial',
          'username': 'partial',
          'xp': 25,
          'createdAt': Timestamp.now(),
          'onboarding': <String, dynamic>{
            'hasSeenIntro': true,
            'currentStep': 1,
          },
        },
      );
      final OnboardingService service = OnboardingService(firestore: firestore);
      final OnboardingState state = await service.ensureMigrated('partial');
      expect(state.completed, isFalse);
      final Map<String, dynamic>? doc =
          (await firestore.collection('users').doc('partial').get()).data();
      expect(doc?['hasCompletedOnboarding'], isFalse);
      expect((doc?['onboarding'] as Map?)?['completed'], isFalse);
    });

    test('ensureMigrated does not auto-complete fresh signup profiles', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('fresh-signup').set(
        <String, dynamic>{
          'displayName': 'New Creator',
          'username': 'newcreator',
          'email': 'new@example.com',
          'createdAt': Timestamp.now(),
        },
      );
      final OnboardingService service = OnboardingService(firestore: firestore);
      final OnboardingState state =
          await service.ensureMigrated('fresh-signup');
      expect(state.completed, isFalse);
      expect(state.status, OnboardingStatus.notStarted);
      final Map<String, dynamic>? doc =
          (await firestore.collection('users').doc('fresh-signup').get()).data();
      expect(doc?['hasCompletedOnboarding'], isFalse);
      expect(doc?['onboardingCompleted'], isFalse);
      expect((doc?['onboarding'] as Map?)?['completed'], isFalse);
    });

    test('ensureMigrated marks legacy users completed', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('legacy-user').set(
        <String, dynamic>{
          'displayName': 'Legacy Creator',
          'username': 'legacy',
          'hasCompletedOnboarding': true,
        },
      );
      final OnboardingService service = OnboardingService(firestore: firestore);
      final OnboardingState state =
          await service.ensureMigrated('legacy-user');
      expect(state.completed, isTrue);
      expect(state.status, OnboardingStatus.completed);
      expect(state.currentStep, OnboardingV1Constants.completedStepMarker);
    });

    test('saveCreatorGoals stores goals and advances step', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final OnboardingService service = OnboardingService(firestore: firestore);
      await service.ensureMigrated('user-1');
      await service.saveCreatorGoals(
        'user-1',
        <String>['growth', 'streaming'],
      );
      final OnboardingState state = await service.fetchOnboarding('user-1');
      expect(state.creatorGoals, containsAll(<String>['growth', 'streaming']));
      expect(state.currentStep, 2);
      expect(state.status, OnboardingStatus.inProgress);
    });

    test('resetForDeveloperTesterInstall clears legacy completion flags', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('tester-user').set(
        <String, dynamic>{
          'hasCompletedOnboarding': true,
          'displayName': 'Tester',
          'username': 'tester',
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'completed': true,
            'hasCompletedOnboarding': true,
            'hasCompletedProductTour': true,
            'status': OnboardingStatus.completed,
          },
        },
      );
      final OnboardingService service = OnboardingService(firestore: firestore);
      await service.resetForDeveloperTesterInstall('tester-user');
      final OnboardingState state = await service.fetchOnboarding('tester-user');
      expect(state.completed, isFalse);
      expect(state.status, OnboardingStatus.notStarted);
      expect(state.currentStep, 0);
      final Map<String, dynamic>? doc =
          (await firestore.collection('users').doc('tester-user').get()).data();
      expect(doc?['hasCompletedOnboarding'], isFalse);
      final Map<String, dynamic>? onboarding =
          (doc?['onboarding'] as Map?)?.cast<String, dynamic>();
      expect(onboarding?['completed'], isFalse);
      expect(onboarding?['hasCompletedOnboarding'], isFalse);
      expect(onboarding?['hasCompletedProductTour'], isFalse);
    });

    test('saveCreatorCard sets creatorCardCompleted flag', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final OnboardingService service = OnboardingService(firestore: firestore);
      await service.ensureMigrated('user-1');
      await service.saveCreatorCard(
        userId: 'user-1',
        displayName: 'Creator',
        username: 'creator',
        bio: 'Hello world',
        categoryId: 'gaming',
      );
      final Map<String, dynamic>? doc =
          (await firestore.collection('users').doc('user-1').get()).data();
      expect(
        (doc?['onboarding'] as Map?)?['creatorCardCompleted'],
        isTrue,
      );
    });

    test('completeOnboarding marks user completed in Firestore', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final OnboardingService service = OnboardingService(firestore: firestore);
      await service.ensureMigrated('user-1');
      await service.completeOnboarding('user-1');
      final OnboardingState state = await service.fetchOnboarding('user-1');
      expect(state.completed, isTrue);
      expect(state.status, OnboardingStatus.completed);
      expect(state.currentStep, OnboardingV1Constants.completedStepMarker);
      final Map<String, dynamic>? doc =
          (await firestore.collection('users').doc('user-1').get()).data();
      expect(doc?['hasCompletedOnboarding'], isTrue);
      expect(
        (doc?['onboarding'] as Map?)?['completed'],
        isTrue,
      );
    });
  });
}
