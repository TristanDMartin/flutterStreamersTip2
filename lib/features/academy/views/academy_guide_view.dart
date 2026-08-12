import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../routing/app_navigator.dart';
import '../../../services/creator_intelligence_analytics_service.dart';
import '../../../shared/analytics/analytics_event_constants.dart';
import '../../tippy/models/tippy_launch_context.dart';
import '../academy_providers.dart';
import '../data/academy_repository.dart';
import '../models/academy_models.dart';
import '../services/academy_web_launcher.dart';
import '../widgets/academy_widgets.dart';

class AcademyGuideView extends ConsumerStatefulWidget {
  const AcademyGuideView({super.key, required this.guideId});

  final String guideId;

  @override
  ConsumerState<AcademyGuideView> createState() => _AcademyGuideViewState();
}

class _AcademyGuideViewState extends ConsumerState<AcademyGuideView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackOpen());
  }

  Future<void> _trackOpen() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await ref.read(academyXpServiceProvider).maybeAwardFirstGuideOfDay(
          userId: user.uid,
          guideId: widget.guideId,
        );
    unawaited(
      CreatorIntelligenceAnalyticsService().trackEvent(
        eventType: AnalyticsEventTypes.guideRead,
        targetType: AnalyticsTargetTypes.guide,
        targetId: widget.guideId,
      ),
    );
  }

  Future<void> _toggleSave(AcademyGuideSummary guide) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final AcademyRepository repo = ref.read(academyRepositoryProvider);
    final List<AcademyUserProgress> saved =
        await repo.fetchSavedGuides(user.uid);
    final bool alreadySaved = saved.any(
      (AcademyUserProgress p) => p.guideId == guide.id && p.isSaved,
    );
    final AcademyUserProgress progress = AcademyUserProgress(
      userId: user.uid,
      guideId: guide.id,
      lessonId: '${guide.id}_bookmark',
      isSaved: !alreadySaved,
      savedAt: alreadySaved ? null : DateTime.now(),
      lastOpenedAt: DateTime.now(),
      status: AcademyProgressStatus.inProgress,
    );
    await repo.upsertProgress(progress);
    if (!alreadySaved) {
      await ref.read(academyXpServiceProvider).awardGuideBookmarked(
            userId: user.uid,
            guideId: guide.id,
          );
    }
    ref.invalidate(academySavedGuidesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final AsyncValue<AcademyGuideSummary?> guideAsync =
        ref.watch(academyGuideProvider(widget.guideId));
    final AsyncValue<List<AcademyLessonSummary>> lessonsAsync =
        ref.watch(academyGuideLessonsProvider(widget.guideId));
    final List<AcademyUserProgress> progress =
        ref.watch(academyUserProgressProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    final List<AcademyUserProgress> saved =
        ref.watch(academySavedGuidesProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: guideAsync.when(
        loading: () => const AcademySkeletonList(),
        error: (_, __) => AcademyEmptyState(
          title: 'Guide unavailable',
          message:
              'The Academy could not load this guide right now. '
              'Your saved progress is safe.',
          onRetry: () => ref.invalidate(academyGuideProvider(widget.guideId)),
        ),
        data: (AcademyGuideSummary? guide) {
          if (guide == null) {
            return const AcademyEmptyState(
              title: 'Guide not found',
              message: 'This guide may have been removed or unpublished.',
            );
          }
          final List<AcademyLessonSummary> lessons =
              lessonsAsync.valueOrNull ?? const <AcademyLessonSummary>[];
          final int lessonTotal =
              lessons.isNotEmpty ? lessons.length : guide.lessonCount;
          final int completedLessons = progress
              .where(
                (AcademyUserProgress p) =>
                    p.guideId == guide.id && p.isCompleted,
              )
              .length;
          final double guideProgress = academyCompletionPercent(
            completed: completedLessons,
            total: lessonTotal,
          );
          final bool isSaved = saved.any(
            (AcademyUserProgress p) => p.guideId == guide.id && p.isSaved,
          );
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                backgroundColor: shell.scaffold,
                foregroundColor: shell.onChrome,
                title: const Text('Guide'),
                actions: <Widget>[
                  IconButton(
                    tooltip: isSaved ? 'Remove bookmark' : 'Save guide',
                    onPressed: () => _toggleSave(guide),
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share guide',
                    onPressed: () {
                      Share.share(guide.shareUrl);
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: AcademyGradientHeader(
                  title: guide.title,
                  subtitle: guide.description.isNotEmpty
                      ? guide.description
                      : 'Streamer Academy guide',
                  icon: Icons.menu_book_rounded,
                  xpLabel: difficultyLabel(guide.difficulty),
                  streakLabel: guide.estimatedMinutes > 0
                      ? '${guide.estimatedMinutes} min'
                      : null,
                  weeklyGoalLabel: guide.isWebsiteBacked
                      ? 'Website guide'
                      : (lessonTotal > 0
                          ? '$completedLessons of $lessonTotal lessons'
                          : null),
                  completionPercent:
                      lessonTotal > 0 ? guideProgress : null,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AcademyTokens.pagePadding,
                  0,
                  AcademyTokens.pagePadding,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      AcademyMetaChip(
                        label: difficultyLabel(guide.difficulty),
                      ),
                      if (guide.estimatedMinutes > 0)
                        AcademyMetaChip(
                          label: '${guide.estimatedMinutes}m',
                        ),
                      if (guide.author != null && guide.author!.isNotEmpty)
                        AcademyMetaChip(label: guide.author!),
                      if (guide.isWebsiteBacked)
                        const AcademyMetaChip(label: 'Live on web'),
                      if (guide.updatedAt != null)
                        AcademyMetaChip(
                          label:
                              'Updated ${DateFormat.MMMd().format(guide.updatedAt!)}',
                        ),
                    ],
                  ),
                ),
              ),
              if (lessonsAsync.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (lessons.isEmpty && guide.isWebsiteBacked)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AcademyTokens.pagePadding,
                    0,
                    AcademyTokens.pagePadding,
                    12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: AcademyShellActionCard(
                      title: 'Read the full guide',
                      body:
                          'This guide lives on StreamersTip and stays '
                          'up to date when new pages are published.',
                      actionLabel: 'Open guide',
                      icon: Icons.open_in_new_rounded,
                      onPressed: () {
                        unawaited(
                          AcademyWebLauncher.openGuideUrl(
                            guide.webUrl ?? guide.shareUrl,
                          ),
                        );
                      },
                    ),
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AcademyTokens.pagePadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      lessons.isEmpty ? 'Lessons' : 'Lessons in this guide',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AcademyTokens.pagePadding,
                    10,
                    AcademyTokens.pagePadding,
                    12,
                  ),
                  sliver: lessons.isEmpty
                      ? SliverToBoxAdapter(
                          child: Text(
                            'Lessons for this guide are coming soon.',
                            style: TextStyle(
                              color: shell.muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        )
                      : SliverList.separated(
                          itemCount: lessons.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (BuildContext context, int index) {
                            final AcademyLessonSummary lesson =
                                lessons[index];
                            final bool done = progress.any(
                              (AcademyUserProgress p) =>
                                  p.lessonId == lesson.id && p.isCompleted,
                            );
                            return AcademyPathStepCard(
                              stepNumber: index + 1,
                              title: lesson.title,
                              subtitle: done
                                  ? 'Completed'
                                  : (lesson.estimatedMinutes > 0
                                      ? '${lesson.estimatedMinutes} min read'
                                      : 'Tap to start'),
                              isCompleted: done,
                              isWebsiteBacked: false,
                              estimatedMinutes: lesson.estimatedMinutes > 0
                                  ? lesson.estimatedMinutes
                                  : null,
                              onTap: () => AppNavigator.openAcademyLesson(
                                context,
                                lessonId: lesson.id,
                                guideId: guide.id,
                              ),
                            );
                          },
                        ),
                ),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AcademyTokens.pagePadding,
                  4,
                  AcademyTokens.pagePadding,
                  32,
                ),
                sliver: SliverToBoxAdapter(
                  child: AcademyShellActionCard(
                    title: 'Ask Tippy',
                    body:
                        'Open Tippy on "${guide.title}" and get a clear '
                        'explanation plus next steps.',
                    actionLabel: 'Ask Tippy to explain this guide',
                    icon: Icons.auto_awesome_rounded,
                    isPrimary: false,
                    onPressed: () => AppNavigator.openTippyChat(
                      context,
                      launchContext: TippyLaunchContext.forAcademyGuideExplain(
                        guideId: guide.id,
                        title: guide.title,
                        description: guide.description,
                        webUrl: guide.webUrl ?? guide.shareUrl,
                        categoryId: guide.categoryId,
                        difficulty: difficultyLabel(guide.difficulty),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
