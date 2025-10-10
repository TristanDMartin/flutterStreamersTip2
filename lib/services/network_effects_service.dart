import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Network effects service - Amplifies content from user's network
/// Implements viral boost from connections and trending in network
class NetworkEffectsService {
  static NetworkEffectsService? _instance;
  static NetworkEffectsService get instance =>
      _instance ??= NetworkEffectsService._();

  NetworkEffectsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Network boost multipliers
  static const double CONNECTIONS_LIKED_BOOST =
      1.5; // Your connections liked this
  static const double TRENDING_IN_NETWORK_BOOST =
      1.3; // Trending among your network
  static const double SIMILAR_USERS_BOOST = 1.2; // Similar users engaged

  /// Calculate network effects boost for a video
  Future<double> calculateNetworkBoost({
    required String userId,
    required String videoId,
    required String creatorId,
  }) async {
    try {
      double multiplier = 1.0;

      // 1. Check if connections liked this video
      final connectionsLiked = await _getConnectionsWhoLiked(userId, videoId);
      if (connectionsLiked.isNotEmpty) {
        final boost =
            1.0 + (connectionsLiked.length * 0.1); // +10% per connection
        multiplier *= boost.clamp(1.0, CONNECTIONS_LIKED_BOOST);
        log('👥 Connections boost: ${connectionsLiked.length} connections liked - ${boost.toStringAsFixed(2)}x');
      }

      // 2. Check if trending in network
      final trendingScore = await _getTrendingInNetworkScore(userId, videoId);
      if (trendingScore > 0.5) {
        multiplier *= TRENDING_IN_NETWORK_BOOST;
        log('🔥 Trending in network boost - ${TRENDING_IN_NETWORK_BOOST}x');
      }

      // 3. Check similar users engagement
      final similarUsersScore =
          await _getSimilarUsersEngagement(userId, videoId);
      if (similarUsersScore > 0.6) {
        multiplier *= SIMILAR_USERS_BOOST;
        log('👤 Similar users boost - ${SIMILAR_USERS_BOOST}x');
      }

      log('✅ Total network boost for $videoId: ${multiplier.toStringAsFixed(2)}x');
      return multiplier;
    } catch (e) {
      log('❌ Error calculating network boost: $e');
      return 1.0;
    }
  }

  /// Get connections who liked a video
  Future<List<String>> _getConnectionsWhoLiked(
      String userId, String videoId) async {
    try {
      // Get user's connections
      final connectionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .where('followState', whereIn: ['mutual', 'following']).get();

      final connectionIds =
          connectionsSnapshot.docs.map((doc) => doc.id).toList();

      if (connectionIds.isEmpty) return [];

      // Check which connections liked this video
      final List<String> likedByConnections = [];

      // Query in chunks of 10 (Firestore limit)
      for (int i = 0; i < connectionIds.length; i += 10) {
        final chunk = connectionIds.skip(i).take(10).toList();

        final likesSnapshot = await _firestore
            .collection('likes')
            .where('videoId', isEqualTo: videoId)
            .where('userId', whereIn: chunk)
            .get();

        likedByConnections.addAll(likesSnapshot.docs.map((doc) => doc.id));
      }

      return likedByConnections;
    } catch (e) {
      log('❌ Error getting connections who liked: $e');
      return [];
    }
  }

  /// Calculate if video is trending in user's network
  Future<double> _getTrendingInNetworkScore(
      String userId, String videoId) async {
    try {
      // Get user's connections
      final connectionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .limit(100)
          .get();

      final connectionIds =
          connectionsSnapshot.docs.map((doc) => doc.id).toList();

      if (connectionIds.isEmpty) return 0.0;

      // Count engagements from network in last 24 hours
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      int networkEngagements = 0;

      // Query engagements from connections
      for (int i = 0; i < connectionIds.length; i += 10) {
        final chunk = connectionIds.skip(i).take(10).toList();

        final engagementSnapshot = await _firestore
            .collection('engagement')
            .where('userId', whereIn: chunk)
            .where('videoId', isEqualTo: videoId)
            .where('lastUpdated', isGreaterThan: Timestamp.fromDate(cutoff))
            .get();

        networkEngagements += engagementSnapshot.docs.length;
      }

      // Calculate trending score (% of network that engaged)
      final trendingScore = networkEngagements / connectionIds.length;

      log('🔥 Trending score: $networkEngagements/${connectionIds.length} = ${trendingScore.toStringAsFixed(2)}');

      return trendingScore;
    } catch (e) {
      log('❌ Error calculating trending score: $e');
      return 0.0;
    }
  }

  /// Calculate engagement from similar users
  Future<double> _getSimilarUsersEngagement(
      String userId, String videoId) async {
    try {
      // Get user's favorite categories
      final userDoc = await _firestore
          .collection('user_retention_profiles')
          .doc(userId)
          .get();

      final favoriteCategories =
          List<String>.from(userDoc.data()?['favoriteCategories'] ?? []);

      if (favoriteCategories.isEmpty) return 0.0;

      // Find users with similar interests
      final similarUsersSnapshot = await _firestore
          .collection('user_retention_profiles')
          .where('favoriteCategories',
              arrayContainsAny: favoriteCategories.take(10).toList())
          .limit(50)
          .get();

      final similarUserIds = similarUsersSnapshot.docs
          .map((doc) => doc.id)
          .where((id) => id != userId)
          .toList();

      if (similarUserIds.isEmpty) return 0.0;

      // Count how many engaged with this video
      int engagedCount = 0;

      for (int i = 0; i < similarUserIds.length; i += 10) {
        final chunk = similarUserIds.skip(i).take(10).toList();

        final engagementSnapshot = await _firestore
            .collection('engagement')
            .where('userId', whereIn: chunk)
            .where('videoId', isEqualTo: videoId)
            .where('engagementScore', isGreaterThan: 10.0)
            .get();

        engagedCount += engagementSnapshot.docs.length;
      }

      final engagementRate = engagedCount / similarUserIds.length;

      log('👥 Similar users engagement: $engagedCount/${similarUserIds.length} = ${engagementRate.toStringAsFixed(2)}');

      return engagementRate;
    } catch (e) {
      log('❌ Error calculating similar users engagement: $e');
      return 0.0;
    }
  }
}

/// User retention profile
class UserRetentionProfile {
  final String userId;
  final int currentStreak;
  final double dauRate;
  final double wauRate;
  final double lastSessionQuality;
  final DateTime lastVisitTime;
  final List<String> favoriteCategories;
  final int connectionCount;
  final int followingCount;
  final double engagementTrend;

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
