import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/support_shell_style.dart';
import '../gamification_providers.dart';
import '../models/gamification_summary_model.dart';
import '../missions/mission_engine.dart';
import '../models/user_progress_bundle.dart';
import '../utils/gamification_constants.dart';
import 'mission_sections_list.dart';
import 'tier_badge_strip.dart';

/// Home "Progression" tab: creator progress, plan, missions (read-only Firestore).
class CreatorProgressionPanel extends ConsumerWidget {
  const CreatorProgressionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ColoredBox(
        color: shell.scaffold,
        child: const _SignedOutMessage(),
      );
    }
    final AsyncValue<UserProgressBundle> asyncBundle =
        ref.watch(userProgressBundleProvider);
    final Widget body = asyncBundle.when(
      data: (UserProgressBundle bundle) => _ProgressionBody(
        bundle: bundle,
        uid: user.uid,
        onRefresh: () async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.server));
          ref.invalidate(userProgressBundleProvider);
        },
      ),
      loading: () => const _LoadingOrEmpty(loading: true),
      error: (Object e, StackTrace st) {
        debugPrint('userProgressBundleProvider: $e\n$st');
        return Builder(
          builder: (BuildContext context) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'Could not load progression. Pull to refresh or try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return ColoredBox(color: shell.scaffold, child: body);
  }
}

class _ProgressionBody extends StatelessWidget {
  final UserProgressBundle bundle;
  final String uid;
  final Future<void> Function() onRefresh;

  const _ProgressionBody({
    required this.bundle,
    required this.uid,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GamificationSummaryModel model = bundle.progress;
    final String rankTitle =
        GamificationConstants.rankTitleForLevel(model.level);
    final bool hasMissions = bundle.missions.isNotEmpty;
    final bool hasHint =
        model.nextActionHint != null && model.nextActionHint!.isNotEmpty;
    return RefreshIndicator(
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 60,
          20,
          120,
        ),
        children: <Widget>[
          _HeroHeader(
            level: model.level,
            rankTitle: rankTitle,
            creatorScore: model.creatorScore,
            streakDays: model.streakDays,
          ),
          const SizedBox(height: 18),
          TierBadgeStrip(subscription: bundle.subscription),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Level progress',
            subtitle: 'Track your XP, streak, and creator momentum.',
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Level ${model.level}, $rankTitle, ${model.totalXp} total XP',
            child: _LevelCard(
              model: model,
              onTap: () => _showLevelRewardsSheet(context, model),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orangeAccent.withValues(alpha: 0.95),
                  title: 'Streak',
                  value: model.streakDays > 0
                      ? '${model.streakDays} days'
                      : 'Start today',
                  helper: model.streakDays > 0
                      ? 'Keep your momentum going'
                      : 'Complete activity to begin',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: scheme.primary.withValues(alpha: 0.95),
                  title: 'Creator score',
                  value: model.creatorScore.toStringAsFixed(1),
                  helper: 'Based on your recent activity',
                ),
              ),
            ],
          ),
          if (hasHint) ...<Widget>[
            const SizedBox(height: 18),
            _NextActionCard(hint: model.nextActionHint!),
          ],
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Missions',
            subtitle: hasMissions
                ? '${bundle.missions.length} active mission entr${bundle.missions.length == 1 ? 'y' : 'ies'} synced to your profile.'
                : 'Mission tracks will appear here as your progression syncs.',
          ),
          const SizedBox(height: 12),
          MissionSectionsList(
            sections: MissionEngine.resolveSections(
              bundle,
              uid,
              DateTime.now(),
            ),
            onRefreshRequested: onRefresh,
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Achievements',
            subtitle: 'Unlocked milestones, current pushes, and next wins.',
          ),
          const SizedBox(height: 12),
          _AchievementsSection(bundle: bundle),
        ],
      ),
    );
  }

  static Future<void> _showLevelRewardsSheet(
    BuildContext context,
    GamificationSummaryModel model,
  ) {
    final int maxLevel = GamificationConstants.maxConfiguredLevel();
    final int startLevel = model.level.clamp(1, maxLevel);
    final int endLevel = (startLevel + 4).clamp(1, maxLevel);
    final List<int> levels = <int>[
      for (int level = startLevel; level <= endLevel; level++) level,
    ];
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return _GlassSheet(
          title: 'Level rewards ladder',
          subtitle: 'See what your next creator milestones unlock.',
          child: Column(
            children: levels.map((int level) {
              final bool current = level == model.level;
              final bool completed = level < model.level;
              final String reward =
                  GamificationConstants.rewardLabelForLevel(level);
              final Color rowBg = scheme.surfaceContainerLow.withValues(
                alpha: current ? 1.0 : 0.72,
              );
              final Color rowBorder = current
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.outline.withValues(alpha: 0.28);
              final List<Color> orbColors = completed
                  ? <Color>[
                      Colors.greenAccent.withValues(alpha: 0.85),
                      scheme.primary.withValues(alpha: 0.35),
                    ]
                  : current
                      ? <Color>[
                          scheme.primary,
                          scheme.secondary.withValues(alpha: 0.55),
                        ]
                      : <Color>[
                          scheme.outline.withValues(alpha: 0.45),
                          scheme.surfaceContainerHighest,
                        ];
              final Color levelNumColor =
                  completed || current ? scheme.onPrimary : scheme.onSurface;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: rowBorder),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: orbColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$level',
                            style: TextStyle(
                              color: levelNumColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              GamificationConstants.rankTitleForLevel(level),
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reward,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.62),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        completed
                            ? 'Earned'
                            : current
                                ? 'Current'
                                : '${GamificationConstants.xpFloorForLevel(level)} XP',
                        style: TextStyle(
                          color: completed
                              ? Colors.greenAccent
                              : current
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final int level;
  final String rankTitle;
  final double creatorScore;
  final int streakDays;

  const _HeroHeader({
    required this.level,
    required this.rankTitle,
    required this.creatorScore,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.heroGradient,
        ),
        border: Border.all(color: shell.heroBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.shadowSoft,
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: shell.chipUnselectedBorder),
            ),
            child: Text(
              'Creator Progression',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rankTitle,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level $level · Score ${creatorScore.toStringAsFixed(1)} · ${streakDays > 0 ? '$streakDays day streak' : 'Build your first streak'}',
            style: TextStyle(
              color: shell.muted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: shell.mutedStrong,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SignedOutMessage extends StatelessWidget {
  const _SignedOutMessage();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sign in to track creator progression.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

class _LoadingOrEmpty extends StatelessWidget {
  final bool loading;
  const _LoadingOrEmpty({required this.loading});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: loading
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: shell.skeletonFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: shell.surfaceCardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 14),
                  Text(
                    'Loading your progression...',
                    style: TextStyle(color: shell.muted),
                  ),
                ],
              ),
            )
          : Text(
              'No profile data',
              style: TextStyle(color: shell.mutedStrong),
            ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final GamificationSummaryModel model;
  final VoidCallback onTap;
  const _LevelCard({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String rankTitle =
        GamificationConstants.rankTitleForLevel(model.level);
    final int need = model.xpNeededForNextLevel;
    final int safeNeed = need <= 0 ? 1 : need;
    final int into = model.xpIntoLevel.clamp(0, safeNeed);
    final BoxDecoration outerDecoration = shell.isLight
        ? BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: shell.surfaceCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                scheme.primary.withValues(alpha: 0.22),
                scheme.surfaceContainerHighest.withValues(alpha: 0.75),
              ],
            ),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.38),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          );
    final BoxDecoration orbDecoration = shell.isLight
        ? BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                shell.glassCircleGradientStart,
                shell.glassCircleGradientEnd,
              ],
            ),
            border: Border.all(color: shell.glassCircleBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                scheme.primary.withValues(alpha: 0.32),
                scheme.surfaceContainerHighest.withValues(alpha: 0.85),
              ],
            ),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          );
    final Color levelTextColor = scheme.onSurface;
    final Color trackBg = shell.isLight
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.9)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final Color trackFg = scheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: outerDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: orbDecoration,
                    child: Center(
                      child: Text(
                        '${model.level}',
                        style: TextStyle(
                          color: levelTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          rankTitle,
                          style: TextStyle(
                            color: shell.onChrome,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${model.totalXp} total XP',
                          style: TextStyle(
                            color: shell.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: shell.chipUnselectedBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: shell.chipUnselectedBorder,
                            ),
                          ),
                          child: Text(
                            '${(model.progressInLevel * 100).round()}% to next level',
                            style: TextStyle(
                              color: shell.chipUnselectedFg,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: model.progressInLevel.clamp(0, 1),
                  ),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext ctx, double value, Widget? _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: trackBg,
                      valueColor: AlwaysStoppedAnimation<Color>(trackFg),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '$into / $safeNeed XP this level',
                      style: TextStyle(
                        color: shell.mutedStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'View rewards',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String helper;

  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: shell.mutedStrong,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(
              color: shell.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final String hint;
  const _NextActionCard({required this.hint});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Next step',
            style: TextStyle(
              color: shell.mutedStrong,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  final UserProgressBundle bundle;

  const _AchievementsSection({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final GamificationSummaryModel progress = bundle.progress;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int completedMissions =
        bundle.missions.where((mission) => mission.isCompleted).length;
    final List<_AchievementState> achievements = <_AchievementState>[
      _AchievementState(
        title: 'Momentum starter',
        subtitle: progress.level > 1
            ? 'You pushed past the opening tier.'
            : 'Reach level 2 to secure your first progression badge.',
        value: progress.level > 1 ? 'Unlocked' : 'Level ${progress.level}/2',
        nextStep: 'Keep earning XP through posting and mission progress.',
        icon: Icons.rocket_launch_rounded,
        accent: Colors.orangeAccent,
        unlocked: progress.level > 1,
      ),
      _AchievementState(
        title: 'Streak builder',
        subtitle: progress.streakDays >= 3
            ? 'Your creator rhythm is holding strong.'
            : 'String together 3 active days to light this badge up.',
        value: progress.streakDays >= 3
            ? '${progress.streakDays} day streak'
            : '${progress.streakDays}/3 days',
        nextStep: 'Stay active on consecutive days to grow your streak.',
        icon: Icons.local_fire_department_rounded,
        accent: scheme.primary,
        unlocked: progress.streakDays >= 3,
      ),
      _AchievementState(
        title: 'Mission runner',
        subtitle: completedMissions > 0
            ? 'You have real clears on the board.'
            : 'Complete your first mission to activate this milestone.',
        value: completedMissions > 0
            ? '$completedMissions cleared'
            : '${bundle.missions.length} queued',
        nextStep: 'Open a mission and finish one active objective.',
        icon: Icons.military_tech_rounded,
        accent: Colors.greenAccent,
        unlocked: completedMissions > 0,
      ),
    ];
    return Column(
      children: achievements
          .map((achievement) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AchievementCard(achievement: achievement),
              ))
          .toList(),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final _AchievementState achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color accent =
        achievement.unlocked ? achievement.accent : shell.iconDim;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.97, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAchievementSheet(context, achievement),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: shell.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: achievement.unlocked
                    ? accent.withValues(alpha: 0.26)
                    : shell.surfaceCardBorder,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: achievement.unlocked
                      ? accent.withValues(alpha: 0.12)
                      : shell.shadowSoft,
                  blurRadius: achievement.unlocked ? 22 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                _AchievementOrb(
                  accent: accent,
                  icon: achievement.icon,
                  unlocked: achievement.unlocked,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              achievement.title,
                              style: TextStyle(
                                color: shell.onChrome,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Text(
                              achievement.value,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.subtitle,
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showAchievementSheet(
    BuildContext context,
    _AchievementState achievement,
  ) {
    final String statusCopy = achievement.unlocked
        ? 'Unlocked and currently active on your creator profile.'
        : 'Still in progress. Keep pushing this track to unlock it.';
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return _GlassSheet(
          title: achievement.title,
          subtitle: statusCopy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: achievement.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    _AchievementOrb(
                      accent: achievement.accent,
                      icon: achievement.icon,
                      unlocked: achievement.unlocked,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        achievement.subtitle,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.76),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SheetFactRow(label: 'Status', value: achievement.value),
              _SheetFactRow(
                label: 'Next move',
                value: achievement.unlocked
                    ? 'Keep stacking progress to unlock higher-tier milestones.'
                    : achievement.nextStep,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementOrb extends StatefulWidget {
  final Color accent;
  final IconData icon;
  final bool unlocked;

  const _AchievementOrb({
    required this.accent,
    required this.icon,
    required this.unlocked,
  });

  @override
  State<_AchievementOrb> createState() => _AchievementOrbState();
}

class _AchievementOrbState extends State<_AchievementOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    if (widget.unlocked) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AchievementOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unlocked && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.unlocked && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
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
        final double pulse =
            widget.unlocked ? (0.88 + (_controller.value * 0.2)) : 0.55;
        return Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                widget.accent.withValues(alpha: pulse),
                widget.accent.withValues(alpha: 0.18),
              ],
            ),
            boxShadow: <BoxShadow>[
              if (widget.unlocked)
                BoxShadow(
                  color: widget.accent.withValues(
                    alpha: 0.22 + (_controller.value * 0.1),
                  ),
                  blurRadius: 18 + (_controller.value * 6),
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: child,
        );
      },
      child: Icon(
        widget.icon,
        color: widget.unlocked
            ? Colors.white
            : StSupportShellStyle.of(context).onChrome.withValues(
                  alpha: 0.45,
                ),
        size: 22,
      ),
    );
  }
}

class _AchievementState {
  final String title;
  final String subtitle;
  final String value;
  final String nextStep;
  final IconData icon;
  final Color accent;
  final bool unlocked;

  const _AchievementState({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.nextStep,
    required this.icon,
    required this.accent,
    required this.unlocked,
  });
}

class _GlassSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _GlassSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: shell.panelSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: shell.panelBorder),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: shell.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetFactRow extends StatelessWidget {
  final String label;
  final String value;

  const _SheetFactRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                color: shell.mutedStrong,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: shell.onChrome.withValues(alpha: 0.88),
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
