import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
    final AsyncValue<AcademyGuideSummary?> guideAsync =
        ref.watch(academyGuideProvider(widget.guideId));
    final AsyncValue<List<AcademyLessonSummary>> lessonsAsync =
        ref.watch(academyGuideLessonsProvider(widget.guideId));
    final List<AcademyUserProgress> progress =
        ref.watch(academyUserProgressProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    return Scaffold(
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
          final int completedLessons = progress
              .where(
                (AcademyUserProgress p) =>
                    p.guideId == guide.id && p.isCompleted,
              )
              .length;
          final double guideProgress = academyCompletionPercent(
            completed: completedLessons,
            total: lessons.isNotEmpty ? lessons.length : guide.lessonCount,
          );
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    guide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: guide.imageUrl.isNotEmpty
                      ? Image.network(
                          guide.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.black26),
                        )
                      : null,
                ),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Save guide',
                    onPressed: () => _toggleSave(guide),
                    icon: const Icon(Icons.bookmark_add_outlined),
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
              SliverPadding(
                padding: const EdgeInsets.all(AcademyTokens.pagePadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Chip(label: Text(difficultyLabel(guide.difficulty))),
                        Chip(label: Text('${guide.estimatedMinutes} min')),
                        if (guide.author != null)
                          Chip(label: Text(guide.author!)),
                      ],
                    ),
                    if (guide.updatedAt != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Updated ${DateFormat.yMMMd().format(guide.updatedAt!)}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(guide.description),
                    const SizedBox(height: 16),
                    AcademyAnimatedProgressBar(value: guideProgress),
                    const SizedBox(height: 20),
                    Text(
                      'Lessons',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (lessonsAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (lessons.isEmpty && guide.isWebsiteBacked)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'This guide lives on StreamersTip and stays '
                            'up to date when new pages are published.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              unawaited(
                                AcademyWebLauncher.openGuideUrl(
                                  guide.webUrl ?? guide.shareUrl,
                                ),
                              );
                            },
                            icon: const Icon(Icons.menu_book_rounded),
                            label: const Text('Read full guide'),
                          ),
                        ],
                      )
                    else if (lessons.isEmpty)
                      const Text('Lessons for this guide are coming soon.')
                    else
                      ...lessons.map((AcademyLessonSummary lesson) {
                        final AcademyUserProgress? lessonProgress = progress
                            .where(
                              (AcademyUserProgress p) =>
                                  p.lessonId == lesson.id,
                            )
                            .cast<AcademyUserProgress?>()
                            .firstWhere(
                              (AcademyUserProgress? p) => p != null,
                              orElse: () => null,
                            );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            lessonProgress?.isCompleted == true
                                ? Icons.check_circle_rounded
                                : Icons.play_lesson_rounded,
                          ),
                          title: Text(lesson.title),
                          subtitle: Text(
                            lessonProgress?.isCompleted == true
                                ? 'Completed'
                                : '${lesson.estimatedMinutes} min',
                          ),
                          onTap: () => AppNavigator.openAcademyLesson(
                            context,
                            lessonId: lesson.id,
                            guideId: guide.id,
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => AppNavigator.openTippyChat(
                        context,
                        launchContext: TippyLaunchContext(
                          surface: 'academy_guide',
                          academyGuideId: guide.id,
                          academyGuideTitle: guide.title,
                          prefilledPrompt:
                              'What should I learn next after '
                              '"${guide.title}"?',
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Ask Tippy about this guide'),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
