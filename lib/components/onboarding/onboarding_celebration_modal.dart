import 'package:flutter/material.dart';

import 'onboarding_models.dart';
import 'onboarding_style.dart';

class OnboardingCelebrationModal extends StatelessWidget {
  const OnboardingCelebrationModal({
    super.key,
    required this.mission,
    required this.onClose,
    this.nextMission,
  });

  final OnboardingMission mission;
  final OnboardingMission? nextMission;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('onboarding-celebration-modal'),
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          width: MediaQuery.sizeOf(context).width.clamp(0, 380).toDouble(),
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(22),
          decoration: OnboardingStyle.cardDecoration(context: context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFBBF24),
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                'Mission Complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textPrimaryFor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You earned ${mission.reward} for ${mission.title.toLowerCase()}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  height: 1.35,
                ),
              ),
              if (nextMission != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Next Mission: ${nextMission!.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7DD3FC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GradientPillButton(
                label: 'Keep Leveling Up',
                icon: Icons.bolt_rounded,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
