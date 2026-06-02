import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/gamification/gamification_providers.dart';
import 'onboarding_models.dart';
import 'onboarding_style.dart';

class OnboardingProgressCard extends ConsumerWidget {
  const OnboardingProgressCard({
    super.key,
    required this.state,
    required this.onOpenChecklist,
    required this.onNextMission,
  });

  final OnboardingState state;
  final VoidCallback onOpenChecklist;
  final ValueChanged<OnboardingMission> onNextMission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingMission? next = state.nextMission;
    final int displayLevel = ref.watch(userProgressBundleProvider).maybeWhen(
          data: (bundle) => bundle.progress.level,
          orElse: () => levelForXp(state.xp),
        );
    final bool light = OnboardingStyle.isLight(context);
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    final Color textSecondary = OnboardingStyle.textSecondaryFor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: next == null ? onOpenChecklist : () => onNextMission(next),
        onLongPress: onOpenChecklist,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: 0.92)
                : OnboardingStyle.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: OnboardingStyle.borderFor(context)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: state.levelOneProgress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF4897D2)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Lv $displayLevel · ${state.completedMissionCount}/${visibleLevelOneMissions.length}',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
