import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../routing/app_navigator.dart';
import '../../../services/creator_intelligence_analytics_service.dart';
import '../../../shared/analytics/analytics_event_constants.dart';
import '../../content_planning/content_plan_detail_view.dart';
import '../../content_planning/content_planning_api_client.dart';
import '../../content_planning/content_planning_models.dart';
import '../../content_planning/content_planning_provider.dart';
import '../../content_planning/content_planning_repository.dart';
import '../../tippy/models/tippy_launch_context.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../widgets/academy_widgets.dart';

class AcademyLessonView extends ConsumerStatefulWidget {
  const AcademyLessonView({
    super.key,
    required this.lessonId,
    this.guideId,
  });

  final String lessonId;
  final String? guideId;

  @override
  ConsumerState<AcademyLessonView> createState() => _AcademyLessonViewState();
}

class _AcademyLessonViewState extends ConsumerState<AcademyLessonView> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _checkedItems = <int>{};
  int? _selectedQuizIndex;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_persistReadingPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreReadingPosition());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_persistReadingPosition);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreReadingPosition() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final AcademyUserProgress? progress = await ref
        .read(academyRepositoryProvider)
        .fetchProgressForLesson(
          userId: user.uid,
          lessonId: widget.lessonId,
        );
    if (!mounted || progress == null || progress.readingPosition <= 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(progress.readingPosition);
  }

  void _persistReadingPosition() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !_scrollController.hasClients) {
      return;
    }
  }

  Future<void> _markOpened({
    required String guideId,
    required AcademyLesson lesson,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final AcademyUserProgress progress = AcademyUserProgress(
      userId: user.uid,
      guideId: guideId,
      lessonId: widget.lessonId,
      status: AcademyProgressStatus.inProgress,
      progressPercent: 10,
      lastOpenedAt: DateTime.now(),
      readingPosition: _scrollController.hasClients
          ? _scrollController.offset
          : 0,
    );
    await ref.read(academyRepositoryProvider).upsertProgress(progress);
    await ref.read(academyXpServiceProvider).maybeAwardFirstGuideOfDay(
          userId: user.uid,
          guideId: guideId,
        );
  }

  Future<void> _completeLesson({
    required String guideId,
    required AcademyLesson lesson,
    int? quizScore,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _isCompleting) {
      return;
    }
    setState(() => _isCompleting = true);
    try {
      final AcademyUserProgress? existing = await ref
          .read(academyRepositoryProvider)
          .fetchProgressForLesson(
            userId: user.uid,
            lessonId: widget.lessonId,
          );
      if (existing?.isCompleted == true) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson already completed.')),
        );
        return;
      }
      await ref.read(academyXpServiceProvider).awardLessonCompleted(
            userId: user.uid,
            guideId: guideId,
            lessonId: widget.lessonId,
          );
      if (quizScore != null) {
        await ref.read(academyXpServiceProvider).awardQuizCompleted(
              userId: user.uid,
              guideId: guideId,
              lessonId: widget.lessonId,
              score: quizScore,
            );
      }
      unawaited(
        CreatorIntelligenceAnalyticsService().trackEvent(
          eventType: AnalyticsEventTypes.courseStepCompleted,
          targetType: AnalyticsTargetTypes.course,
          targetId: widget.lessonId,
          metadata: <String, dynamic>{'guideId': guideId},
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson complete! XP awarded.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  Future<void> _applyToPlanner({
    required String guideId,
    required AcademyApplyAction action,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final ContentPlanningRepository repo =
        ref.read(contentPlanningRepositoryProvider);
    final String idToken = (await user.getIdToken()) ?? '';
    final List<ContentPlan> plans = await repo.listPlans(
      idToken: idToken,
      userId: user.uid,
    );
    ContentPlan plan;
    if (plans.isEmpty) {
      plan = ContentPlan(
        id: const Uuid().v4(),
        userId: user.uid,
        title: 'Academy Actions',
        description: 'Tasks created from Streamer Academy lessons.',
        status: 'planned',
        source: 'academy',
        itemCount: 0,
        items: const <ContentPlanItem>[],
      );
    } else {
      plan = plans.first;
    }
    final ContentPlanItem item = ContentPlanItem(
      id: const Uuid().v4(),
      title: action.plannerItemTitle,
      description: action.plannerItemDescription,
      type: action.plannerItemType,
      status: 'scheduled',
      tags: <String>[
        ...action.tags,
        'academy',
        guideId,
        widget.lessonId,
      ],
      notes:
          'sourceType: academy\nsourceGuideId: $guideId\n'
          'sourceLessonId: ${widget.lessonId}',
    );
    final ContentPlan updated = plan.copyWith(
      items: <ContentPlanItem>[...plan.items, item],
      itemCount: plan.items.length + 1,
    );
    String savedPlanId = plan.id;
    try {
      final ContentPlanningApiClient api = ContentPlanningApiClient();
      if (plans.isEmpty) {
        final DateTime start = DateTime.now();
        savedPlanId = await api.createPlan(
          userId: user.uid,
          title: 'Academy Actions',
          description: 'Tasks created from Streamer Academy lessons.',
          startDate: start,
          endDate: start.add(const Duration(days: 30)),
          source: 'academy',
          items: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'description': item.description ?? '',
              'type': item.type ?? 'post',
              'status': item.status,
              'notes': item.notes,
              'tags': item.tags,
            },
          ],
        );
      } else {
        await api.addPlanItem(
          userId: user.uid,
          planId: plan.id,
          title: item.title,
          type: item.type ?? 'post',
          description: item.description ?? '',
          status: item.status,
          notes: item.notes,
          tags: item.tags,
        );
      }
    } on ContentPlanningApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } on ContentPlanningException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    await ref.read(academyXpServiceProvider).awardPlannerApply(
          userId: user.uid,
          guideId: guideId,
          lessonId: widget.lessonId,
        );
    ref.invalidate(contentPlansProvider);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContentPlanDetailView(
          plan: updated.copyWith(id: savedPlanId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AcademyLesson?> lessonAsync =
        ref.watch(academyLessonProvider(widget.lessonId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Ask Tippy',
            onPressed: () {
              final AcademyLesson? lesson = lessonAsync.valueOrNull;
              AppNavigator.openTippyChat(
                context,
                launchContext: TippyLaunchContext.forAcademyLessonExplain(
                  lessonId: widget.lessonId,
                  title: lesson?.summary.title ?? 'this lesson',
                  guideId: widget.guideId ?? lesson?.summary.guideId,
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
      body: lessonAsync.when(
        loading: () => const AcademySkeletonList(),
        error: (_, __) => AcademyEmptyState(
          title: 'Lesson unavailable',
          message:
              'The Academy could not load this lesson right now. '
              'Your saved progress is safe.',
          onRetry: () => ref.invalidate(academyLessonProvider(widget.lessonId)),
        ),
        data: (AcademyLesson? lesson) {
          if (lesson == null) {
            return const AcademyEmptyState(
              title: 'Lesson not found',
              message: 'This lesson may have been removed or unpublished.',
            );
          }
          final String guideId =
              widget.guideId ?? lesson.summary.guideId;
          unawaited(_markOpened(guideId: guideId, lesson: lesson));
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AcademyTokens.pagePadding),
                  children: <Widget>[
                    Text(
                      lesson.summary.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...lesson.contentBlocks.asMap().entries.map(
                          (MapEntry<int, AcademyContentBlock> entry) {
                            return _LessonBlock(
                              block: entry.value,
                              index: entry.key,
                              checkedItems: _checkedItems,
                              selectedQuizIndex: _selectedQuizIndex,
                              onChecklistToggle: (int itemIndex) {
                                setState(() {
                                  if (_checkedItems.contains(itemIndex)) {
                                    _checkedItems.remove(itemIndex);
                                  } else {
                                    _checkedItems.add(itemIndex);
                                  }
                                });
                              },
                              onQuizSelect: (int? value) {
                                setState(() => _selectedQuizIndex = value);
                              },
                            );
                          },
                        ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AcademyTokens.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (lesson.applyAction != null)
                        OutlinedButton(
                          onPressed: () => _applyToPlanner(
                            guideId: guideId,
                            action: lesson.applyAction!,
                          ),
                          child: Text(lesson.applyAction!.title),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _isCompleting
                            ? null
                            : () => _completeLesson(
                                  guideId: guideId,
                                  lesson: lesson,
                                  quizScore: _selectedQuizIndex,
                                ),
                        child: Text(
                          _isCompleting
                              ? 'Completing...'
                              : 'Complete Lesson',
                        ),
                      ),
                    ],
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

class _LessonBlock extends StatelessWidget {
  const _LessonBlock({
    required this.block,
    required this.index,
    required this.checkedItems,
    required this.selectedQuizIndex,
    required this.onChecklistToggle,
    required this.onQuizSelect,
  });

  final AcademyContentBlock block;
  final int index;
  final Set<int> checkedItems;
  final int? selectedQuizIndex;
  final ValueChanged<int> onChecklistToggle;
  final ValueChanged<int?> onQuizSelect;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case AcademyContentBlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        );
      case AcademyContentBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(block.content),
        );
      case AcademyContentBlockType.image:
        if (block.url == null || block.url!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  block.url!,
                  fit: BoxFit.cover,
                  semanticLabel: block.caption ?? 'Lesson image',
                ),
              ),
              if (block.caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    block.caption!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      case AcademyContentBlockType.list:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.items
                .map(
                  (String item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('• '),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        );
      case AcademyContentBlockType.tip:
      case AcademyContentBlockType.callout:
      case AcademyContentBlockType.warning:
        final Color color = block.type == AcademyContentBlockType.warning
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(block.content),
        );
      case AcademyContentBlockType.checklist:
        return Column(
          children: block.items.asMap().entries.map(
                (MapEntry<int, String> entry) {
                  final bool checked = checkedItems.contains(entry.key);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    onChanged: (_) => onChecklistToggle(entry.key),
                    title: Text(entry.value),
                  );
                },
              ).toList(),
        );
      case AcademyContentBlockType.quiz:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                block.content,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...block.options.asMap().entries.map(
                    (MapEntry<int, String> entry) => RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: entry.key,
                      groupValue: selectedQuizIndex,
                      onChanged: onQuizSelect,
                      title: Text(entry.value),
                    ),
                  ),
            ],
          ),
        );
      case AcademyContentBlockType.video:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.play_circle_fill_rounded),
            title: Text(block.caption ?? 'Watch lesson video'),
            subtitle: Text(block.url ?? ''),
          ),
        );
      case AcademyContentBlockType.link:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.content,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    }
  }
}
