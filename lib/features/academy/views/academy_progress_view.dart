import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/gamification_providers.dart';
import '../../gamification/models/user_progress_bundle.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyProgressView extends ConsumerWidget {
  const AcademyProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AcademyUserProgress> progress =
        ref.watch(academyUserProgressProvider).valueOrNull ??
            const <AcademyUserProgress>[];
    final UserProgressBundle? bundle =
        ref.watch(userProgressBundleProvider).valueOrNull;
    final AsyncValue<List<AcademyGuideSummary>> guidesAsync =
        ref.watch(academyGuideSummariesProvider);
    final int completed =
        progress.where((AcademyUserProgress p) => p.isCompleted).length;
    final int inProgress = progress
        .where(
          (AcademyUserProgress p) =>
              p.status == AcademyProgressStatus.inProgress,
        )
        .length;
    final int saved =
        progress.where((AcademyUserProgress p) => p.isSaved).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Academy Progress')),
      body: ListView(
        padding: const EdgeInsets.all(AcademyTokens.pagePadding),
        children: <Widget>[
          AcademyGradientHeader(
            title: 'Your Progress',
            subtitle: 'Track lessons, streaks, and XP from Streamer Academy.',
            level: bundle?.progress.level,
            xpLabel: bundle == null
                ? null
                : '${bundle.progress.totalXp} XP total',
            streakLabel: bundle != null && bundle.progress.streakDays > 0
                ? '${bundle.progress.streakDays}-day streak'
                : null,
            completionPercent: guidesAsync.maybeWhen(
              data: (List<AcademyGuideSummary> guides) {
                final int totalLessons = guides.fold<int>(
                  0,
                  (int sum, AcademyGuideSummary g) => sum + g.lessonCount,
                );
                return academyCompletionPercent(
                  completed: completed,
                  total: totalLessons,
                );
              },
              orElse: () => null,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Completed lessons', value: '$completed'),
          _StatRow(label: 'In progress', value: '$inProgress'),
          _StatRow(label: 'Saved guides', value: '$saved'),
          const SizedBox(height: 20),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (progress.isEmpty)
            const Text('Complete your first lesson to start tracking progress.')
          else
            ...progress.take(12).map(
                  (AcademyUserProgress item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                    ),
                    title: Text('Lesson ${item.lessonId}'),
                    subtitle: Text(item.status.name),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
