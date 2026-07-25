import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../gamification/create_gamification_event.dart';
import '../../gamification/daily_activity_service.dart';
import '../../gamification/gamification_event_types.dart';
import '../data/academy_repository.dart';
import '../models/academy_models.dart';

class AcademyXpService {
  AcademyXpService({
    AcademyRepository? repository,
  }) : _repository = repository ?? AcademyRepository();

  final AcademyRepository _repository;

  static const String _firstGuideDayKeyPrefix = 'academy_first_guide_day_';

  Future<void> maybeAwardFirstGuideOfDay({
    required String userId,
    required String guideId,
    AcademyXpRewards? rewards,
  }) async {
    final AcademyXpRewards xp =
        rewards ?? await _repository.fetchXpRewards();
    final String todayKey = _todayKey();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String cacheKey = '$_firstGuideDayKeyPrefix$userId';
    if (prefs.getString(cacheKey) == todayKey) {
      return;
    }
    await createGamificationEvent(
      type: GamificationEventTypes.academyGuideViewed,
      entityType: 'guide',
      entityId: guideId,
      eventId: 'academy_first_guide_day_${userId}_$todayKey',
      metadata: <String, dynamic>{
        'xpHint': xp.openFirstGuideOfDay,
        'surface': 'academy',
      },
    );
    await prefs.setString(cacheKey, todayKey);
  }

  Future<void> awardLessonCompleted({
    required String userId,
    required String guideId,
    required String lessonId,
    AcademyXpRewards? rewards,
  }) async {
    final AcademyUserProgress? existing =
        await _repository.fetchProgressForLesson(
      userId: userId,
      lessonId: lessonId,
    );
    if (existing?.isCompleted == true) {
      return;
    }
    final AcademyXpRewards xp =
        rewards ?? await _repository.fetchXpRewards();
    final String eventId = 'academy_lesson_completed:$userId:$lessonId';
    await createGamificationEvent(
      type: GamificationEventTypes.academyLessonCompleted,
      entityType: 'lesson',
      entityId: lessonId,
      eventId: eventId,
      metadata: <String, dynamic>{
        'guideId': guideId,
        'xpHint': xp.completeLesson,
        'surface': 'academy',
      },
    );
    DailyActivityService.instance.maybeEmitDayQualified(source: 'academy');
    await _repository.upsertProgress(
      (existing ??
              AcademyUserProgress(
                userId: userId,
                guideId: guideId,
                lessonId: lessonId,
              ))
          .copyWith(
        status: AcademyProgressStatus.completed,
        progressPercent: 100,
        completedAt: DateTime.now(),
        completionEventId: eventId,
      ),
    );
  }

  Future<void> awardQuizCompleted({
    required String userId,
    required String guideId,
    required String lessonId,
    required int score,
    AcademyXpRewards? rewards,
  }) async {
    final AcademyXpRewards xp =
        rewards ?? await _repository.fetchXpRewards();
    final String eventId =
        'academy_quiz_completed:${userId}:$lessonId';
    await createGamificationEvent(
      type: GamificationEventTypes.academyLessonCompleted,
      entityType: 'lesson',
      entityId: lessonId,
      eventId: eventId,
      metadata: <String, dynamic>{
        'guideId': guideId,
        'quizScore': score,
        'xpHint': xp.completeQuiz,
        'surface': 'academy',
        'completionType': 'quiz',
      },
    );
  }

  Future<void> awardPathCompleted({
    required String userId,
    required String pathId,
    AcademyXpRewards? rewards,
  }) async {
    final AcademyXpRewards xp =
        rewards ?? await _repository.fetchXpRewards();
    await createGamificationEvent(
      type: GamificationEventTypes.academyTrackCompleted,
      entityType: 'path',
      entityId: pathId,
      eventId: 'academy_path_completed:${userId}:$pathId',
      metadata: <String, dynamic>{
        'xpHint': xp.finishLearningPath,
        'surface': 'academy',
      },
    );
  }

  Future<void> awardCategoryCompleted({
    required String userId,
    required String categoryId,
    AcademyXpRewards? rewards,
  }) async {
    final AcademyXpRewards xp =
        rewards ?? await _repository.fetchXpRewards();
    await createGamificationEvent(
      type: GamificationEventTypes.academyModuleCompleted,
      entityType: 'category',
      entityId: categoryId,
      eventId: 'academy_category_completed:${userId}:$categoryId',
      metadata: <String, dynamic>{
        'xpHint': xp.completeCategory,
        'surface': 'academy',
      },
    );
  }

  Future<void> awardPlannerApply({
    required String userId,
    required String guideId,
    required String lessonId,
    AcademyXpRewards? rewards,
  }) async {
    final AcademyXpRewards xp =
        rewards ?? await _repository.fetchXpRewards();
    await createGamificationEvent(
      type: GamificationEventTypes.contentPlanItemCreated,
      entityType: 'lesson',
      entityId: lessonId,
      eventId: 'academy_planner_apply:${userId}:$lessonId',
      metadata: <String, dynamic>{
        'guideId': guideId,
        'sourceType': 'academy',
        'sourceGuideId': guideId,
        'sourceLessonId': lessonId,
        'xpHint': xp.applyToContentPlanner,
        'surface': 'academy',
      },
    );
  }

  Future<void> awardGuideBookmarked({
    required String userId,
    required String guideId,
  }) async {
    await createGamificationEvent(
      type: GamificationEventTypes.academyGuideBookmarked,
      entityType: 'guide',
      entityId: guideId,
      eventId: 'academy_guide_saved:${userId}:$guideId',
      metadata: const <String, dynamic>{'surface': 'academy'},
    );
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
