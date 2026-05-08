import 'package:flutter/material.dart';

import '../../../core/theme/support_shell_style.dart';
import '../services/gamification_event_service.dart';
import '../missions/mission_engine.dart';
import '../models/daily_mission_model.dart';

/// Grouped daily / weekly / onboarding missions with compact, game-like states.
class MissionSectionsList extends StatelessWidget {
  final List<MissionSection> sections;
  final Future<void> Function()? onRefreshRequested;

  const MissionSectionsList({
    super.key,
    required this.sections,
    this.onRefreshRequested,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    if (sections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: Text(
          'No missions available yet. Check back after your next creator activity.',
          style: TextStyle(
            color: shell.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections.map((MissionSection section) {
        final int completed = section.missions
            .where((DailyMissionModel mission) => mission.isCompleted)
            .length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: shell.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: shell.surfaceCardBorder),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: shell.shadowSoft,
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        section.title,
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: shell.chipUnselectedBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: shell.surfaceCardBorder,
                        ),
                      ),
                      child: Text(
                        '$completed/${section.missions.length}',
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...section.missions.map(
                  (DailyMissionModel mission) => _MissionTile(
                    mission,
                    onRefreshRequested: onRefreshRequested,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final DailyMissionModel mission;
  final Future<void> Function()? onRefreshRequested;

  const _MissionTile(this.mission, {this.onRefreshRequested});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool done = mission.isCompleted;
    final bool claimed = mission.isClaimed;
    final Color accent = claimed
        ? shell.muted
        : done
            ? Colors.greenAccent.withValues(alpha: 0.9)
            : scheme.primary;
    final IconData icon = claimed
        ? Icons.check_circle_rounded
        : done
            ? Icons.workspace_premium_rounded
            : Icons.flash_on_rounded;
    final String progressLabel = mission.target <= 0
        ? '${mission.progress}'
        : '${mission.progress}/${mission.target}';
    final bool readyToClaim = done && !claimed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: '${mission.title}. $progressLabel progress.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMissionSheet(
              context,
              mission,
              readyToClaim,
              onRefreshRequested,
            ),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: shell.surfaceCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: done
                      ? accent.withValues(alpha: 0.32)
                      : shell.surfaceCardBorder,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: <Color>[
                          accent.withValues(alpha: 0.9),
                          accent.withValues(alpha: 0.28),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                mission.title,
                                style: TextStyle(
                                  color: shell.onChrome,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MissionStatusChip(
                              label: claimed
                                  ? 'Claimed'
                                  : done
                                      ? 'Done'
                                      : '+${mission.rewardXp} XP',
                              color: accent,
                            ),
                          ],
                        ),
                        if (mission.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            mission.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: shell.muted,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: mission.completionPercent
                                        .clamp(0.0, 1.0),
                                  ),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return LinearProgressIndicator(
                                      value: value,
                                      minHeight: 6,
                                      backgroundColor: scheme.onSurface
                                          .withValues(alpha: 0.12),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(accent),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              progressLabel,
                              style: TextStyle(
                                color: shell.onChrome.withValues(alpha: 0.78),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (readyToClaim) ...<Widget>[
                          const SizedBox(height: 8),
                          _ClaimAffordanceChip(accent: accent),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showMissionSheet(
    BuildContext context,
    DailyMissionModel mission,
    bool readyToClaim,
    Future<void> Function()? onRefreshRequested,
  ) {
    final Color accent = readyToClaim
        ? Colors.greenAccent
        : mission.isClaimed
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)
            : Theme.of(context).colorScheme.primary;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _MissionSheet(
          mission: mission,
          accent: accent,
          readyToClaim: readyToClaim,
          onRefreshRequested: onRefreshRequested,
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ClaimAffordanceChip extends StatefulWidget {
  final Color accent;

  const _ClaimAffordanceChip({required this.accent});

  @override
  State<_ClaimAffordanceChip> createState() => _ClaimAffordanceChipState();
}

class _ClaimAffordanceChipState extends State<_ClaimAffordanceChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double glow = 0.14 + (_controller.value * 0.08);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.accent
                  .withValues(alpha: 0.26 + (_controller.value * 0.16)),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.accent.withValues(alpha: glow),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.redeem_rounded,
                size: 14,
                color: widget.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Ready to claim',
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MissionSheet extends StatelessWidget {
  final DailyMissionModel mission;
  final Color accent;
  final bool readyToClaim;
  final Future<void> Function()? onRefreshRequested;

  const _MissionSheet({
    required this.mission,
    required this.accent,
    required this.readyToClaim,
    required this.onRefreshRequested,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final String progressLabel = mission.target <= 0
        ? '${mission.progress}'
        : '${mission.progress}/${mission.target}';
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: isLight ? scheme.surface : const Color(0xFF1A1440),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight
                ? scheme.outline.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              mission.title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mission.description.isEmpty
                  ? 'Keep progressing this mission to move your creator track forward.'
                  : mission.description,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _MissionSheetRow(label: 'Progress', value: progressLabel),
            _MissionSheetRow(label: 'Reward', value: '+${mission.rewardXp} XP'),
            _MissionSheetRow(label: 'Status', value: mission.status),
            const SizedBox(height: 10),
            if (readyToClaim)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final NavigatorState navigator = Navigator.of(context);
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    navigator.pop();
                    try {
                      final Map<String, dynamic> result =
                          await GamificationEventService().claimMissionReward(
                        missionId: mission.missionId,
                      );
                      if (onRefreshRequested != null) {
                        await onRefreshRequested!();
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            result['alreadyClaimed'] == true
                                ? 'Mission reward was already claimed.'
                                : 'Mission claimed. +${result['xpGranted'] ?? mission.rewardXp} XP added.',
                          ),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Bad state: ', ''),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.redeem_rounded),
                  label: const Text('Claim reward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  mission.isClaimed
                      ? 'This reward has already been collected.'
                      : 'Complete the objective to unlock claiming.',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MissionSheetRow extends StatelessWidget {
  final String label;
  final String value;

  const _MissionSheetRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
