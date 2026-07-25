import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_navigator.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyCategoryView extends ConsumerWidget {
  const AcademyCategoryView({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AcademyHomeSnapshot> snapshotAsync =
        ref.watch(academyHomeSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Academy Category')),
      body: snapshotAsync.when(
        loading: () => const AcademySkeletonList(),
        error: (_, __) => AcademyEmptyState(
          title: 'Category unavailable',
          message: 'The Academy could not load this category right now.',
          onRetry: () => ref.invalidate(academyHomeSnapshotProvider),
        ),
        data: (AcademyHomeSnapshot snapshot) {
          AcademyCategory? category;
          for (final AcademyCategory c in snapshot.categories) {
            if (c.id == categoryId) {
              category = c;
              break;
            }
          }
          final List<AcademyGuideSummary> guides = snapshot.guides
              .where((AcademyGuideSummary g) => g.categoryId == categoryId)
              .toList();
          if (category == null) {
            return const AcademyEmptyState(
              title: 'Category not found',
              message: 'This category may have been removed or unpublished.',
            );
          }
          final AcademyCategory resolvedCategory = category;
          if (guides.isEmpty) {
            return AcademyEmptyState(
              title: 'No guides yet',
              message:
                  '${resolvedCategory.name} guides will appear here when published.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AcademyTokens.pagePadding),
            itemCount: guides.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      resolvedCategory.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      resolvedCategory.description,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }
              final AcademyGuideSummary guide = guides[index - 1];
              return AcademyGuideCard(
                title: guide.title,
                description: guide.description,
                difficulty: difficultyLabel(guide.difficulty),
                estimatedMinutes: guide.estimatedMinutes,
                imageUrl: guide.imageUrl,
                categoryName: resolvedCategory.name,
                onTap: () => AppNavigator.openAcademyGuide(
                  context,
                  guideId: guide.id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
