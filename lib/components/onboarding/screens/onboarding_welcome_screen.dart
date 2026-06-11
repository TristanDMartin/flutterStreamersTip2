import 'package:flutter/material.dart';

import '../onboarding_style.dart';
import '../widgets/onboarding_app_logo.dart';
import '../widgets/onboarding_progress_header.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({
    super.key,
    required this.onGetStarted,
  });

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const OnboardingProgressHeader(step: 1, totalSteps: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const OnboardingAppLogo(size: 120),
                    const SizedBox(height: 36),
                    Text(
                      'Welcome to StreamersTip',
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
                      'A platform built to help creators grow, connect, '
                      'share content, and turn consistency into momentum.',
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
                  label: 'Get Started',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onGetStarted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
