import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/app_colors.dart';
import '../gamification_providers.dart';
import '../models/gamification_summary_model.dart';
import '../missions/mission_engine.dart';
import '../models/usage_metrics_model.dart';
import '../models/user_entitlements_model.dart';
import '../models/user_progress_bundle.dart';
import 'mission_sections_list.dart';
import 'tier_badge_strip.dart';

/// Home "Progression" tab: creator progress, plan, missions (read-only Firestore).
class CreatorProgressionPanel extends ConsumerWidget {
  const CreatorProgressionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _SignedOutMessage();
    }
    final AsyncValue<UserProgressBundle> asyncBundle =
        ref.watch(userProgressBundleProvider);
    return asyncBundle.when(
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Could not load progression. Pull to refresh or try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
      },
    );
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
    final GamificationSummaryModel model = bundle.progress;
    final bool hasMissions = bundle.missions.isNotEmpty;
    final bool hasHint =
        model.nextActionHint != null && model.nextActionHint!.isNotEmpty;
    return RefreshIndicator(
      color: AppColors.supportAccent,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 72,
          20,
          120,
        ),
        children: <Widget>[
          _HeroHeader(
            level: model.level,
            rankTitle: model.rankTitle,
            creatorScore: model.creatorScore,
            streakDays: model.streakDays,
          ),
          const SizedBox(height: 18),
          TierBadgeStrip(subscription: bundle.subscription),
          const SizedBox(height: 14),
          _InfoCard(
            title: 'Unlocked tools',
            subtitle: 'Your plan perks and current creator usage at a glance.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _EntitlementsLine(entitlements: bundle.entitlements),
                if (bundle.usage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _UsageLine(usage: bundle.usage!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Level progress',
            subtitle: 'Track your XP, streak, and creator momentum.',
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Level ${model.level}, ${model.rankTitle}, ${model.totalXp} total XP',
            child: _LevelCard(model: model),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orangeAccent.withValues(alpha: 0.95),
                  title: 'Streak',
                  value: model.streakDays > 0 ? '${model.streakDays} days' : 'Start today',
                  helper: model.streakDays > 0
                      ? 'Keep your momentum going'
                      : 'Complete activity to begin',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.supportAccent.withValues(alpha: 0.95),
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
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Achievements',
            subtitle: 'Milestones and badge unlocks will show up here.',
          ),
          const SizedBox(height: 12),
          const _AchievementsPlaceholder(),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.38),
            AppColors.supportAccent.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Creator Progression',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rankTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level $level · Score ${creatorScore.toStringAsFixed(1)} · ${streakDays > 0 ? '$streakDays day streak' : 'Build your first streak'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EntitlementsLine extends StatelessWidget {
  final UserEntitlementsModel entitlements;

  const _EntitlementsLine({required this.entitlements});

  @override
  Widget build(BuildContext context) {
    final List<String> active = <String>[];
    if (entitlements.tippyAi) active.add('Tippy AI');
    if (entitlements.crossPosting) active.add('Cross-post');
    if (entitlements.advancedAnalytics) active.add('Analytics');
    if (entitlements.advancedPlanner) active.add('Planner+');
    if (entitlements.premiumMissionTracks) active.add('Premium missions');
    if (active.isEmpty) {
      return Text(
        'Your current plan perks will appear here once available.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 12,
          height: 1.35,
        ),
      );
    }
    return Text(
      active.join(' · '),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}

class _UsageLine extends StatelessWidget {
  final UsageMetricsModel usage;

  const _UsageLine({required this.usage});

  @override
  Widget build(BuildContext context) {
    final List<String> parts = <String>[];
    if (usage.crossPostsUsed != null && usage.crossPostsLimit != null) {
      parts.add(
        'Cross-posts ${usage.crossPostsUsed}/${usage.crossPostsLimit}',
      );
    }
    if (usage.aiCreditsUsed != null && usage.aiCreditsLimit != null) {
      parts.add('AI ${usage.aiCreditsUsed}/${usage.aiCreditsLimit}');
    }
    if (parts.isEmpty) {
      return Text(
        'Usage details will appear here when available.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 12,
        ),
      );
    }
    return Text(
      parts.join(' · '),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.62),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SignedOutMessage extends StatelessWidget {
  const _SignedOutMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sign in to track creator progression.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
    return Center(
      child: loading
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text(
                    'Loading your progression...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Text(
              'No profile data',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final GamificationSummaryModel model;
  const _LevelCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final int need = model.xpNeededForNextLevel;
    final int safeNeed = need <= 0 ? 1 : need;
    final int into = model.xpIntoLevel.clamp(0, safeNeed);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Center(
                  child: Text(
                    '${model.level}',
                    style: const TextStyle(
                      color: Colors.white,
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
                      model.rankTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${model.totalXp} total XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
            child: LinearProgressIndicator(
              value: model.progressInLevel.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.supportAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$into / $safeNeed XP this level',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.supportAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Next step',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsPlaceholder extends StatelessWidget {
  const _AchievementsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              color: AppColors.supportAccent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Keep completing missions and leveling up to unlock badge milestones here.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
