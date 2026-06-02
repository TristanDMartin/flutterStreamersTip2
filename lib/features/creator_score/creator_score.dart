import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorScore {
  const CreatorScore({
    required this.score,
    required this.rankLabel,
    required this.level,
    required this.consistencyScore,
    required this.contentScore,
    required this.networkingScore,
    required this.engagementScore,
    required this.recommendations,
    this.isAvailable = true,
    this.lastCalculatedAt,
  });

  final int score;
  final String rankLabel;
  final int level;
  final int consistencyScore;
  final int contentScore;
  final int networkingScore;
  final int engagementScore;
  final List<String> recommendations;
  final bool isAvailable;
  final DateTime? lastCalculatedAt;

  static const CreatorScore fallback = CreatorScore(
    score: 0,
    rankLabel: 'New Creator',
    level: 1,
    consistencyScore: 0,
    contentScore: 0,
    networkingScore: 0,
    engagementScore: 0,
    recommendations: <String>[
      'Upload your first clip',
      'Complete your Creator Card',
      'Connect a platform',
    ],
    isAvailable: false,
  );

  factory CreatorScore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return fallback;
    }

    return CreatorScore(
      score: _readScore(data['score']),
      rankLabel: _readString(data['rankLabel'], fallback.rankLabel),
      level: _readScore(data['level'], fallbackValue: fallback.level, min: 1),
      consistencyScore: _readScore(data['consistencyScore']),
      contentScore: _readScore(data['contentScore']),
      networkingScore: _readScore(data['networkingScore']),
      engagementScore: _readScore(data['engagementScore']),
      recommendations: _readRecommendations(data['recommendations']),
      isAvailable: true,
      lastCalculatedAt: _readDate(data['lastCalculatedAt']),
    );
  }

  static int _readScore(
    Object? value, {
    int fallbackValue = 0,
    int min = 0,
  }) {
    final int parsed = switch (value) {
      int n => n,
      num n => n.round(),
      String s => int.tryParse(s) ?? fallbackValue,
      _ => fallbackValue,
    };
    return parsed.clamp(min, 100);
  }

  static String _readString(Object? value, String fallbackValue) {
    final String? text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? fallbackValue : text;
  }

  static List<String> _readRecommendations(Object? value) {
    if (value is! List) {
      return fallback.recommendations;
    }
    final List<String> items = value
        .map((Object? item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    return items.isEmpty ? fallback.recommendations : items;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
