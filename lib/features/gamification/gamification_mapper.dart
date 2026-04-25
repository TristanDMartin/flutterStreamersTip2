import 'package:flutter/foundation.dart';

import 'models/daily_mission_model.dart';
import 'models/gamification_summary_model.dart';
import 'models/usage_metrics_model.dart';
import 'models/user_entitlements_model.dart';
import 'models/user_progress_bundle.dart';
import 'models/user_subscription_model.dart';
import 'utils/gamification_constants.dart';

/// Parses Firestore user document into the shared read bundle (no XP math).
class GamificationMapper {
  GamificationMapper._();

  static UserProgressBundle userDocToBundle(
    Map<String, dynamic> data, {
    String? uid,
  }) {
    final Object? gam = data['gamification'];
    final Map<String, dynamic>? gamMap =
        gam is Map<String, dynamic> ? gam : null;
    final GamificationSummaryModel historicalProgress =
        _deriveHistoricalSummary(data);
    final GamificationSummaryModel progress = (gamMap == null || gamMap.isEmpty)
        ? historicalProgress
        : _mergeWithHistoricalFallback(
            GamificationSummaryModel.fromFirestoreMap(gamMap),
            historicalProgress,
          );
    final UserSubscriptionModel subscription =
        UserSubscriptionModel.fromUserDocument(data, uid: uid);
    final Object? ent = data['entitlements'];
    final UserEntitlementsModel entitlements = ent is Map<String, dynamic>
        ? UserEntitlementsModel.fromFirestoreMap(ent)
        : const UserEntitlementsModel();
    final Object? use = data['usage'];
    final UsageMetricsModel? usage = use is Map<String, dynamic>
        ? UsageMetricsModel.fromFirestoreMap(use)
        : null;
    final List<DailyMissionModel> missions = _parseMissionList(data);
    final List<DailyMissionModel> historicalMissions =
        _deriveHistoricalMissions(data);
    debugPrint(
      '🎮 ProgressionBundle: level=${progress.level} | rankTitle=${progress.rankTitle} | totalXp=${progress.totalXp} | subscriptionPlan=${subscription.plan.name} | subscriptionStatus=${subscription.status} | missions=${missions.isEmpty ? historicalMissions.length : missions.length}',
    );
    return UserProgressBundle(
      progress: progress,
      subscription: subscription,
      entitlements: entitlements,
      usage: usage,
      missions: missions.isEmpty ? historicalMissions : missions,
    );
  }

  static GamificationSummaryModel _mergeWithHistoricalFallback(
    GamificationSummaryModel existing,
    GamificationSummaryModel historical,
  ) {
    final bool looksUninitialized = existing.totalXp <= 0 &&
        existing.level <= 1 &&
        existing.creatorScore <= 0 &&
        (existing.nextActionHint == null || existing.nextActionHint!.isEmpty);

    if (!looksUninitialized || historical.totalXp <= 0) {
      return existing;
    }

    return historical;
  }

  static List<DailyMissionModel> _parseMissionList(Map<String, dynamic> data) {
    final List<DailyMissionModel> out = <DailyMissionModel>[];
    final Set<String> seenMissionKeys = <String>{};
    void addFrom(Object? raw) {
      if (raw is! List<dynamic>) return;
      for (final Object? item in raw) {
        if (item is Map) {
          final DailyMissionModel mission = DailyMissionModel.fromFirestoreMap(
            Map<String, dynamic>.from(item),
          );
          final String identity = mission.missionId.isNotEmpty
              ? mission.missionId
              : '${mission.templateId ?? ''}|${mission.type}|${mission.title}';
          if (seenMissionKeys.add(identity)) {
            out.add(mission);
          }
        }
      }
    }

    addFrom(data['dailyMissions']);
    addFrom(data['daily_missions']);
    addFrom(data['missions']);
    addFrom(data['weekly_missions']);
    return out;
  }

  static GamificationSummaryModel _deriveHistoricalSummary(
    Map<String, dynamic> data,
  ) {
    final int postCount =
        _readInt(data, <String>['postCount', 'postsCount']) ?? 0;
    final int followerCount =
        _readInt(data, <String>['followerCount', 'followersCount']) ?? 0;
    final int followingCount =
        _readInt(data, <String>['followingCount', 'following_count']) ?? 0;
    final int platformCount = _readCollectionCount(
      data,
      <String>['platforms', 'linkedPlatforms'],
    );
    final bool profileComplete = _hasMeaningfulProfile(data);

    int totalXp = 0;
    if (profileComplete) totalXp += 40;
    if (platformCount > 0) totalXp += 35;
    if (postCount > 0) totalXp += 50;
    totalXp += (postCount.clamp(0, 12)) * 20;
    totalXp += (followingCount.clamp(0, 10)) * 4;
    totalXp += (followerCount.clamp(0, 100)) ~/ 5;

    int level = 1;
    for (int i = 0;
        i < GamificationConstants.cumulativeXpForLevel.length;
        i++) {
      if (totalXp >= GamificationConstants.cumulativeXpForLevel[i]) {
        level = i + 1;
      }
    }

    final double creatorScore = (postCount * 8) +
        (platformCount * 6) +
        (followerCount / 10) +
        (followingCount / 20);

    String? nextActionHint;
    if (!profileComplete) {
      nextActionHint = 'Complete your profile to unlock more progression.';
    } else if (platformCount == 0) {
      nextActionHint = 'Connect your first creator platform.';
    } else if (postCount == 0) {
      nextActionHint = 'Make your first post to kickstart progression.';
    }

    return GamificationSummaryModel(
      level: level,
      totalXp: totalXp,
      streakDays: 0,
      creatorScore: creatorScore,
      rankTitle: GamificationConstants.rankTitleForLevel(level),
      nextActionHint: nextActionHint,
    );
  }

  static List<DailyMissionModel> _deriveHistoricalMissions(
    Map<String, dynamic> data,
  ) {
    final DateTime now = DateTime.now().toUtc();
    final int postCount =
        _readInt(data, <String>['postCount', 'postsCount']) ?? 0;
    final int platformCount = _readCollectionCount(
      data,
      <String>['platforms', 'linkedPlatforms'],
    );
    final bool profileComplete = _hasMeaningfulProfile(data);

    return <DailyMissionModel>[
      _historicalMission(
        missionId: 'historical_onboard_profile',
        templateId: 'onboard_profile_v1',
        title: 'Complete your profile',
        description:
            'Derived from the profile details already on your account.',
        target: 1,
        progress: profileComplete ? 1 : 0,
        rewardXp: 30,
        type: 'onboarding',
        now: now,
      ),
      _historicalMission(
        missionId: 'historical_onboard_platform',
        templateId: 'onboard_platform_v1',
        title: 'Connect your first platform',
        description: 'Synced from your existing linked creator platforms.',
        target: 1,
        progress: platformCount > 0 ? 1 : 0,
        rewardXp: 25,
        type: 'onboarding',
        now: now,
      ),
      _historicalMission(
        missionId: 'historical_onboard_first_post',
        templateId: 'onboard_first_post_v1',
        title: 'Make your first post',
        description:
            'Backfilled from posts already associated with your account.',
        target: 1,
        progress: postCount > 0 ? 1 : 0,
        rewardXp: 40,
        type: 'onboarding',
        now: now,
      ),
    ];
  }

  static DailyMissionModel _historicalMission({
    required String missionId,
    required String templateId,
    required String title,
    required String description,
    required int target,
    required int progress,
    required int rewardXp,
    required String type,
    required DateTime now,
  }) {
    final bool completed = progress >= target && target > 0;
    return DailyMissionModel(
      missionId: missionId,
      templateId: templateId,
      missionCategoryKey: 'historical_backfill',
      type: type,
      status: completed ? 'completed' : 'pending',
      title: title,
      description: description,
      objectiveType: 'historical_backfill',
      target: target,
      progress: progress,
      rewardXp: rewardXp,
      startsAt: now,
      expiresAt: now.add(const Duration(days: 3650)),
      completedAt: completed ? now : null,
      rewardClaimed: completed,
    );
  }

  static bool _hasMeaningfulProfile(Map<String, dynamic> data) {
    final String? displayName = _readString(
      data,
      <String>['displayName', 'display_name'],
    );
    final String? bio = _readString(data, <String>['bio']);
    final String? avatar = _readString(data, <String>['avatarURL', 'photoURL']);
    return (displayName != null && displayName.trim().isNotEmpty) &&
        (bio != null && bio.trim().isNotEmpty) &&
        (avatar != null && avatar.trim().isNotEmpty);
  }

  static int _readCollectionCount(
      Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value is List) return value.length;
    }
    return 0;
  }

  static int? _readInt(Map<String, dynamic> raw, List<String> keys) {
    for (final String key in keys) {
      final Object? value = raw[key];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is num) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final String key in keys) {
      final Object? value = raw[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
