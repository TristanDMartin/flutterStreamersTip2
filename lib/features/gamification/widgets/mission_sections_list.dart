import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../missions/mission_engine.dart';
import '../models/daily_mission_model.dart';

/// Grouped daily / weekly / onboarding missions with completion states.
class MissionSectionsList extends StatelessWidget {
  final List<MissionSection> sections;

  const MissionSectionsList({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          'No missions available yet. Check back after your next creator activity.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections.expand((MissionSection s) {
        return <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              s.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...s.missions.map(_MissionTile.new),
        ];
      }).toList(),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final DailyMissionModel mission;

  const _MissionTile(this.mission);

  @override
  Widget build(BuildContext context) {
    final bool done = mission.isCompleted;
    final bool claimed = mission.isClaimed;
    final String stateLabel = claimed
        ? 'Claimed'
        : done
            ? 'Completed'
            : '${mission.progress} of ${mission.target} progress';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: '${mission.title}. $stateLabel',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.065),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: done
                  ? Colors.greenAccent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      mission.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (claimed)
                    _MissionStatusChip(
                      label: 'Claimed',
                      color: Colors.greenAccent.withValues(alpha: 0.9),
                    )
                  else if (done)
                    _MissionStatusChip(
                      label: 'Done',
                      color: Colors.greenAccent.withValues(alpha: 0.85),
                    )
                  else
                    _MissionStatusChip(
                      label: '+${mission.rewardXp} XP',
                      color: AppColors.supportAccent.withValues(alpha: 0.95),
                    ),
                ],
              ),
              if (mission.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  mission.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: mission.completionPercent.clamp(0, 1),
                  minHeight: 7,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    claimed
                        ? Colors.white24
                        : done
                            ? Colors.greenAccent.withValues(alpha: 0.75)
                            : AppColors.supportAccent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${mission.progress} / ${mission.target} · ${mission.status}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MissionStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
