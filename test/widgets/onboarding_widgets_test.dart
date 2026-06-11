import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_v1_constants.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_goals_screen.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_level_unlock_screen.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_platforms_screen.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_welcome_screen.dart';

void main() {
  testWidgets('welcome screen shows headline and CTA', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingWelcomeScreen(
          onGetStarted: () {
            tapped = true;
          },
        ),
      ),
    );
    expect(find.text('Welcome to StreamersTip'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('goals screen requires selection before continue', (
    WidgetTester tester,
  ) async {
    List<String>? continuedGoals;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingGoalsScreen(
          initialGoals: const <String>[],
          onContinue: (List<String> goals) {
            continuedGoals = goals;
          },
          onBack: () {},
        ),
      ),
    );
    expect(find.text('What are you here to accomplish?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(continuedGoals, isNull);
    await tester.tap(find.text('Growth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(continuedGoals, contains('growth'));
  });

  testWidgets('platforms screen passes selected platforms', (
    WidgetTester tester,
  ) async {
    List<String>? continuedPlatforms;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPlatformsScreen(
          initialPlatforms: const <String>['twitch'],
          onContinue: (List<String> platforms) {
            continuedPlatforms = platforms;
          },
          onBack: () {},
        ),
      ),
    );
    expect(find.text('Where do you create?'), findsOneWidget);
    expect(find.text('Twitch'), findsOneWidget);
    await tester.tap(find.text('YouTube'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(continuedPlatforms, containsAll(<String>['twitch', 'youtube']));
  });

  testWidgets('level unlock screen lists starter missions and enter CTA', (
    WidgetTester tester,
  ) async {
    bool entered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingLevelUnlockScreen(
          onEnterApp: () {
            entered = true;
          },
          onBack: () {},
        ),
      ),
    );
    expect(find.text('Level 1: Getting Started'), findsOneWidget);
    expect(find.text('Complete Creator Card'), findsOneWidget);
    expect(find.text('Ask Tippy A Question'), findsOneWidget);
    expect(
      find.text('+${OnboardingV1Constants.levelOneUnlockRewardXp} XP reward'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enter StreamersTip'));
    await tester.pump();
    expect(entered, isTrue);
  });
}
