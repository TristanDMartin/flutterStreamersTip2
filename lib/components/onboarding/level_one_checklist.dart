import 'package:flutter/material.dart';

import 'onboarding_models.dart';
import 'onboarding_style.dart';

class LevelOneChecklist extends StatelessWidget {
  const LevelOneChecklist({
    super.key,
    required this.state,
    required this.onMissionTap,
    this.compact = false,
  });

  final OnboardingState state;
  final ValueChanged<OnboardingMission> onMissionTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final int complete = state.completedMissionCount;
    final Size size = MediaQuery.sizeOf(context);
    final bool isCompact = compact || size.width < 380 || size.height < 720;
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    final Color textSecondary = OnboardingStyle.textSecondaryFor(context);
    final Color border = OnboardingStyle.borderFor(context);
    return Container(
      key: const Key('level-one-checklist'),
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        isCompact ? 12 : 14,
        isCompact ? 12 : 16,
        isCompact ? 12 : 16,
      ),
      decoration: OnboardingStyle.cardDecoration(context: context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Level 1: Getting Started',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$complete/${levelOneMissions.length}',
                style: const TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: state.levelOneProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4897D2)),
            ),
          ),
          const SizedBox(height: 10),
          ...levelOneMissions.map((OnboardingMission mission) {
            final bool done = state.completedMissions.contains(mission.id);
            return _MissionRow(
              key: _missionKey(mission.id),
              mission: mission,
              done: done,
              compact: isCompact,
              onTap: () => onMissionTap(mission),
            );
          }),
          if (!compact) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OnboardingStyle.isLight(context)
                    ? const Color(0xFFF8FAFC)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Text(
                'Reward: Unlock Rising Creator status',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Key _missionKey(String id) {
    switch (id) {
      case 'complete_profile':
        return const Key('onboarding-mission-complete-profile');
      case 'upload_first_post':
        return const Key('onboarding-mission-upload-first-post');
      default:
        return Key('onboarding-mission-$id');
    }
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    super.key,
    required this.mission,
    required this.done,
    required this.compact,
    required this.onTap,
  });

  final OnboardingMission mission;
  final bool done;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: done ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: done ? const Color(0xFF22C55E) : Colors.white54,
                size: compact ? 21 : 24,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    mission.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: done
                          ? OnboardingStyle.textPrimaryFor(context)
                          : OnboardingStyle.textSecondaryFor(context),
                      fontSize: compact ? 12.5 : 13,
                      fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      mission.reward,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  mission.reward,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7DD3FC),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
