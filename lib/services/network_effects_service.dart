import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_count_fields.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Network effects service - Amplifies content from user's network
/// Implements viral boost from connections and trending in network
class NetworkEffectsService {
  static NetworkEffectsService? _instance;
  static NetworkEffectsService get instance =>
      _instance ??= NetworkEffectsService._();

  NetworkEffectsService._();

  // Network boost multipliers
  static const double connectionsLikedBoost =
      1.5; // Your connections liked this
  static const double trendingInNetworkBoost =
      1.3; // Trending among your network
  static const double similarUsersBoost = 1.2; // Similar users engaged

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
        multiplier *= boost.clamp(1.0, connectionsLikedBoost);
        secureLog('👥 Connections boost: ${connectionsLiked.length} connections liked - ${boost.toStringAsFixed(2)}x');
      }

      // 2. Check if trending in network
      final trendingScore = await _getTrendingInNetworkScore(userId, videoId);
      if (trendingScore > 0.5) {
        multiplier *= trendingInNetworkBoost;
        secureLog('🔥 Trending in network boost - ${trendingInNetworkBoost}x');
      }

      // 3. Check similar users engagement
      final similarUsersScore =
          await _getSimilarUsersEngagement(userId, videoId);
      if (similarUsersScore > 0.6) {
        multiplier *= similarUsersBoost;
        secureLog('👤 Similar users boost - ${similarUsersBoost}x');
      }

      secureLog('✅ Total network boost for $videoId: ${multiplier.toStringAsFixed(2)}x');
      return multiplier;
    } catch (e) {
      secureLog('❌ Error calculating network boost: $e');
      return 1.0;
    }
  }

  /// Get connections who liked a video
  Future<List<String>> _getConnectionsWhoLiked(
      String userId, String videoId) async {
    // ✅ FIX: Querying root 'likes' collection with videoId + userId whereIn is not allowed
    // This requires complex indexes and violates security rules
    // TODO: Use deterministic paths: videos/{videoId}/likes/{uid} with individual get() calls
    // OR: Move this feature to server-side (Cloud Functions)
    // Server should:
    // 1. Query likes using proper schema (videos/{videoId}/likes/{uid})
    // 2. Store aggregated results: network_likes/{userId}/{videoId}
    // 3. Client reads only pre-computed results
    
    secureLog('⚠️ Connections who liked: Feature disabled (should use deterministic paths or server-side)');
    return [];
  }

  /// Calculate if video is trending in user's network
  Future<double> _getTrendingInNetworkScore(
      String userId, String videoId) async {
    // ✅ FIX: Client-side engagement queries are not allowed (requires complex indexes + violates security)
    // This should be computed server-side and exposed via public aggregates
    // TODO: Move to server-side (Cloud Functions)
    // Server should:
    // 1. Compute trending in network (server-side only)
    // 2. Store results in: trending_network/{userId}/{videoId} or public_trending/{timeWindow}
    // 3. Client reads only pre-computed results
    
    secureLog('⚠️ Trending in network score: Feature disabled (should be server-side)');
    return 0.0;
  }

  /// Calculate engagement from similar users
  Future<double> _getSimilarUsersEngagement(
      String userId, String videoId) async {
    // ✅ FIX: Client-side queries to user_retention_profiles and engagement are not allowed
    // These should be computed server-side (Cloud Functions) and exposed via public aggregates
    // Returning safe default to prevent PERMISSION_DENIED errors
    // TODO: Move this feature to server-side
    // Server should:
    // 1. Compute similar users based on categories (server-side only)
    // 2. Calculate engagement metrics (server-side only)
    // 3. Store public aggregates in: public_creator_metrics/{creatorId} or similar
    // 4. Client reads only public aggregates
    
    secureLog('⚠️ Similar users engagement: Feature disabled (should be server-side)');
    return 0.0;
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
      followingCount: UserCountFields.readFollowingCount(data),
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
