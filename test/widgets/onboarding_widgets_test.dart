import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamers_tip/components/onboarding/onboarding_intro_modal.dart';
import 'package:streamers_tip/components/onboarding/onboarding_models.dart';
import 'package:streamers_tip/components/onboarding/onboarding_service.dart';
import 'package:streamers_tip/components/onboarding/product_tour_overlay.dart';
import 'package:streamers_tip/components/onboarding/streamers_tip_onboarding.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('new user sees onboarding intro', (tester) async {
    final service = _FakeOnboardingService(OnboardingState.initial());

    await tester.pumpWidget(
      MaterialApp(
        home: StreamersTipOnboarding(
          userId: 'user-1',
          service: service,
          child: const Scaffold(body: Text('App')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('onboarding-intro-modal')), findsOneWidget);
    expect(find.text('Welcome to StreamersTip'), findsOneWidget);
  });

  testWidgets('tester user resets onboarding every login session',
      (tester) async {
    final service = _FakeOnboardingService(
      const OnboardingState(
        hasSeenIntro: true,
        hasCompletedProductTour: true,
        hasCompletedOnboarding: true,
        hasCompletedLevelOne: false,
        currentOnboardingStep: 999,
        creatorGoal: 'grow_audience',
        completedMissions: <String>['upload_first_post'],
        skippedSteps: <String>[],
        xp: 100,
        level: 1,
        creatorStatus: 'new_creator',
      ),
    );

    Future<void> pumpTesterShell({required Key sessionKey}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StreamersTipOnboarding(
            key: sessionKey,
            userId: 'tester',
            email: 'tester@streamerstip.com',
            service: service,
            child: const Scaffold(body: Text('App')),
          ),
        ),
      );
    }

    await pumpTesterShell(sessionKey: const Key('tester-session-1'));
    await tester.pump();
    await tester.pump();

    expect(service.resetCount, 1);
    expect(find.byKey(const Key('onboarding-intro-modal')), findsOneWidget);

    await pumpTesterShell(sessionKey: const Key('tester-session-2'));
    await tester.pump();

    expect(service.resetCount, 2);
  });

  testWidgets('returning user does not see intro again', (tester) async {
    final service = _FakeOnboardingService(
      const OnboardingState(
        hasSeenIntro: true,
        hasCompletedProductTour: true,
        hasCompletedOnboarding: true,
        hasCompletedLevelOne: false,
        currentOnboardingStep: 999,
        creatorGoal: 'grow_audience',
        completedMissions: <String>[],
        skippedSteps: <String>[],
        xp: 0,
        level: 1,
        creatorStatus: 'new_creator',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StreamersTipOnboarding(
          userId: 'user-1',
          service: service,
          child: const Scaffold(body: Text('App')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('onboarding-intro-modal')), findsNothing);
    expect(find.byKey(const Key('level-one-checklist')), findsNothing);
    expect(find.text('Level 1'), findsNothing);
  });

  testWidgets('completed product tour opens level one checklist',
      (tester) async {
    final service = _FakeOnboardingService(
      const OnboardingState(
        hasSeenIntro: true,
        hasCompletedProductTour: true,
        hasCompletedOnboarding: false,
        hasCompletedLevelOne: false,
        currentOnboardingStep: 999,
        creatorGoal: 'grow_audience',
        completedMissions: <String>[],
        skippedSteps: <String>[],
        xp: 0,
        level: 1,
        creatorStatus: 'new_creator',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StreamersTipOnboarding(
            userId: 'user-1',
            service: service,
            child: const Scaffold(body: Text('App')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('level-one-checklist')), findsOneWidget);
    expect(service.completedOnboardingCount, 0);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    expect(service.completedOnboardingCount, 1);
  });

  testWidgets('user can select creator goal', (tester) async {
    String? selectedGoal;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingIntroModal(
          onComplete: (String goal) => selectedGoal = goal,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding-start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('creator-goal-grow-audience')));
    await tester.tap(find.byKey(const Key('onboarding-start-button')));

    expect(selectedGoal, 'grow_audience');
  });

  testWidgets('product tour progresses correctly and can be skipped',
      (tester) async {
    bool finished = false;
    int? skippedAt;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProductTourOverlay(
            onFinish: () => finished = true,
            onSkip: (int step) => skippedAt = step,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('product-tour-overlay')), findsOneWidget);
    expect(find.byKey(const Key('coachmark-home-feed')), findsOneWidget);
    expect(find.text('Swipe up for more'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('product-tour-overlay')),
      const Offset(0, -360),
      900,
    );
    await tester.pumpAndSettle();

    expect(finished, isFalse);
    expect(find.text('Upload'), findsOneWidget);

    while (find.text('Finish Tour').evaluate().isEmpty) {
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Finish Tour'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    expect(skippedAt, isNull);
  });

  testWidgets('product tour primer can be skipped', (tester) async {
    bool finished = false;
    int? skippedAt;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProductTourOverlay(
            onFinish: () => finished = true,
            onSkip: (int step) => skippedAt = step,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('product-tour-skip-button')));
    await tester.pumpAndSettle();

    expect(skippedAt, 0);
    expect(finished, isFalse);
  });
}

class _FakeOnboardingService extends OnboardingService {
  _FakeOnboardingService(OnboardingState initial)
      : _controller = StreamController<OnboardingState>.broadcast(),
        _state = initial,
        super(firestore: FakeFirebaseFirestore()) {
    Future<void>.microtask(() => _controller.add(initial));
  }

  final StreamController<OnboardingState> _controller;
  OnboardingState _state;
  int resetCount = 0;
  int completedOnboardingCount = 0;

  @override
  Stream<OnboardingState> watchOnboarding(String userId) {
    return Stream<OnboardingState>.multi((controller) {
      controller.add(_state);
      final subscription = _controller.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> completeIntro(String userId, String creatorGoal) async {
    _state = OnboardingState(
      hasSeenIntro: true,
      hasCompletedProductTour: false,
      hasCompletedOnboarding: false,
      hasCompletedLevelOne: false,
      currentOnboardingStep: 0,
      creatorGoal: creatorGoal,
      completedMissions: const <String>[],
      skippedSteps: const <String>[],
      xp: 0,
      level: 1,
      creatorStatus: 'new_creator',
    );
    _controller.add(_state);
  }

  @override
  Future<void> completeProductTour(String userId) async {
    _state = OnboardingState(
      hasSeenIntro: _state.hasSeenIntro,
      hasCompletedProductTour: true,
      hasCompletedOnboarding: false,
      hasCompletedLevelOne: _state.hasCompletedLevelOne,
      currentOnboardingStep: 999,
      creatorGoal: _state.creatorGoal,
      completedMissions: _state.completedMissions,
      skippedSteps: _state.skippedSteps,
      xp: _state.xp,
      level: _state.level,
      creatorStatus: _state.creatorStatus,
    );
    _controller.add(_state);
  }

  @override
  Future<void> skipProductTour(String userId, int currentStep) async {
    _state = OnboardingState(
      hasSeenIntro: _state.hasSeenIntro,
      hasCompletedProductTour: true,
      hasCompletedOnboarding: false,
      hasCompletedLevelOne: _state.hasCompletedLevelOne,
      currentOnboardingStep: currentStep,
      creatorGoal: _state.creatorGoal,
      completedMissions: _state.completedMissions,
      skippedSteps: <String>[..._state.skippedSteps, 'product_tour'],
      xp: _state.xp,
      level: _state.level,
      creatorStatus: _state.creatorStatus,
    );
    _controller.add(_state);
  }

  @override
  Future<void> dismissLevelOneChecklist(String userId) async {
    _state = OnboardingState(
      hasSeenIntro: _state.hasSeenIntro,
      hasCompletedProductTour: _state.hasCompletedProductTour,
      hasCompletedOnboarding: _state.hasCompletedOnboarding,
      hasCompletedLevelOne: _state.hasCompletedLevelOne,
      currentOnboardingStep: _state.currentOnboardingStep,
      creatorGoal: _state.creatorGoal,
      completedMissions: _state.completedMissions,
      skippedSteps: <String>[..._state.skippedSteps, 'level_one_checklist'],
      xp: _state.xp,
      level: _state.level,
      creatorStatus: _state.creatorStatus,
    );
    _controller.add(_state);
  }

  @override
  Future<void> completeOnboarding(String userId) async {
    completedOnboardingCount += 1;
    _state = OnboardingState(
      hasSeenIntro: _state.hasSeenIntro,
      hasCompletedProductTour: _state.hasCompletedProductTour,
      hasCompletedOnboarding: true,
      hasCompletedLevelOne: _state.hasCompletedLevelOne,
      currentOnboardingStep: _state.currentOnboardingStep,
      creatorGoal: _state.creatorGoal,
      completedMissions: _state.completedMissions,
      skippedSteps: _state.skippedSteps,
      xp: _state.xp,
      level: _state.level,
      creatorStatus: _state.creatorStatus,
    );
    _controller.add(_state);
  }

  @override
  Future<void> resetForDeveloperTesterInstall(String userId) async {
    resetCount += 1;
    _state = OnboardingState.initial();
    _controller.add(_state);
  }
}
