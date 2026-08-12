import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../routing/app_navigator.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyPathView extends ConsumerWidget {
  const AcademyPathView({super.key, required this.pathId});

  final String pathId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final AsyncValue<AcademyPath?> pathAsync =
        ref.watch(academyPathProvider(pathId));
    final List<AcademyUserProgress> progress =
        ref.watch(academyUserProgressProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    final Map<String, AcademyGuideSummary> guidesById =
        <String, AcademyGuideSummary>{
      for (final AcademyGuideSummary guide
          in ref.watch(academyGuideSummariesProvider).valueOrNull ??
              const <AcademyGuideSummary>[])
        guide.id: guide,
    };
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: pathAsync.when(
        loading: () => const AcademySkeletonList(),
        error: (_, __) => AcademyEmptyState(
          title: 'Path unavailable',
          message: 'This learning path could not be loaded right now.',
          onRetry: () => ref.invalidate(academyPathProvider(pathId)),
        ),
        data: (AcademyPath? path) {
          if (path == null) {
            return const AcademyEmptyState(
              title: 'Path not found',
              message: 'This learning path may have been removed.',
            );
          }
          final List<AcademyPathStep> steps = path.steps;
          final int completed = academyCompletedPathStepCount(
            progress: progress,
            path: path,
          );
          final double completion = academyCompletionPercent(
            completed: completed,
            total: path.stepCount,
          );
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                backgroundColor: shell.scaffold,
                foregroundColor: shell.onChrome,
                title: const Text('Learning Path'),
              ),
              SliverToBoxAdapter(
                child: AcademyGradientHeader(
                  title: path.title,
                  subtitle: path.description,
                  icon: Icons.route_rounded,
                  xpLabel: '$completed of ${path.stepCount} guides',
                  completionPercent: completion,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AcademyTokens.pagePadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Guides in this path',
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
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final AcademyPathStep step = steps[index];
                    final String guideId = step.displayGuideId;
                    final AcademyGuideSummary? guide =
                        guideId.isEmpty ? null : guidesById[guideId];
                    final bool done = _isStepCompleted(
                      progress: progress,
                      step: step,
                      guideId: guideId,
                    );
                    final String title = guide?.title ??
                        (guideId.isNotEmpty
                            ? _titleFromGuideId(guideId)
                            : 'Lesson ${step.index + 1}');
                    final String subtitle = done
                        ? 'Completed'
                        : (guide?.description.isNotEmpty == true
                            ? guide!.description
                            : (step.isWebsiteBacked
                                ? 'Open this Streamer Academy guide'
                                : 'Tap to start this lesson'));
                    return AcademyPathStepCard(
                      stepNumber: step.index + 1,
                      title: title,
                      subtitle: subtitle,
                      isCompleted: done,
                      isWebsiteBacked: step.isWebsiteBacked,
                      difficulty: guide == null
                          ? null
                          : difficultyLabel(guide.difficulty),
                      estimatedMinutes: guide?.estimatedMinutes,
                      onTap: () {
                        if (step.isWebsiteBacked && guideId.isNotEmpty) {
                          AppNavigator.openAcademyGuide(
                            context,
                            guideId: guideId,
                          );
                          return;
                        }
                        AppNavigator.openAcademyLesson(
                          context,
                          lessonId: step.lessonId,
                          guideId: guideId.isEmpty ? null : guideId,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isStepCompleted({
    required List<AcademyUserProgress> progress,
    required AcademyPathStep step,
    required String guideId,
  }) {
    return progress.any((AcademyUserProgress p) {
      if (!p.isCompleted) {
        return false;
      }
      if (p.lessonId == step.lessonId) {
        return true;
      }
      if (guideId.isEmpty) {
        return false;
      }
      return p.guideId == guideId || p.lessonId == '${guideId}__web';
    });
  }

  String _titleFromGuideId(String guideId) {
    return guideId
        .split('-')
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
