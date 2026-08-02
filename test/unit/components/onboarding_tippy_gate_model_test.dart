import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/onboarding_models.dart';
import 'package:streamers_tip/components/onboarding/onboarding_v1_constants.dart';

void main() {
  group('OnboardingState Tippy gate ownership', () {
    test('Tippy attached without landing stays incomplete for classic gate', () {
      final OnboardingState actualX = OnboardingState.fromUserMap(
        <String, dynamic>{
          'username': 'provisional',
          'displayName': 'Provisional',
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'completed': false,
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': false,
            'essentialProfileComplete': false,
          },
        },
      );
      expect(actualX.isTippyPathActive, isTrue);
      expect(actualX.isTippyFunnelIncomplete, isTrue);
      expect(actualX.completed, isFalse);
    });

    test('landing without essential profile still owns Tippy over classic', () {
      final OnboardingState actualX = OnboardingState.fromUserMap(
        <String, dynamic>{
          'username': '',
          'displayName': '',
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'completed': false,
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': true,
            'landingChoice': 'explore',
            'essentialProfileComplete': false,
          },
        },
      );
      expect(actualX.isTippyFunnelIncomplete, isTrue);
      expect(actualX.completed, isFalse);
    });

    test('Tippy path fully done is not incomplete', () {
      final OnboardingState actualX = OnboardingState.fromUserMap(
        <String, dynamic>{
          'username': 'creator',
          'displayName': 'Creator',
          'onboarding': <String, dynamic>{
            'version': OnboardingV1Constants.version,
            'completed': true,
            'tippyOnboardingV1Attached': true,
            'slim7Completed': true,
            'tippyFunnelCompleted': true,
            'essentialProfileComplete': true,
            'creatorCardCompleted': true,
          },
        },
      );
      expect(actualX.isTippyFunnelIncomplete, isFalse);
      expect(actualX.completed, isTrue);
    });
  });
}
