import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/account_navigation.dart';
import 'package:streamers_tip/components/onboarding/activation_state.dart';
import 'package:streamers_tip/components/onboarding/resolve_onboarding_destination.dart';

void main() {
  final Map<String, dynamic> golden = jsonDecode(
    File('test/fixtures/onboarding-lifecycle.golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final List<dynamic> vectors = golden['vectors'] as List<dynamic>;

  group('onboarding lifecycle golden vectors', () {
    for (final dynamic raw in vectors) {
      final Map<String, dynamic> vector = raw as Map<String, dynamic>;
      test(vector['id'] as String, () {
        final Map<String, dynamic> input =
            vector['input'] as Map<String, dynamic>;
        final Map<String, dynamic> expected =
            vector['expected'] as Map<String, dynamic>;
        final OnboardingDestination destination = resolveOnboardingDestination(
          userData: input['userData'] is Map
              ? Map<String, dynamic>.from(input['userData'] as Map)
              : null,
          emailVerified: input['emailVerified'] == true,
          isPasswordProvider: input['isPasswordProvider'] == true,
          localTippyStage: input['localTippyStage'] as String?,
        );
        expect(destination.lifecycle, expected['lifecycle']);
        expect(destination.tippyStageHint, expected['tippyStageHint']);
        expect(destination.allowApp, expected['allowApp']);
        expect(destination.reason, expected['reason']);

        final ActivationDecision activation = resolveActivationState(
          isAuthenticated: input['isAuthenticated'] == true,
          destination: destination,
          hasFirstGrowthPlan: input['hasFirstGrowthPlan'] == true,
          firstMissionChoice: input['firstMissionChoice'] as String?,
        );
        expect(activation.state, expected['activationState']);
        expect(activation.allowApp, expected['allowApp']);
        expect(activation.tippyStageHint, expected['tippyStageHint']);

        final AccountNavigation nav = navigationFromAccountStatus(
          activationState: activation.state,
          activationReason: activation.reason,
          tippyStageHint: activation.tippyStageHint,
          allowApp: activation.allowApp,
        );
        if (activation.state == 'ACTIVATED') {
          expect(nav.route, 'app');
        }
        if (activation.state == 'EMAIL_VERIFICATION_REQUIRED') {
          expect(nav.route, 'verify-email');
        }
        if (activation.state == 'CREATOR_IDENTITY') {
          expect(nav.route, 'onboarding');
          expect(nav.tippyStageHint, isNot('welcome'));
        }
        if (activation.state == 'GUEST_PERSONALIZATION' &&
            activation.reason == 'identity_recycled_restart') {
          expect(nav.tippyStageHint, 'welcome');
        }
      });
    }
  });
}
