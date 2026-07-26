import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/gamification_constants.dart';

/// Read model for `users/{uid}.gamification` (or embedded map shape).
class GamificationSummaryModel {
  final int level;
  final int totalXp;
  final int streakDays;
  final double creatorScore;
  final String rankTitle;
  final String? streakStatus;
  final String? streakLabel;
  final String? lastActiveDate;
  final String? nextActionHint;
  final DateTime? lastQualifiedActivityAt;

  /// Server-owned progress (from `gamification/state`) when present.
  final int? serverXpInCurrentLevel;
  final int? serverXpToNextLevel;
  final int? serverLevelProgressPct;

  const GamificationSummaryModel({
    required this.level,
    required this.totalXp,
    required this.streakDays,
    required this.creatorScore,
    required this.rankTitle,
    this.streakStatus,
    this.streakLabel,
    this.lastActiveDate,
    this.nextActionHint,
    this.lastQualifiedActivityAt,
    this.serverXpInCurrentLevel,
    this.serverXpToNextLevel,
    this.serverLevelProgressPct,
  });

  factory GamificationSummaryModel.fromFirestoreMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return GamificationSummaryModel(
        level: 1,
        totalXp: 0,
        streakDays: 0,
        creatorScore: 0,
        rankTitle: GamificationConstants.rankTitleForLevel(1),
      );
    }
    final int level = _readInt(raw, <String>['level', 'creatorLevel']) ?? 1;
    final int totalXp =
        _readInt(raw, <String>['totalXp', 'total_xp', 'xp']) ?? 0;
    final int streak = _readInt(raw, <String>[
          'streakLength',
          'streakCount',
          'streakDays',
          'streak_days',
          'currentStreakDays',
        ]) ??
        0;
    final double score = _readDouble(raw, <String>[
          'creatorScore',
          'creator_score',
          'consistencyScore',
        ]) ??
        0;
    final String? storedRank = _readString(raw, <String>[
      'rank_title',
      'rankTitle',
      'rankName',
      'rank',
      'currentTitleLabel',
    ]);
    final String title = _resolveRankTitle(storedRank, level);
    final String? next = _readString(raw, <String>[
      'nextAction',
      'next_action',
      'nextSuggestedAction',
      'nextActionHint',
    ]);
    return GamificationSummaryModel(
      level: level,
      totalXp: totalXp,
      streakDays: streak,
      creatorScore: score,
      rankTitle: title,
      streakStatus: _readString(raw, <String>['streakStatus']),
      streakLabel: _readString(raw, <String>['streakLabel']),
      lastActiveDate: _readString(raw, <String>['lastActiveDate']),
      nextActionHint: next,
      lastQualifiedActivityAt: _readTimestamp(raw, <String>[
        'lastQualifiedActivityAt',
        'last_qualified_activity_at',
      ]),
      serverXpInCurrentLevel: _readInt(raw, <String>[
        'xpInCurrentLevel',
        'xpIntoLevel',
        'currentLevelXp',
      ]),
      serverXpToNextLevel: _readInt(raw, <String>[
        'xpToNextLevel',
        'xpNeededForNextLevel',
        'nextLevelXp',
      ]),
      serverLevelProgressPct: _readInt(raw, <String>[
        'levelProgressPct',
        'levelProgressPercent',
        'progressPercent',
      ]),
    );
  }

  bool get isActiveToday {
    final String today =
        DateTime.now().toUtc().toIso8601String().split('T').first;
    return streakStatus == 'Active today' || lastActiveDate == today;
  }

  String get displayStreakValue {
    if (streakDays > 0) return '$streakDays days';
    return isActiveToday ? 'Active today' : 'Start today';
  }

  String get displayStreakHelper {
    if (streakLabel != null && streakLabel!.isNotEmpty && streakDays > 0) {
      return streakLabel!;
    }
    return isActiveToday ? 'Active today' : 'Complete activity to begin';
  }

  int get xpIntoLevel {
    final int? serverInto = serverXpInCurrentLevel;
    if (serverInto != null && serverInto >= 0) {
      return serverInto;
    }
    final int floor = GamificationConstants.xpFloorForLevel(level);
    return (totalXp - floor).clamp(0, 1 << 30);
  }

  int get xpNeededForNextLevel {
    final int? serverNeed = serverXpToNextLevel;
    if (serverNeed != null && serverNeed > 0) {
      return serverNeed;
    }
    return GamificationConstants.xpSpanIntoNextLevel(level);
  }

  double get progressInLevel {
    final int? pct = serverLevelProgressPct;
    if (pct != null) {
      return (pct.clamp(0, 100)) / 100.0;
    }
    return GamificationConstants.progressInLevel(level, totalXp);
  }
}

const Set<String> _obsoleteRankTitles = <String>{
  'Active Creator',
  'Community Builder',
  'Pro Creator',
  'Emerging Creator',
};

String _resolveRankTitle(String? storedRank, int level) {
  if (storedRank != null &&
      storedRank.isNotEmpty &&
      !_obsoleteRankTitles.contains(storedRank)) {
    return storedRank;
  }
  return GamificationConstants.rankTitleForLevel(level);
}

int? _readInt(Map<String, dynamic> raw, List<String> keys) {
  for (final String k in keys) {
    final Object? v = raw[k];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
  }
  return null;
}

double? _readDouble(Map<String, dynamic> raw, List<String> keys) {
  for (final String k in keys) {
    final Object? v = raw[k];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
  }
  return null;
}

String? _readString(Map<String, dynamic> raw, List<String> keys) {
  for (final String k in keys) {
    final Object? v = raw[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

DateTime? _readTimestamp(Map<String, dynamic> raw, List<String> keys) {
  for (final String k in keys) {
    final Object? v = raw[k];
    if (v == null) continue;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
  }
  return null;
}
