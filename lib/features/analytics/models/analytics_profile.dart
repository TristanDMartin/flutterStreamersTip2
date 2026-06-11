import 'package:cloud_firestore/cloud_firestore.dart';

/// users/{uid}/analyticsProfile/profile — server aggregated.
class AnalyticsProfile {
  const AnalyticsProfile({
    required this.favoriteCategories,
    required this.ignoredCategories,
    required this.preferredContentType,
    required this.creatorStage,
    required this.engagementScore,
    required this.churnRisk,
    required this.recommendedNextActions,
    required this.lastActiveAt,
    required this.updatedAt,
    required this.eventCounts,
    required this.recentSearches,
  });

  final Map<String, int> favoriteCategories;
  final Map<String, int> ignoredCategories;
  final String preferredContentType;
  final String creatorStage;
  final int engagementScore;
  final double churnRisk;
  final List<String> recommendedNextActions;
  final DateTime? lastActiveAt;
  final DateTime? updatedAt;
  final Map<String, int> eventCounts;
  final List<String> recentSearches;

  static const AnalyticsProfile empty = AnalyticsProfile(
    favoriteCategories: <String, int>{},
    ignoredCategories: <String, int>{},
    preferredContentType: 'video',
    creatorStage: 'beginner',
    engagementScore: 0,
    churnRisk: 0,
    recommendedNextActions: <String>[],
    lastActiveAt: null,
    updatedAt: null,
    eventCounts: <String, int>{},
    recentSearches: <String>[],
  );

  /// User-facing snapshot — strips internal admin fields.
  AnalyticsProfile toUserFacing() {
    return AnalyticsProfile(
      favoriteCategories: favoriteCategories,
      ignoredCategories: const <String, int>{},
      preferredContentType: preferredContentType,
      creatorStage: creatorStage,
      engagementScore: engagementScore,
      churnRisk: 0,
      recommendedNextActions: recommendedNextActions,
      lastActiveAt: lastActiveAt,
      updatedAt: updatedAt,
      eventCounts: eventCounts,
      recentSearches: recentSearches,
    );
  }

  factory AnalyticsProfile.fromFirestore(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return AnalyticsProfile.empty;
    }
    return AnalyticsProfile(
      favoriteCategories: _readIntMap(raw['favoriteCategories']),
      ignoredCategories: _readIntMap(raw['ignoredCategories']),
      preferredContentType:
          (raw['preferredContentType'] as String?)?.trim() ?? 'video',
      creatorStage: (raw['creatorStage'] as String?)?.trim() ?? 'beginner',
      engagementScore: _readInt(raw['engagementScore']),
      churnRisk: _readDouble(raw['churnRisk']),
      recommendedNextActions: _readStringList(raw['recommendedNextActions']),
      lastActiveAt: _readDate(raw['lastActiveAt']),
      updatedAt: _readDate(raw['updatedAt']),
      eventCounts: _readIntMap(raw['eventCounts']),
      recentSearches: _readStringList(raw['recentSearches']),
    );
  }

  static Map<String, int> _readIntMap(Object? raw) {
    if (raw is! Map) {
      return <String, int>{};
    }
    final Map<String, int> out = <String, int>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      out[entry.key.toString()] = _readInt(entry.value);
    }
    return out;
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) {
      return <String>[];
    }
    return raw.map((dynamic e) => e.toString()).toList();
  }

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }

  static double _readDouble(Object? raw) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw) ?? 0;
    }
    return 0;
  }

  static DateTime? _readDate(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}
