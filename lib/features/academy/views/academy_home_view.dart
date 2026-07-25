import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/gamification_providers.dart';
import '../../gamification/missions/mission_engine.dart';
import '../../gamification/models/user_progress_bundle.dart';
import '../../gamification/utils/gamification_constants.dart';
import '../../gamification/widgets/mission_sections_list.dart';
import '../../../routing/app_navigator.dart';
import '../../../services/creator_intelligence_analytics_service.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyHomeView extends ConsumerStatefulWidget {
  const AcademyHomeView({super.key});

  @override
  ConsumerState<AcademyHomeView> createState() => _AcademyHomeViewState();
}

class _AcademyHomeViewState extends ConsumerState<AcademyHomeView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AcademyHomeSnapshot> snapshotAsync =
        ref.watch(academyHomeSnapshotProvider);
    final List<AcademyUserProgress> progress =
        ref.watch(academyUserProgressProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    final UserProgressBundle? bundle =
        ref.watch(userProgressBundleProvider).valueOrNull;
    final List<MissionSection> questSections =
        ref.watch(academyQuestSectionsProvider);
    return Scaffold(
      body: snapshotAsync.when(
        loading: () => const AcademySkeletonList(),
        error: (_, __) => AcademyEmptyState(
          title: 'The Academy could not load right now',
          message:
              'Your saved progress is safe. Please try again.',
          onRetry: () => ref.invalidate(academyHomeSnapshotProvider),
        ),
        data: (AcademyHomeSnapshot snapshot) {
          final int totalLessons = snapshot.guides.fold<int>(
            0,
            (int sum, AcademyGuideSummary g) => sum + g.lessonCount,
          );
          final int completedLessons = academyCompletedLessonCount(
            progress: progress,
          );
          final double overallCompletion = academyCompletionPercent(
            completed: completedLessons,
            total: totalLessons,
          );
          final int level = bundle?.progress.level ?? 1;
          final int totalXp = bundle?.progress.totalXp ?? 0;
          final int nextXp = GamificationConstants.xpFloorForLevel(level + 1);
          final int streak = bundle?.progress.streakDays ?? 0;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(academyHomeSnapshotProvider);
              ref.invalidate(academyUserProgressProvider);
            },
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  title: const Text('Streamer Academy'),
                  actions: <Widget>[
                    IconButton(
                      tooltip: 'Saved guides',
                      onPressed: () => AppNavigator.openAcademySaved(context),
                      icon: const Icon(Icons.bookmark_rounded),
                    ),
                    IconButton(
                      tooltip: 'Your progress',
                      onPressed: () =>
                          AppNavigator.openAcademyProgress(context),
                      icon: const Icon(Icons.insights_rounded),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: AcademyGradientHeader(
                    title: 'Streamer Academy',
                    subtitle:
                        'Build your skills. Grow your content. '
                        'Level up your creator journey.',
                    level: level,
                    xpLabel: '$totalXp / $nextXp XP',
                    streakLabel:
                        streak > 0 ? '$streak-day learning streak' : null,
                    weeklyGoalLabel: 'Weekly goal: 3 lessons',
                    completionPercent: overallCompletion,
                  ),
                ),
                SliverToBoxAdapter(
                  child: AcademySearchField(
                    controller: _searchController,
                    readOnly: true,
                    onTap: () => AppNavigator.openAcademySearch(context),
                    onChanged: (_) {},
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AcademyTokens.pagePadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Learning Paths',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    AcademyTokens.sectionGap,
                  ),
                  sliver: snapshot.paths.isEmpty
                      ? SliverToBoxAdapter(
                          child: Text(
                            'Learning paths will appear here as they are published.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.62),
                            ),
                          ),
                        )
                      : SliverList.separated(
                          itemCount: snapshot.paths.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (BuildContext context, int index) {
                            final AcademyPath path = snapshot.paths[index];
                            final int completed = academyCompletedLessonCount(
                              progress: progress,
                              lessonIds: path.lessonIds,
                            );
                            return AcademyPathCard(
                              title: path.title,
                              description: path.description,
                              completedLessons: completed,
                              totalLessons: path.lessonIds.length,
                              isLocked: level < path.unlockLevel,
                              onTap: () {
                                unawaited(
                                  CreatorIntelligenceAnalyticsService()
                                      .trackToolOpened(toolId: 'academy_path'),
                                );
                                AppNavigator.openAcademyPath(
                                  context,
                                  pathId: path.id,
                                );
                              },
                            );
                          },
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AcademyTokens.pagePadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Daily & Weekly Quests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    AcademyTokens.sectionGap,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: MissionSectionsList(sections: questSections),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AcademyTokens.pagePadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Browse Categories',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    32,
                  ),
                  sliver: snapshot.categories.isEmpty
                      ? SliverToBoxAdapter(
                          child: AcademyEmptyState(
                            title: 'Academy content is on the way',
                            message:
                                'Published categories from StreamersTip will appear here automatically.',
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final AcademyCategory category =
                                  snapshot.categories[index];
                              final List<AcademyGuideSummary> categoryGuides =
                                  snapshot.guides
                                      .where(
                                        (AcademyGuideSummary g) =>
                                            g.categoryId == category.id,
                                      )
                                      .toList();
                              final int categoryLessonTotal =
                                  categoryGuides.fold<int>(
                                0,
                                (int sum, AcademyGuideSummary g) =>
                                    sum + g.lessonCount,
                              );
                              final Set<String> lessonIds = categoryGuides
                                  .expand(
                                    (AcademyGuideSummary g) =>
                                        List<String>.generate(
                                      g.lessonCount,
                                      (_) => g.id,
                                    ),
                                  )
                                  .toSet();
                              final int completedInCategory = progress
                                  .where(
                                    (AcademyUserProgress p) =>
                                        p.isCompleted &&
                                        lessonIds.contains(p.lessonId),
                                  )
                                  .length;
                              return AcademyCategoryCard(
                                name: category.name,
                                description: category.description,
                                guideCount: category.guideCount > 0
                                    ? category.guideCount
                                    : categoryGuides.length,
                                completionPercent: academyCompletionPercent(
                                  completed: completedInCategory,
                                  total: categoryLessonTotal,
                                ),
                                isLocked: level < category.unlockLevel,
                                onTap: () {
                                  AppNavigator.openAcademyCategory(
                                    context,
                                    categoryId: category.id,
                                  );
                                },
                              );
                            },
                            childCount: snapshot.categories.length,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
