import 'package:flutter/foundation.dart';

import 'models/daily_mission_model.dart';
import 'models/gamification_celebration_state.dart';
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
    Map<String, dynamic>? gamificationState,
  }) {
    final Map<String, dynamic>? stateMap = gamificationState;
    final Object? gam = data['gamification'];
    final Map<String, dynamic>? gamMap =
        gam is Map<String, dynamic> ? gam : null;
    final Object? summary = data['progressionSummary'];
    final Map<String, dynamic>? summaryMap =
        summary is Map<String, dynamic> ? summary : null;
    final Map<String, dynamic> topLevelProgress = _topLevelProgressMap(data);
    final GamificationSummaryModel historicalProgress =
        _deriveHistoricalSummary(data);
    // progressionSummary is onboarding rollup only — never let its XP/level
    // override global gamification / state (website + app must match).
    final Map<String, dynamic> progressMap = <String, dynamic>{
      if (gamMap != null) ..._progressWithoutInventedScore(gamMap),
      ...topLevelProgress,
      if (summaryMap != null) ..._progressFromProgressionSummary(summaryMap),
      if (stateMap != null) ..._progressFromGamificationState(stateMap),
    };
    final GamificationSummaryModel progress = progressMap.isEmpty
        ? historicalProgress
        : _mergeWithHistoricalFallback(
            GamificationSummaryModel.fromFirestoreMap(progressMap),
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
    final List<DailyMissionModel> stateMissions =
        _parseMissionsFromGamificationState(stateMap);
    final List<DailyMissionModel> historicalMissions =
        _deriveHistoricalMissions(data);
    final List<DailyMissionModel> resolvedMissions = missions.isNotEmpty
        ? missions
        : (stateMissions.isNotEmpty ? stateMissions : historicalMissions);
    debugPrint(
      '🎮 ProgressionBundle: level=${progress.level} | rankTitle=${progress.rankTitle} | totalXp=${progress.totalXp} | streak=${progress.streakDays} | score=${progress.creatorScore} | subscriptionPlan=${subscription.plan.name} | subscriptionStatus=${subscription.status} | missions=${resolvedMissions.length}',
    );
    final GamificationCelebrationState celebration =
        GamificationCelebrationState.fromFirestoreMap(stateMap);
    return UserProgressBundle(
      progress: progress,
      subscription: subscription,
      entitlements: entitlements,
      usage: usage,
      missions: resolvedMissions,
      celebration: celebration,
    );
  }

  /// Onboarding rollup only — streak/score/hint, not global XP/level/rank.
  static Map<String, dynamic> _progressFromProgressionSummary(
    Map<String, dynamic> summary,
  ) {
    final Map<String, dynamic> out = <String, dynamic>{};
    final double? creatorScore = _readDouble(
      summary,
      <String>['creatorScore', 'creator_score'],
    );
    if (creatorScore != null) {
      out['creatorScore'] = creatorScore;
    }
    final int? streak = _readInt(
      summary,
      <String>['streakCount', 'streakDays', 'streak_days'],
    );
    if (streak != null) {
      out['streakDays'] = streak;
    }
    final String? nextAction = _readString(
      summary,
      <String>['nextAction', 'next_action', 'nextActionHint'],
    );
    if (nextAction != null) {
      out['nextActionHint'] = nextAction;
    }
    return out;
  }

  /// Maps `users/{uid}/gamification/state` onto summary fields (display only).
  ///
  /// Accepts both Cloudflare Worker field names (`streakLength`, `creatorScore`,
  /// relative `currentLevelXp`/`nextLevelXp`) and Firebase CF names
  /// (`streakCount`, `consistencyScore`, absolute floor/ceiling XP).
  static Map<String, dynamic> _progressFromGamificationState(
    Map<String, dynamic> state,
  ) {
    final Map<String, dynamic> out = <String, dynamic>{};
    final int? xp = _readInt(state, <String>['xp', 'totalXp', 'totalXP']);
    if (xp != null) {
      out['totalXp'] = xp;
    }
    final int? level = _readInt(state, <String>['level', 'currentLevel']);
    if (level != null) {
      out['level'] = level;
    }
    final String? rank = _readString(state, <String>[
      'rank',
      'rankTitle',
      'rankName',
      'currentTitleLabel',
    ]);
    if (rank != null) {
      out['rankTitle'] = rank;
    }
    final int? streak = _readInt(state, <String>[
      'streakLength',
      'streakCount',
      'streakDays',
      'currentStreakDays',
    ]);
    if (streak != null) {
      out['streakDays'] = streak;
    }
    final double? score = _readDouble(state, <String>[
      'creatorScore',
      'creator_score',
    ]);
    if (score != null) {
      out['creatorScore'] = score;
    }
    final int? progressPct = _readInt(state, <String>[
      'progressPercent',
      'levelProgressPct',
      'levelProgressPercent',
    ]);
    if (progressPct != null) {
      out['levelProgressPct'] = progressPct;
    }
    final int? currentLevelXp = _readInt(state, <String>[
      'currentLevelXp',
      'xpInCurrentLevel',
      'xpIntoLevel',
    ]);
    final int? nextLevelXp = _readInt(state, <String>[
      'nextLevelXp',
      'xpToNextLevel',
      'xpNeededForNextLevel',
    ]);
    if (currentLevelXp != null && nextLevelXp != null && xp != null) {
      // Worker writes relative into/need; CF writes absolute floor/ceiling.
      if (nextLevelXp > xp) {
        final int floor = currentLevelXp;
        final int span = (nextLevelXp - floor).clamp(1, 1 << 30);
        out['xpInCurrentLevel'] = (xp - floor).clamp(0, span);
        out['xpToNextLevel'] = span;
      } else {
        out['xpInCurrentLevel'] = currentLevelXp;
        out['xpToNextLevel'] = nextLevelXp <= 0 ? 1 : nextLevelXp;
      }
    }
    return out;
  }

  /// Worker `activeMissions` are full objects; CF may store id strings only.
  static List<DailyMissionModel> _parseMissionsFromGamificationState(
    Map<String, dynamic>? state,
  ) {
    if (state == null) {
      return <DailyMissionModel>[];
    }
    final Object? raw = state['activeMissions'];
    if (raw is! List<dynamic>) {
      return <DailyMissionModel>[];
    }
    final List<DailyMissionModel> out = <DailyMissionModel>[];
    final DateTime now = DateTime.now().toUtc();
    for (final Object? item in raw) {
      if (item is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        // Worker preview shape uses currentCount/targetCount/xpReward.
        if (!map.containsKey('progress') && map.containsKey('currentCount')) {
          map['progress'] = map['currentCount'];
        }
        if (!map.containsKey('target') && map.containsKey('targetCount')) {
          map['target'] = map['targetCount'];
        }
        if (!map.containsKey('rewardXp') && map.containsKey('xpReward')) {
          map['rewardXp'] = map['xpReward'];
        }
        if (!map.containsKey('missionId') && map.containsKey('id')) {
          map['missionId'] = map['id'];
        }
        final DailyMissionModel mission =
            DailyMissionModel.fromFirestoreMap(map);
        if (mission.missionId.isNotEmpty) {
          out.add(mission);
        }
      } else if (item is String && item.trim().isNotEmpty) {
        out.add(
          DailyMissionModel(
            missionId: item.trim(),
            type: 'daily',
            status: 'active',
            title: item.trim().replaceAll('_', ' '),
            description: 'Synced from your gamification state.',
            objectiveType: 'state_active_mission',
            target: 1,
            progress: 0,
            rewardXp: 0,
            startsAt: now,
            expiresAt: now.add(const Duration(days: 7)),
          ),
        );
      }
    }
    return out;
  }

  static Map<String, dynamic> _topLevelProgressMap(Map<String, dynamic> data) {
    final Map<String, dynamic> out = <String, dynamic>{};
    final int? totalXp = _readInt(data, <String>['totalXP', 'totalXp']);
    if (totalXp != null) out['totalXp'] = totalXp;
    final int? level = _readInt(data, <String>['level']);
    if (level != null) out['level'] = level;
    final double? creatorScore =
        _readDouble(data, <String>['creatorScore', 'creator_score']);
    if (creatorScore != null) out['creatorScore'] = creatorScore;
    final int? streakDays =
        _readInt(data, <String>['streakCount', 'streakDays', 'streak_days']);
    if (streakDays != null) out['streakDays'] = streakDays;
    final String? rankName = _readString(data, <String>[
      'rankName',
      'rankTitle',
    ]);
    if (rankName != null) out['rankTitle'] = rankName;
    return out;
  }

  /// Legacy `users/{uid}.gamification` may carry a stale `creatorScore`.
  /// Prefer Worker `gamification/state` / summary for score; keep XP/level/streak.
  static Map<String, dynamic> _progressWithoutInventedScore(
    Map<String, dynamic> gamMap,
  ) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(gamMap);
    out.remove('creatorScore');
    out.remove('creator_score');
    out.remove('consistencyScore');
    return out;
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

    // Never adopt a client-invented historical creatorScore.
    return GamificationSummaryModel(
      level: historical.level,
      totalXp: historical.totalXp,
      streakDays: historical.streakDays,
      creatorScore: 0,
      rankTitle: historical.rankTitle,
      streakStatus: historical.streakStatus,
      streakLabel: historical.streakLabel,
      lastActiveDate: historical.lastActiveDate,
      nextActionHint: historical.nextActionHint,
      lastQualifiedActivityAt: historical.lastQualifiedActivityAt,
      serverXpInCurrentLevel: historical.serverXpInCurrentLevel,
      serverXpToNextLevel: historical.serverXpToNextLevel,
      serverLevelProgressPct: historical.serverLevelProgressPct,
    );
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

    int level = GamificationConstants.levelFromTotalXp(totalXp);

    final double creatorScore = 0;

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

  static double? _readDouble(Map<String, dynamic> raw, List<String> keys) {
    for (final String key in keys) {
      final Object? value = raw[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
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
