import 'package:flutter/material.dart';

import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/email_verification_banner.dart';
import '../widgets/onboarding_app_logo.dart';
import '../widgets/onboarding_full_screen_shell.dart';
import '../widgets/onboarding_progress_header.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({
    super.key,
    required this.userId,
    required this.onGetStarted,
    this.emailBannerDismissed = false,
    this.showEmailBanner = false,
    this.email = '',
  });

  final String userId;
  final VoidCallback onGetStarted;
  final bool emailBannerDismissed;
  final bool showEmailBanner;
  final String email;

  @override
  Widget build(BuildContext context) {
    final bool shouldShowBanner =
        showEmailBanner && !emailBannerDismissed && email.isNotEmpty;
    return OnboardingScreenLayout(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF1A1033),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          if (shouldShowBanner)
            EmailVerificationBanner(
              userId: userId,
              email: email,
            ),
          const OnboardingProgressHeader(
            step: 1,
            totalSteps: OnboardingV1Constants.totalSteps,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const OnboardingAppLogo(size: 112),
                  const SizedBox(height: 24),
                  Text(
                    'WELCOME',
                    style: OnboardingStyle.plainTextStyle(
                      TextStyle(
                        color: const Color(0xFF9248D2).withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your creator journey starts here',
                    textAlign: TextAlign.center,
                    style: OnboardingStyle.plainTextStyle(
                      TextStyle(
                        color: OnboardingStyle.textPrimaryFor(context),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'StreamersTip brings your entire creator life into one '
                    'place — growth, AI, and community.',
                    textAlign: TextAlign.center,
                    style: OnboardingStyle.bodyFor(context, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: SizedBox(
              width: double.infinity,
              child: GradientPillButton(
                label: 'Get Started →',
                useSolidPurple: true,
                onPressed: onGetStarted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
