import 'package:flutter/material.dart';

import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_progress_header.dart';

class OnboardingLevelUnlockScreen extends StatelessWidget {
  const OnboardingLevelUnlockScreen({
    super.key,
    required this.onEnterApp,
    required this.onBack,
    this.isLoading = false,
  });

  final VoidCallback onEnterApp;
  final VoidCallback onBack;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1A1033),
            Color(0xFF0F172A),
            Color(0xFF162447),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            OnboardingProgressHeader(
              step: 5,
              totalSteps: OnboardingV1Constants.totalSteps,
              showBack: true,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: OnboardingStyle.primaryGradient,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color:
                                const Color(0xFF9248D2).withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Level 1: Getting Started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingStyle.textPrimaryFor(context),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your starter missions are ready. Complete them to '
                      'level up fast.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingStyle.textSecondaryFor(context),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF58CC02).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF58CC02).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '+${OnboardingV1Constants.levelOneUnlockRewardXp} XP reward',
                        style: const TextStyle(
                          color: Color(0xFF58CC02),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...OnboardingLevelOneMissions.starterMissions.map(
                      (({String title, String emoji}) mission) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: OnboardingStyle.surfaceFor(context)
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: OnboardingStyle.borderFor(context),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  mission.emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    mission.title,
                                    style: TextStyle(
                                      color: OnboardingStyle.textPrimaryFor(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.lock_open_rounded,
                                  color: OnboardingStyle.textSecondaryFor(
                                    context,
                                  ),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                  label: isLoading ? 'Loading...' : 'Enter StreamersTip',
                  icon: Icons.rocket_launch_rounded,
                  onPressed: isLoading ? null : onEnterApp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
