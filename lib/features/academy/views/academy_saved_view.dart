import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_navigator.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademySavedView extends ConsumerWidget {
  const AcademySavedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AcademyUserProgress>> savedAsync =
        ref.watch(academySavedGuidesProvider);
    final AsyncValue<List<AcademyGuideSummary>> guidesAsync =
        ref.watch(academyGuideSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Guides')),
      body: savedAsync.when(
        loading: () => const AcademySkeletonList(),
        error: (_, __) => AcademyEmptyState(
          title: 'Could not load saved guides',
          message: 'Please try again in a moment.',
          onRetry: () => ref.invalidate(academySavedGuidesProvider),
        ),
        data: (List<AcademyUserProgress> saved) {
          if (saved.isEmpty) {
            return const AcademyEmptyState(
              title: 'No saved guides yet',
              message: 'Bookmark guides to revisit them quickly.',
            );
          }
          final List<AcademyGuideSummary> guides =
              guidesAsync.valueOrNull ?? const <AcademyGuideSummary>[];
          return ListView.separated(
            padding: const EdgeInsets.all(AcademyTokens.pagePadding),
            itemCount: saved.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final AcademyUserProgress item = saved[index];
              AcademyGuideSummary? guide;
              for (final AcademyGuideSummary g in guides) {
                if (g.id == item.guideId) {
                  guide = g;
                  break;
                }
              }
              return AcademyGuideCard(
                title: guide?.title ?? 'Saved guide',
                description: guide?.description ?? 'Open to continue learning.',
                difficulty: guide == null
                    ? 'Guide'
                    : difficultyLabel(guide.difficulty),
                estimatedMinutes: guide?.estimatedMinutes ?? 0,
                imageUrl: guide?.imageUrl,
                onTap: () => AppNavigator.openAcademyGuide(
                  context,
                  guideId: item.guideId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
