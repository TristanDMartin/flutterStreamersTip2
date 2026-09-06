import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../services/progression_service.dart';
import '../../../widgets/streamer_card_sections.dart';
import '../gamification_providers.dart';
import '../models/gamification_summary_model.dart';
import '../missions/mission_engine.dart';
import '../models/user_progress_bundle.dart';
import '../utils/gamification_constants.dart';
import 'mission_sections_list.dart';
import 'tier_badge_strip.dart';
import '../achievements/canonical_achievements_section.dart';

/// Home "Progression" tab: creator progress, plan, missions (read-only Firestore).
class CreatorProgressionPanel extends ConsumerStatefulWidget {
  const CreatorProgressionPanel({super.key});

  @override
  ConsumerState<CreatorProgressionPanel> createState() =>
      _CreatorProgressionPanelState();
}

class _CreatorProgressionPanelState
    extends ConsumerState<CreatorProgressionPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color scaffoldColor = shell.isLight
        ? shell.scaffold
        : StreamerCardBackStyle.background;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ColoredBox(
        color: scaffoldColor,
        child: const _SignedOutMessage(),
      );
    }
    final AsyncValue<UserProgressBundle> asyncBundle =
        ref.watch(userProgressBundleProvider);
    final UserProgressBundle? cachedBundle = asyncBundle.valueOrNull;
    final Widget body = cachedBundle != null
        ? _ProgressionBody(
            bundle: cachedBundle,
            uid: user.uid,
            onRefresh: () async {
              await ProgressionService.instance.refreshUserProgress(user.uid);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(const GetOptions(source: Source.server));
            },
          )
        : asyncBundle.when(
            data: (UserProgressBundle bundle) => _ProgressionBody(
              bundle: bundle,
              uid: user.uid,
              onRefresh: () async {
                await ProgressionService.instance.refreshUserProgress(user.uid);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(const GetOptions(source: Source.server));
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
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
    return ColoredBox(color: scaffoldColor, child: body);
  }
}

class _FirstThingsToDoSection extends StatefulWidget {
  const _FirstThingsToDoSection({required this.uid});

  final String uid;

  @override
  State<_FirstThingsToDoSection> createState() =>
      _FirstThingsToDoSectionState();
}

class _FirstThingsToDoSectionState extends State<_FirstThingsToDoSection> {
  UserProgressionSnapshot? _lastProgress;
  late Stream<UserProgressionSnapshot> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = ProgressionService.instance.listenToProgress(widget.uid);
    _refresh();
  }

  @override
  void didUpdateWidget(_FirstThingsToDoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _lastProgress = null;
      _progressStream =
          ProgressionService.instance.listenToProgress(widget.uid);
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final UserProgressionSnapshot progress =
        await ProgressionService.instance.refreshUserProgress(widget.uid);
    if (!mounted) return;
    setState(() => _lastProgress = progress);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProgressionSnapshot>(
      stream: _progressStream,
      initialData: _lastProgress,
      builder: (
        BuildContext context,
        AsyncSnapshot<UserProgressionSnapshot> progressSnapshot,
      ) {
        final UserProgressionSnapshot? progress =
            progressSnapshot.data ?? _lastProgress;
        if (progressSnapshot.hasData && progressSnapshot.data != null) {
          _lastProgress = progressSnapshot.data;
        }
        return _FirstThingsToDoCard(
          progress: progress,
        );
      },
    );
  }
}

class _FirstThingsToDoCard extends StatelessWidget {
  const _FirstThingsToDoCard({required this.progress});

  final UserProgressionSnapshot? progress;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ProgressionService progressionService = ProgressionService.instance;
    final bool isLoading = progress == null;
    final List<ProgressionTask> activeTasks = isLoading
        ? <ProgressionTask>[]
        : progressionService.activeTasksForSnapshot(progress).take(3).toList();
    final int completedCount = isLoading
        ? 0
        : progressionService.completedTasksForSnapshot(progress).length;
    final int totalCount = ProgressionService.allTasks
        .where((ProgressionTask task) => !task.hidden)
        .length;
    final bool isComplete = activeTasks.isEmpty && progress != null;
    final Color accent =
        isLight ? scheme.primary : StreamerCardBackStyle.lavender;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? shell.surfaceCard : StreamerCardBackStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? const Color(0xFF86EFAC).withValues(alpha: 0.28)
              : (isLight
                  ? shell.surfaceCardBorder
                  : Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.flag_circle_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLoading
                      ? 'Syncing onboarding'
                      : isComplete
                          ? 'Setup complete'
                          : 'Onboarding progress',
                  style: TextStyle(
                    color: isLight
                        ? shell.onChrome
                        : StreamerCardBackStyle.softText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$completedCount/$totalCount',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (isLoading)
            const _StaticFirstThingsProgress()
          else
            _AnimatedFirstThingsProgress(
              value: totalCount == 0 ? 0 : completedCount / totalCount,
            ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Animation<Offset> offset = Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: isLoading
                ? Padding(
                    key: const ValueKey<String>('syncing-progress'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Checking your account activity...',
                      style: TextStyle(
                        color: isLight
                            ? shell.muted
                            : StreamerCardBackStyle.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                : activeTasks.isEmpty
                    ? Padding(
                        key: const ValueKey<String>('all-complete'),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.check_circle_rounded,
                              color: const Color(0xFF86EFAC)
                                  .withValues(alpha: 0.9),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'First steps are done. New missions will rotate in below.',
                                style: TextStyle(
                                  color: isLight
                                      ? shell.onChrome.withValues(alpha: 0.78)
                                      : StreamerCardBackStyle.softText,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        key: ValueKey<String>(
                          activeTasks
                              .map((ProgressionTask task) => task.id)
                              .join('|'),
                        ),
                        children: activeTasks.map((ProgressionTask task) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isLight
                                    ? scheme.surface.withValues(alpha: 0.34)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLight
                                      ? scheme.outline.withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: isLight
                                        ? scheme.onSurface
                                            .withValues(alpha: 0.42)
                                        : StreamerCardBackStyle.muted,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isLight
                                            ? scheme.onSurface
                                                .withValues(alpha: 0.72)
                                            : StreamerCardBackStyle.softText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+${task.xpReward} XP',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFirstThingsProgress extends StatefulWidget {
  const _AnimatedFirstThingsProgress({required this.value});

  final double value;

  @override
  State<_AnimatedFirstThingsProgress> createState() =>
      _AnimatedFirstThingsProgressState();
}

class _StaticFirstThingsProgress extends StatelessWidget {
  const _StaticFirstThingsProgress();

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final Color track = isLight
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);
    final Color fill = isLight
        ? Theme.of(context).colorScheme.primary
        : StreamerCardBackStyle.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 4,
        value: 0,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation<Color>(
          fill.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _AnimatedFirstThingsProgressState
    extends State<_AnimatedFirstThingsProgress> {
  late double _previousValue = widget.value;

  @override
  void didUpdateWidget(_AnimatedFirstThingsProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousValue = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final Color track = isLight
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);
    final Color fill = isLight
        ? Theme.of(context).colorScheme.primary
        : StreamerCardBackStyle.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: _previousValue.clamp(0, 1),
          end: widget.value.clamp(0, 1),
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) {
          return LinearProgressIndicator(
            minHeight: 4,
            value: value,
            backgroundColor: track,
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          );
        },
      ),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GamificationSummaryModel model = bundle.progress;
    final String rankTitle = model.rankTitle;
    final bool hasMissions = bundle.missions.isNotEmpty;
    final bool hasHint =
        model.nextActionHint != null && model.nextActionHint!.isNotEmpty;
    return RefreshIndicator(
      color: shell.isLight
          ? shell.refreshColor
          : StreamerCardBackStyle.lavender,
      backgroundColor: shell.isLight
          ? shell.refreshBackground
          : StreamerCardBackStyle.card,
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey<String>('creator_progression_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 88,
          16,
          120,
        ),
        children: <Widget>[
          const _ProgressionTopBar(),
          const SizedBox(height: 16),
          KeyedSubtree(
            child: _HeroHeader(model: model),
          ),
          const SizedBox(height: 14),
          _WeeklySnapshotCard(
              model: model, missionCount: bundle.missions.length),
          const SizedBox(height: 14),
          TierBadgeStrip(subscription: bundle.subscription),
          const SizedBox(height: 14),
          _FirstThingsToDoSection(uid: uid),
          const SizedBox(height: 22),
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
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.orangeAccent.withValues(alpha: 0.95),
                    title: 'Streak',
                    value: model.displayStreakValue,
                    helper: model.displayStreakHelper,
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
          ),
          if (hasHint) ...<Widget>[
            const SizedBox(height: 14),
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
          const CanonicalAchievementsSection(),
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
        final StSupportShellStyle shell = StSupportShellStyle.of(context);
        final bool isLight = shell.isLight;
        return _GlassSheet(
          title: 'Level rewards ladder',
          subtitle: 'See what your next creator milestones unlock.',
          child: Column(
            children: levels.map((int level) {
              final bool current = level == model.level;
              final bool completed = level < model.level;
              final String reward =
                  GamificationConstants.rewardLabelForLevel(level);
              final Color rowBg = isLight
                  ? scheme.surfaceContainerLow.withValues(
                      alpha: current ? 1.0 : 0.72,
                    )
                  : (current
                      ? StreamerCardBackStyle.accent.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.04));
              final Color rowBorder = current
                  ? (isLight
                      ? scheme.primary.withValues(alpha: 0.35)
                      : StreamerCardBackStyle.accent.withValues(alpha: 0.35))
                  : (isLight
                      ? scheme.outline.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.08));
              final Color accent = isLight
                  ? scheme.primary
                  : StreamerCardBackStyle.lavender;
              final List<Color> orbColors = completed
                  ? <Color>[
                      const Color(0xFF86EFAC).withValues(alpha: 0.85),
                      accent.withValues(alpha: 0.35),
                    ]
                  : current
                      ? <Color>[
                          StreamerCardBackStyle.accent,
                          StreamerCardBackStyle.ringBlue,
                        ]
                      : <Color>[
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.06),
                        ];
              final Color levelNumColor = completed || current
                  ? Colors.white
                  : (isLight
                      ? scheme.onSurface
                      : StreamerCardBackStyle.muted);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(16),
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
                              fontWeight: FontWeight.w500,
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
                                color: isLight
                                    ? scheme.onSurface
                                    : StreamerCardBackStyle.softText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reward,
                              style: TextStyle(
                                color: isLight
                                    ? scheme.onSurface.withValues(alpha: 0.62)
                                    : StreamerCardBackStyle.muted,
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
                              ? const Color(0xFF86EFAC)
                              : current
                                  ? accent
                                  : (isLight
                                      ? scheme.onSurface.withValues(alpha: 0.55)
                                      : StreamerCardBackStyle.muted),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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

class _ProgressionTopBar extends StatelessWidget {
  const _ProgressionTopBar();

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Progression',
          style: TextStyle(
            color: isLight ? shell.onChrome : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track creator growth and daily momentum.',
          style: TextStyle(
            color: isLight ? shell.mutedStrong : StreamerCardBackStyle.muted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final GamificationSummaryModel model;

  const _HeroHeader({required this.model});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = shell.isLight;
    final int safeNeed =
        model.xpNeededForNextLevel <= 0 ? 1 : model.xpNeededForNextLevel;
    final int into = model.xpIntoLevel.clamp(0, safeNeed);
    final Color accent =
        isLight ? scheme.primary : StreamerCardBackStyle.accent;
    final Color lavender =
        isLight ? scheme.primary : StreamerCardBackStyle.lavender;
    final Color muted =
        isLight ? shell.muted : StreamerCardBackStyle.muted;
    final Color softText =
        isLight ? shell.onChrome : StreamerCardBackStyle.softText;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF2A1F4D),
                  Color(0xFF161320),
                ],
              ),
        color: isLight
            ? shell.surfaceCard
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? shell.surfaceCardBorder
              : StreamerCardBackStyle.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${model.level}',
                    style: TextStyle(
                      color: lavender,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                      'Level ${model.level}',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: Text(
                        model.rankTitle,
                        key: ValueKey<String>(model.rankTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: softText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _AnimatedXpText(
                      value: model.totalXp,
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AnimatedLevelProgressBar(
            value: model.progressInLevel.clamp(0, 1),
            backgroundColor: Colors.white.withValues(alpha: isLight ? 0.12 : 0.1),
            foregroundColor: accent,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$into / $safeNeed XP to Level ${model.level + 1}',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                '${(model.progressInLevel * 100).round()}%',
                style: TextStyle(
                  color: lavender,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _HeroMetric(
                icon: Icons.local_fire_department_rounded,
                label: model.displayStreakValue,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              _HeroMetric(
                icon: Icons.auto_awesome_rounded,
                label: '${model.creatorScore.toStringAsFixed(0)} score',
                color: lavender,
              ),
              const SizedBox(width: 8),
              _HeroMetric(
                icon: Icons.trending_up_rounded,
                label: model.isActiveToday ? 'Active today' : 'Build momentum',
                color: Colors.greenAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return Expanded(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.black.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isLight ? 0.0 : 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.78)
                      : StreamerCardBackStyle.softText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklySnapshotCard extends StatelessWidget {
  const _WeeklySnapshotCard({
    required this.model,
    required this.missionCount,
  });

  final GamificationSummaryModel model;
  final int missionCount;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final int momentum = (model.creatorScore / 10).round().clamp(0, 10);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? shell.surfaceCard : StreamerCardBackStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? shell.surfaceCardBorder
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.insights_rounded,
                color: isLight
                    ? Theme.of(context).colorScheme.primary
                    : StreamerCardBackStyle.lavender,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Weekly snapshot',
                  style: TextStyle(
                    color: isLight
                        ? shell.onChrome
                        : StreamerCardBackStyle.softText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                momentum > 0 ? '+$momentum% momentum' : 'Build momentum',
                style: TextStyle(
                  color: momentum > 0
                      ? const Color(0xFF86EFAC)
                      : (isLight
                          ? shell.mutedStrong
                          : StreamerCardBackStyle.muted),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _SnapshotMetric(label: 'Streak', value: model.displayStreakValue),
              _SnapshotMetric(
                label: 'Missions',
                value: missionCount == 0 ? 'Syncing' : '$missionCount active',
              ),
              _SnapshotMetric(
                label: 'Score',
                value: model.creatorScore.toStringAsFixed(0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLight
                  ? shell.onChrome
                  : StreamerCardBackStyle.softText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isLight ? shell.muted : StreamerCardBackStyle.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
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
    final bool isLight = shell.isLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: isLight ? shell.onChrome : StreamerCardBackStyle.softText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: isLight ? shell.mutedStrong : StreamerCardBackStyle.muted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.35,
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
    final String rankTitle = model.rankTitle;
    final int need = model.xpNeededForNextLevel;
    final int safeNeed = need <= 0 ? 1 : need;
    final int into = model.xpIntoLevel.clamp(0, safeNeed);
    final bool isLight = shell.isLight;
    final Color accent =
        isLight ? scheme.primary : StreamerCardBackStyle.accent;
    final Color lavender =
        isLight ? scheme.primary : StreamerCardBackStyle.lavender;
    final BoxDecoration outerDecoration = BoxDecoration(
      color: isLight
          ? shell.surfaceCard
          : StreamerCardBackStyle.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isLight
            ? shell.surfaceCardBorder
            : Colors.white.withValues(alpha: 0.08),
      ),
    );
    final BoxDecoration orbDecoration = BoxDecoration(
      color: accent.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.35)),
    );
    final Color levelTextColor = lavender;
    final Color trackBg = Colors.white.withValues(alpha: isLight ? 0.12 : 0.1);
    final Color trackFg = accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: outerDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: orbDecoration,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutBack,
                        child: Text(
                          '${model.level}',
                          key: ValueKey<int>(model.level),
                          style: TextStyle(
                            color: levelTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          child: Text(
                            rankTitle,
                            key: ValueKey<String>(rankTitle),
                            style: TextStyle(
                              color: isLight
                                  ? shell.onChrome
                                  : StreamerCardBackStyle.softText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _AnimatedXpText(
                          value: model.totalXp,
                          style: TextStyle(
                            color: isLight
                                ? shell.muted
                                : StreamerCardBackStyle.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _AnimatedLevelProgressBar(
                value: model.progressInLevel.clamp(0, 1),
                backgroundColor: trackBg,
                foregroundColor: trackFg,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '$into / $safeNeed XP',
                      style: TextStyle(
                        color: isLight
                            ? shell.muted
                            : StreamerCardBackStyle.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    '${(model.progressInLevel * 100).round()}%',
                    style: TextStyle(
                      color: lavender,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
    final bool isLight = shell.isLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? shell.surfaceCard : StreamerCardBackStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? shell.surfaceCardBorder
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: isLight ? iconColor : StreamerCardBackStyle.lavender,
            size: 18,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLight
                  ? shell.mutedStrong
                  : StreamerCardBackStyle.muted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLight
                  ? shell.onChrome
                  : StreamerCardBackStyle.softText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            helper,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLight
                  ? shell.muted
                  : StreamerCardBackStyle.muted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedXpText extends StatefulWidget {
  const _AnimatedXpText({
    required this.value,
    required this.style,
  });

  final int value;
  final TextStyle style;

  @override
  State<_AnimatedXpText> createState() => _AnimatedXpTextState();
}

class _AnimatedXpTextState extends State<_AnimatedXpText>
    with SingleTickerProviderStateMixin {
  late int _previousValue = widget.value;
  AnimationController? _pulseController;
  late ColorScheme _scheme;

  @override
  void initState() {
    super.initState();
    // Create while the element is active — never lazily in dispose().
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheme = Theme.of(context).colorScheme;
  }

  @override
  void didUpdateWidget(_AnimatedXpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted) {
      return;
    }
    _previousValue = oldWidget.value;
    if (widget.value > oldWidget.value) {
      _pulseController?.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _pulseController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = _scheme;
    final AnimationController? pulse = _pulseController;
    final int delta = widget.value - _previousValue;
    return SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: _previousValue.toDouble(),
              end: widget.value.toDouble(),
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return Text(
                '${value.round()} total XP',
                style: widget.style,
              );
            },
          ),
          if (delta > 0 && pulse != null)
            Positioned(
              right: 0,
              top: -18,
              child: FadeTransition(
                opacity: ReverseAnimation(pulse),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(0, -0.7),
                  ).animate(
                    CurvedAnimation(
                      parent: pulse,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: Text(
                    '+$delta XP',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedLevelProgressBar extends StatefulWidget {
  const _AnimatedLevelProgressBar({
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final double value;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  State<_AnimatedLevelProgressBar> createState() =>
      _AnimatedLevelProgressBarState();
}

class _AnimatedLevelProgressBarState extends State<_AnimatedLevelProgressBar>
    with SingleTickerProviderStateMixin {
  double _previousValue = 0;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(_AnimatedLevelProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousValue = oldWidget.value;
    if (widget.value > oldWidget.value) {
      _glowController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (BuildContext _, Widget? child) {
        final double glow = (1 - _glowController.value).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              if (glow > 0)
                BoxShadow(
                  color: widget.foregroundColor.withValues(alpha: 0.32 * glow),
                  blurRadius: 18 * glow,
                  spreadRadius: 1.5 * glow,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: _previousValue.clamp(0, 1),
                end: widget.value.clamp(0, 1),
              ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (BuildContext ctx, double value, Widget? _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: widget.backgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.foregroundColor,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final String hint;
  const _NextActionCard({required this.hint});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final Color accent = isLight
        ? Theme.of(context).colorScheme.primary
        : StreamerCardBackStyle.lavender;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? shell.surfaceCard : StreamerCardBackStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? accent.withValues(alpha: 0.24)
              : StreamerCardBackStyle.accent.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Recommended next move',
                  style: TextStyle(
                    color: isLight
                        ? shell.mutedStrong
                        : StreamerCardBackStyle.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLight
                        ? shell.onChrome
                        : StreamerCardBackStyle.softText,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    final bool isLight = shell.isLight;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: isLight ? shell.panelSurface : StreamerCardBackStyle.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLight
                ? shell.panelBorder
                : Colors.white.withValues(alpha: 0.08),
          ),
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
                    color: (isLight ? shell.muted : StreamerCardBackStyle.muted)
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: isLight
                      ? shell.onChrome
                      : StreamerCardBackStyle.softText,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isLight ? shell.muted : StreamerCardBackStyle.muted,
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

