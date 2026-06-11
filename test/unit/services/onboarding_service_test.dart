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
