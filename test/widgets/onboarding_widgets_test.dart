import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_v1_constants.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_level_unlock_screen.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_personalize_screen.dart';
import 'package:streamers_tip/components/onboarding/screens/onboarding_welcome_screen.dart';
import 'package:streamers_tip/widgets/brand_icons.dart';

void main() {
  testWidgets('welcome screen shows headline and CTA', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingWelcomeScreen(
          userId: 'user-1',
          onGetStarted: () {
            tapped = true;
          },
        ),
      ),
    );
    expect(find.text('Your creator journey starts here'), findsOneWidget);
    expect(
      find.textContaining('growth, AI, and community'),
      findsOneWidget,
    );
    expect(find.text('Get Started →'), findsOneWidget);
    await tester.tap(find.text('Get Started →'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('personalize screen always enables continue', (
    WidgetTester tester,
  ) async {
    ({List<String> goals, List<String> platforms})? continued;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPersonalizeScreen(
          initialGoals: const <String>[],
          initialPlatforms: const <String>[],
          onContinue: (({List<String> goals, List<String> platforms}) data) {
            continued = data;
          },
          onSkip: () {},
          onBack: () {},
        ),
      ),
    );
    expect(find.text('What\'s your creator focus?'), findsOneWidget);
    await tester.tap(
      find.text(
        'Continue → +${OnboardingV1Constants.personalizeRewardXp} XP',
      ),
    );
    await tester.pumpAndSettle();
    expect(continued, isNotNull);
    expect(continued!.goals, isEmpty);
  });

  testWidgets('personalize screen saves selected goals and platforms', (
    WidgetTester tester,
  ) async {
    ({List<String> goals, List<String> platforms})? continued;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPersonalizeScreen(
          initialGoals: const <String>[],
          initialPlatforms: const <String>[],
          onContinue: (({List<String> goals, List<String> platforms}) data) {
            continued = data;
          },
          onSkip: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.tap(find.text('Grow my audience'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twitch'));
    await tester.pumpAndSettle();
    expect(find.byType(BrandIcon), findsWidgets);
    await tester.tap(
      find.text(
        'Continue → +${OnboardingV1Constants.personalizeRewardXp} XP',
      ),
    );
    await tester.pumpAndSettle();
    expect(continued?.goals, contains('growth'));
    expect(continued?.platforms, contains('twitch'));
  });

  testWidgets('level unlock screen lists starter missions and enter CTA', (
    WidgetTester tester,
  ) async {
    bool entered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingLevelUnlockScreen(
          userId: 'user-1',
          onEnterApp: () {
            entered = true;
          },
          onBack: () {},
        ),
      ),
    );
    expect(find.text('Enter StreamersTip →'), findsOneWidget);
    for (final ({String id, String title, String emoji}) mission
        in OnboardingLevelOneMissions.starterMissions) {
      expect(find.text(mission.title), findsOneWidget);
    }
    await tester.tap(find.text('Enter StreamersTip →'));
    await tester.pump();
    expect(entered, isTrue);
  });
}
