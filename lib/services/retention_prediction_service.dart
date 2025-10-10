import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Retention prediction service - Predicts user return probability
/// Implements session, daily, and weekly retention scoring
class RetentionPredictionService {
  static RetentionPredictionService? _instance;
  static RetentionPredictionService get instance =>
      _instance ??= RetentionPredictionService._();

  RetentionPredictionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Predict if user will watch next video (session retention)
  Future<double> predictNextVideoWatch(String userId) async {
    try {
      // Get user's recent behavior
      final recentEngagement = await _getRecentEngagement(userId, hours: 1);

      double probability = 0.5; // Base 50%

      // Factor 1: Videos watched in current session
      if (recentEngagement.videosWatched > 5) {
        probability += 0.2; // Strong session
      } else if (recentEngagement.videosWatched > 2) {
        probability += 0.1; // Moderate session
      }

      // Factor 2: Engagement actions (likes, comments, shares)
      if (recentEngagement.engagementActions > 3) {
        probability += 0.15; // High engagement
      } else if (recentEngagement.engagementActions > 0) {
        probability += 0.05; // Some engagement
      }

      // Factor 3: Average watch percentage
      if (recentEngagement.avgWatchPercentage > 75) {
        probability += 0.15; // High completion
      } else if (recentEngagement.avgWatchPercentage < 25) {
        probability -= 0.2; // Losing interest
      }

      return probability.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error predicting next video watch: $e');
      return 0.5; // Default
    }
  }

  /// Predict if user will return tomorrow (DAU retention)
  Future<double> predictDailyReturn(String userId) async {
    try {
      final profile = await _getUserRetentionProfile(userId);

      double probability = 0.3; // Base 30%

      // Factor 1: Daily streak
      if (profile.currentStreak >= 7) {
        probability += 0.4; // Strong habit
      } else if (profile.currentStreak >= 3) {
        probability += 0.2; // Building habit
      }

      // Factor 2: Historical DAU rate
      probability += profile.dauRate * 0.3;

      // Factor 3: Last session quality
      if (profile.lastSessionQuality > 0.7) {
        probability += 0.2; // Good last session
      }

      // Factor 4: Time since last visit
      final hoursSinceLastVisit =
          DateTime.now().difference(profile.lastVisitTime).inHours;

      if (hoursSinceLastVisit < 12) {
        probability += 0.1; // Recent visit
      } else if (hoursSinceLastVisit > 48) {
        probability -= 0.15; // Fading engagement
      }

      return probability.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error predicting daily return: $e');
      return 0.3; // Default
    }
  }

  /// Predict if user will engage this week (WAU retention)
  Future<double> predictWeeklyEngagement(String userId) async {
    try {
      final profile = await _getUserRetentionProfile(userId);

      double probability = 0.5; // Base 50%

      // Factor 1: Historical WAU rate
      probability += profile.wauRate * 0.4;

      // Factor 2: Content affinity
      if (profile.favoriteCategories.isNotEmpty) {
        probability += 0.15; // Has preferences
      }

      // Factor 3: Social connections
      if (profile.connectionCount > 10) {
        probability += 0.2; // Network effects
      } else if (profile.connectionCount > 3) {
        probability += 0.1;
      }

      // Factor 4: Creator following
      if (profile.followingCount > 20) {
        probability += 0.15; // Invested in platform
      }

      return probability.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error predicting weekly engagement: $e');
      return 0.5; // Default
    }
  }

  /// Calculate churn risk score (0-1, higher = more risk)
  Future<double> calculateChurnRisk(String userId) async {
    try {
      final profile = await _getUserRetentionProfile(userId);

      double risk = 0.0;

      // Risk factor 1: Days since last visit
      final daysSinceLastVisit =
          DateTime.now().difference(profile.lastVisitTime).inDays;

      if (daysSinceLastVisit > 14) {
        risk += 0.5; // High risk
      } else if (daysSinceLastVisit > 7) {
        risk += 0.3; // Medium risk
      } else if (daysSinceLastVisit > 3) {
        risk += 0.1; // Low risk
      }

      // Risk factor 2: Declining engagement trend
      if (profile.engagementTrend < -0.2) {
        risk += 0.3; // Rapidly declining
      } else if (profile.engagementTrend < 0) {
        risk += 0.1; // Slowly declining
      }

      // Risk factor 3: Session quality drop
      if (profile.lastSessionQuality < 0.3) {
        risk += 0.2; // Poor last session
      }

      // Risk factor 4: No social connections
      if (profile.connectionCount == 0) {
        risk += 0.15; // No network anchor
      }

      return risk.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error calculating churn risk: $e');
      return 0.5; // Default medium risk
    }
  }

  /// Get user retention profile
  Future<UserRetentionProfile> _getUserRetentionProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_retention_profiles')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserRetentionProfile.fromFirestore(doc);
      } else {
        return UserRetentionProfile.createDefault(userId);
      }
    } catch (e) {
      log('❌ Error getting retention profile: $e');
      return UserRetentionProfile.createDefault(userId);
    }
  }

  /// Get recent engagement data
  Future<RecentEngagement> _getRecentEngagement(String userId,
      {required int hours}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: hours));

      final snapshot = await _firestore
          .collection('engagement')
          .where('userId', isEqualTo: userId)
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      int videosWatched = snapshot.docs.length;
      int engagementActions = 0;
      double totalWatchPercentage = 0.0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalWatchPercentage +=
            (data['averageWatchPercentage'] ?? 0.0) as double;

        // Count significant actions
        if ((data['completions'] ?? 0) > 0) engagementActions++;
      }

      final avgWatchPercentage =
          videosWatched > 0 ? totalWatchPercentage / videosWatched : 0.0;

      return RecentEngagement(
        videosWatched: videosWatched,
        engagementActions: engagementActions,
        avgWatchPercentage: avgWatchPercentage,
      );
    } catch (e) {
      log('❌ Error getting recent engagement: $e');
      return RecentEngagement(
        videosWatched: 0,
        engagementActions: 0,
        avgWatchPercentage: 0.0,
      );
    }
  }

  /// Save retention prediction for analytics
  Future<void> saveRetentionPrediction({
    required String userId,
    required double nextVideoProb,
    required double dailyReturnProb,
    required double weeklyEngagementProb,
    required double churnRisk,
  }) async {
    try {
      await _firestore.collection('retention_predictions').doc(userId).set({
        'nextVideoProb': nextVideoProb,
        'dailyReturnProb': dailyReturnProb,
        'weeklyEngagementProb': weeklyEngagementProb,
        'churnRisk': churnRisk,
        'predictedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Retention predictions saved for $userId');
    } catch (e) {
      log('❌ Error saving retention predictions: $e');
    }
  }
}

/// User retention profile model
class UserRetentionProfile {
  final String userId;
  final int currentStreak;
  final double dauRate; // Daily active user rate (0-1)
  final double wauRate; // Weekly active user rate (0-1)
  final double lastSessionQuality; // 0-1
  final DateTime lastVisitTime;
  final List<String> favoriteCategories;
  final int connectionCount;
  final int followingCount;
  final double engagementTrend; // -1 to 1

  UserRetentionProfile({
    required this.userId,
    required this.currentStreak,
    required this.dauRate,
    required this.wauRate,
    required this.lastSessionQuality,
    required this.lastVisitTime,
    required this.favoriteCategories,
    required this.connectionCount,
    required this.followingCount,
    required this.engagementTrend,
  });

  factory UserRetentionProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRetentionProfile(
      userId: doc.id,
      currentStreak: data['currentStreak'] ?? 0,
      dauRate: (data['dauRate'] ?? 0.0).toDouble(),
      wauRate: (data['wauRate'] ?? 0.0).toDouble(),
      lastSessionQuality: (data['lastSessionQuality'] ?? 0.5).toDouble(),
      lastVisitTime:
          (data['lastVisitTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      favoriteCategories: List<String>.from(data['favoriteCategories'] ?? []),
      connectionCount: data['connectionCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      engagementTrend: (data['engagementTrend'] ?? 0.0).toDouble(),
    );
  }

  factory UserRetentionProfile.createDefault(String userId) {
    return UserRetentionProfile(
      userId: userId,
      currentStreak: 0,
      dauRate: 0.0,
      wauRate: 0.0,
      lastSessionQuality: 0.5,
      lastVisitTime: DateTime.now(),
      favoriteCategories: [],
      connectionCount: 0,
      followingCount: 0,
      engagementTrend: 0.0,
    );
  }
}

/// Recent engagement data
class RecentEngagement {
  final int videosWatched;
  final int engagementActions;
  final double avgWatchPercentage;

  RecentEngagement({
    required this.videosWatched,
    required this.engagementActions,
    required this.avgWatchPercentage,
  });
}
