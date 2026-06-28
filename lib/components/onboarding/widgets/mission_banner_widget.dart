import 'package:flutter/material.dart';

import '../../../features/gamification/models/daily_mission_model.dart';
import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';

class MissionBannerWidget extends StatelessWidget {
  const MissionBannerWidget({
    super.key,
    required this.missions,
    this.onDismiss,
    this.onViewAll,
    this.showDismiss = true,
  });

  final List<DailyMissionModel> missions;
  final VoidCallback? onDismiss;
  final VoidCallback? onViewAll;
  final bool showDismiss;

  bool _isMissionComplete(String slotId, List<DailyMissionModel> missions) {
    final Iterable<String> completedKeys = missions
        .where((DailyMissionModel mission) => mission.isCompleted)
        .map((DailyMissionModel mission) =>
            mission.templateId ?? mission.missionId);
    return OnboardingLevelOneMissions.isMissionComplete(
      missionId: slotId,
      creatorCardCompleted: true,
      completedMissionKeys: completedKeys,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = OnboardingStyle.isLight(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<({String id, String title, String emoji})> slots =
        OnboardingLevelOneMissions.starterMissions;
    final int completedCount = slots
        .where(
          (({String id, String title, String emoji}) slot) =>
              _isMissionComplete(slot.id, missions),
        )
        .length;
    final Color accent = isLight ? scheme.primary : const Color(0xFF00F5A0);
    final Color completeDot = isLight ? scheme.primary : const Color(0xFF00F5A0);
    final Color pendingDot =
        isLight ? scheme.outline : const Color(0xFF475569);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isLight
              ? <Color>[
                  scheme.primary.withValues(alpha: 0.14),
                  scheme.tertiary.withValues(alpha: 0.08),
                ]
              : <Color>[
                  const Color(0xFF6C47FF).withValues(alpha: 0.55),
                  const Color(0xFF00F5A0).withValues(alpha: 0.35),
                ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: isLight ? 0.08 : 0.22),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
        decoration: BoxDecoration(
          color: OnboardingStyle.surfaceFor(context),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: OnboardingStyle.borderFor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '🎯 Level 1 Missions',
                    style: TextStyle(
                      color: OnboardingStyle.textPrimaryFor(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '$completedCount / ${slots.length} complete',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (showDismiss && onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      Icons.close_rounded,
                      color: OnboardingStyle.textSecondaryFor(context),
                      size: 18,
                    ),
                    padding: const EdgeInsets.only(left: 4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...slots.asMap().entries.map(
              (MapEntry<int, ({String id, String title, String emoji})> entry) {
                final int index = entry.key;
                final ({String id, String title, String emoji}) slot =
                    entry.value;
                final bool isComplete =
                    _isMissionComplete(slot.id, missions);
                final int xpReward =
                    OnboardingLevelOneMissions.xpFor(slot.id);
                return Column(
                  children: <Widget>[
                    if (index > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: OnboardingStyle.borderFor(context),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isComplete ? completeDot : pendingDot,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            slot.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              slot.title,
                              style: TextStyle(
                                color: isComplete
                                    ? OnboardingStyle.textSecondaryFor(context)
                                    : OnboardingStyle.textPrimaryFor(context),
                                decoration: isComplete
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '+$xpReward XP',
                            style: TextStyle(
                              color: isComplete
                                  ? OnboardingStyle.textSecondaryFor(context)
                                      .withValues(alpha: 0.55)
                                  : OnboardingStyle.textSecondaryFor(context),
                              decoration: isComplete
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  backgroundColor: isLight
                      ? scheme.primary.withValues(alpha: 0.10)
                      : const Color(0xFF9248D2).withValues(alpha: 0.22),
                  foregroundColor:
                      isLight ? scheme.primary : const Color(0xFFB794F6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: isLight
                          ? scheme.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  'View all missions →',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isLight ? scheme.primary : const Color(0xFFB794F6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
