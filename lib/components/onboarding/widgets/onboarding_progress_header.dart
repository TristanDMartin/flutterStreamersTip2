import 'package:flutter/material.dart';

import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';

class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    this.showBack = false,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final int earnedXp = OnboardingV1Constants.earnedXpForDisplayStep(step);
    final double xpProgress =
        (earnedXp / OnboardingV1Constants.maxOnboardingXp).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showBack)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: OnboardingStyle.textPrimaryFor(context),
                      size: 22,
                    ),
                  ),
                ),
              Text(
                'XP',
                style: OnboardingStyle.plainTextStyle(
                  TextStyle(
                    color: OnboardingStyle.textSecondaryFor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$earnedXp XP',
                style: OnboardingStyle.plainTextStyle(
                  const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 3,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: xpProgress <= 0 ? 0.04 : xpProgress,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Color(0xFF9248D2),
                            Color(0xFF10B981),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(totalSteps, (int index) {
              final int dotStep = index + 1;
              final bool isComplete = dotStep < step;
              final bool isCurrent = dotStep == step;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: isCurrent ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isCurrent
                        ? const Color(0xFF9248D2)
                        : isComplete
                            ? const Color(0xFF10B981)
                            : const Color(0xFF334155),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
