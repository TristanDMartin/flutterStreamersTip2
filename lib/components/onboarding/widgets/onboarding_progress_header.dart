import 'package:flutter/material.dart';

import '../onboarding_style.dart';

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
    final double progress = (step / totalSteps).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: OnboardingStyle.textPrimaryFor(context),
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor:
                        OnboardingStyle.borderFor(context).withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF9248D2),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$step/$totalSteps',
            style: TextStyle(
              color: OnboardingStyle.textSecondaryFor(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
