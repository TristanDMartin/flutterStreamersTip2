import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../routing/app_navigator.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyCategoryView extends ConsumerWidget {
  const AcademyCategoryView({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final AsyncValue<AcademyHomeSnapshot> snapshotAsync =
        ref.watch(academyHomeSnapshotProvider);
    return Scaffold(
      backgroundColor: shell.scaffold,
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
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                backgroundColor: shell.scaffold,
                foregroundColor: shell.onChrome,
                title: const Text('Category'),
              ),
              SliverToBoxAdapter(
                child: AcademyGradientHeader(
                  title: resolvedCategory.name,
                  subtitle: resolvedCategory.description.isNotEmpty
                      ? resolvedCategory.description
                      : 'Browse guides in this category',
                  icon: Icons.auto_stories_rounded,
                  xpLabel:
                      '${guides.isNotEmpty ? guides.length : resolvedCategory.guideCount} guides',
                ),
              ),
              if (guides.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AcademyEmptyState(
                    title: 'No guides yet',
                    message:
                        '${resolvedCategory.name} guides will appear here when published.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AcademyTokens.pagePadding,
                    0,
                    AcademyTokens.pagePadding,
                    32,
                  ),
                  sliver: SliverList.separated(
                    itemCount: guides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final AcademyGuideSummary guide = guides[index];
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
