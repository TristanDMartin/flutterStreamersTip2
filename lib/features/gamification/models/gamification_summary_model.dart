import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/gamification_constants.dart';

/// Read model for `users/{uid}.gamification` (or embedded map shape).
class GamificationSummaryModel {
  final int level;
  final int totalXp;
  final int streakDays;
  final double creatorScore;
  final String rankTitle;
  final String? nextActionHint;
  final DateTime? lastQualifiedActivityAt;

  const GamificationSummaryModel({
    required this.level,
    required this.totalXp,
    required this.streakDays,
    required this.creatorScore,
    required this.rankTitle,
    this.nextActionHint,
    this.lastQualifiedActivityAt,
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
    final int streak =
        _readInt(raw, <String>['streakDays', 'streak_days']) ?? 0;
    final double score =
        _readDouble(raw, <String>['creatorScore', 'creator_score']) ?? 0;
    final String? storedRank = _readString(raw, <String>[
      'rank_title',
      'rankTitle',
    ]);
    final String title = (storedRank != null && storedRank.isNotEmpty)
        ? storedRank
        : GamificationConstants.rankTitleForLevel(level);
    final String? next = _readString(raw, <String>[
      'nextAction',
      'next_action',
      'nextSuggestedAction',
    ]);
    return GamificationSummaryModel(
      level: level,
      totalXp: totalXp,
      streakDays: streak,
      creatorScore: score,
      rankTitle: title,
      nextActionHint: next,
      lastQualifiedActivityAt: _readTimestamp(raw, <String>[
        'lastQualifiedActivityAt',
        'last_qualified_activity_at',
      ]),
    );
  }

  int get xpIntoLevel {
    final int floor = GamificationConstants.xpFloorForLevel(level);
    return (totalXp - floor).clamp(0, 1 << 30);
  }

  int get xpNeededForNextLevel =>
      GamificationConstants.xpSpanIntoNextLevel(level);

  double get progressInLevel =>
      GamificationConstants.progressInLevel(level, totalXp);
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
