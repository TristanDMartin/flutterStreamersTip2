import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_navigator.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyPathView extends ConsumerWidget {
  const AcademyPathView({super.key, required this.pathId});

  final String pathId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AcademyPath?> pathAsync =
        ref.watch(academyPathProvider(pathId));
    final List<AcademyUserProgress> progress =
        ref.watch(academyUserProgressProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Path')),
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
          final int completed = academyCompletedLessonCount(
            progress: progress,
            lessonIds: path.lessonIds,
          );
          return ListView(
            padding: const EdgeInsets.all(AcademyTokens.pagePadding),
            children: <Widget>[
              Text(
                path.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(path.description),
              const SizedBox(height: 12),
              AcademyPathCard(
                title: path.title,
                description: path.description,
                completedLessons: completed,
                totalLessons: path.lessonIds.length,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              ...path.lessonIds.map((String lessonId) {
                final AcademyUserProgress? lessonProgress = progress
                    .where((AcademyUserProgress p) => p.lessonId == lessonId)
                    .cast<AcademyUserProgress?>()
                    .firstWhere(
                      (AcademyUserProgress? p) => p != null,
                      orElse: () => null,
                    );
                final bool done = lessonProgress?.isCompleted ?? false;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.play_circle_outline_rounded,
                    color: done
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text('Lesson ${path.lessonIds.indexOf(lessonId) + 1}'),
                  subtitle: Text(done ? 'Completed' : 'Tap to start'),
                  onTap: () => AppNavigator.openAcademyLesson(
                    context,
                    lessonId: lessonId,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
