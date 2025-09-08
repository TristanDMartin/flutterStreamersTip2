import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class EngagementTrackingService {
  static const String _videosCollection = 'videos';
  static const String _engagementCollection = 'video_engagement';
  static const String _analyticsCollection = 'video_analytics';
  static const String _feedCollection = 'feed_algorithm';

  // Track video view
  Future<void> trackVideoView({
    required String videoId,
    required String viewerId,
    required double watchTime, // in seconds
    required double completionRate, // 0.0 to 1.0
  }) async {
    try {
      final engagementData = {
        'videoId': videoId,
        'viewerId': viewerId,
        'watchTime': watchTime,
        'completionRate': completionRate,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'view',
      };

      // Store engagement data
      await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .add(engagementData);

      // Update video analytics
      await _updateVideoAnalytics(videoId, {
        'views': FieldValue.increment(1),
        'totalWatchTime': FieldValue.increment(watchTime),
        'totalCompletionRate': FieldValue.increment(completionRate),
      });

      // Update feed algorithm data
      await _updateFeedAlgorithmData(videoId, viewerId, completionRate);

    } catch (e) {
      debugPrint('Error tracking video view: $e');
    }
  }

  // Track video like
  Future<bool> trackVideoLike({
    required String videoId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      final likeData = {
        'videoId': videoId,
        'userId': userId,
        'isLiked': isLiked,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'like',
      };

      await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .add(likeData);

      // Update video like count
      await FirebaseFirestore.instance
          .collection(_videosCollection)
          .doc(videoId)
          .update({
        'likes': FieldValue.increment(isLiked ? 1 : -1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's liked videos
      await _updateUserLikedVideos(userId, videoId, isLiked);

      return true;
    } catch (e) {
      debugPrint('Error tracking video like: $e');
      return false;
    }
  }

  // Track video comment
  Future<void> trackVideoComment({
    required String videoId,
    required String commenterId,
    required String commentId,
  }) async {
    try {
      final commentData = {
        'videoId': videoId,
        'commenterId': commenterId,
        'commentId': commentId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'comment',
      };

      await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .add(commentData);

      // Update video comment count
      await FirebaseFirestore.instance
          .collection(_videosCollection)
          .doc(videoId)
          .update({
        'comments': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update feed algorithm data
      await _updateFeedAlgorithmData(videoId, commenterId, 1.0);

    } catch (e) {
      debugPrint('Error tracking video comment: $e');
    }
  }

  // Track video share
  Future<void> trackVideoShare({
    required String videoId,
    required String sharerId,
    required String shareType, // 'internal', 'external', 'duet', 'stitch'
  }) async {
    try {
      final shareData = {
        'videoId': videoId,
        'sharerId': sharerId,
        'shareType': shareType,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'share',
      };

      await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .add(shareData);

      // Update video share count
      await FirebaseFirestore.instance
          .collection(_videosCollection)
          .doc(videoId)
          .update({
        'shares': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update feed algorithm data
      await _updateFeedAlgorithmData(videoId, sharerId, 1.0);

    } catch (e) {
      debugPrint('Error tracking video share: $e');
    }
  }

  // Track video favorite
  Future<bool> trackVideoFavorite({
    required String videoId,
    required String userId,
    required bool isFavorited,
  }) async {
    try {
      final favoriteData = {
        'videoId': videoId,
        'userId': userId,
        'isFavorited': isFavorited,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'favorite',
      };

      await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .add(favoriteData);

      // Update user's favorite videos
      await _updateUserFavoriteVideos(userId, videoId, isFavorited);

      return true;
    } catch (e) {
      debugPrint('Error tracking video favorite: $e');
      return false;
    }
  }

  // Get video engagement metrics
  Future<VideoEngagementMetrics> getVideoEngagementMetrics(String videoId) async {
    try {
      final videoDoc = await FirebaseFirestore.instance
          .collection(_videosCollection)
          .doc(videoId)
          .get();

      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }

      final videoData = videoDoc.data()!;
      
      // Get detailed engagement data
      final engagementQuery = await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .where('videoId', isEqualTo: videoId)
          .get();

      final engagements = engagementQuery.docs.map((doc) => doc.data()).toList();
      
      // Calculate metrics
      final views = engagements.where((e) => e['type'] == 'view').length;
      final likes = engagements.where((e) => e['type'] == 'like' && e['isLiked'] == true).length;
      final comments = engagements.where((e) => e['type'] == 'comment').length;
      final shares = engagements.where((e) => e['type'] == 'share').length;
      final favorites = engagements.where((e) => e['type'] == 'favorite' && e['isFavorited'] == true).length;

      // Calculate average completion rate
      final viewEngagements = engagements.where((e) => e['type'] == 'view').toList();
      final avgCompletionRate = viewEngagements.isEmpty 
          ? 0.0 
          : viewEngagements.map((e) => e['completionRate'] as double).reduce((a, b) => a + b) / viewEngagements.length;

      // Calculate engagement rate
      final totalEngagements = likes + comments + shares + favorites;
      final engagementRate = views > 0 ? totalEngagements / views : 0.0;

      return VideoEngagementMetrics(
        videoId: videoId,
        views: views,
        likes: likes,
        comments: comments,
        shares: shares,
        favorites: favorites,
        averageCompletionRate: avgCompletionRate,
        engagementRate: engagementRate,
        createdAt: videoData['createdAt'] as Timestamp?,
        updatedAt: videoData['updatedAt'] as Timestamp?,
      );

    } catch (e) {
      debugPrint('Error getting video engagement metrics: $e');
      rethrow;
    }
  }

  // Get trending videos based on engagement
  Future<List<String>> getTrendingVideoIds({
    int limit = 20,
    Duration timeWindow = const Duration(hours: 24),
  }) async {
    try {
      final cutoffTime = Timestamp.fromDate(
        DateTime.now().subtract(timeWindow),
      );

      // Get videos with high engagement in the time window
      final engagementQuery = await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .where('timestamp', isGreaterThan: cutoffTime)
          .get();

      // Group by video ID and calculate engagement scores
      final videoEngagementScores = <String, double>{};
      
      for (final doc in engagementQuery.docs) {
        final data = doc.data();
        final videoId = data['videoId'] as String;
        final type = data['type'] as String;
        
        // Weight different engagement types
        double weight = 1.0;
        switch (type) {
          case 'like':
            weight = 1.0;
            break;
          case 'comment':
            weight = 2.0;
            break;
          case 'share':
            weight = 3.0;
            break;
          case 'favorite':
            weight = 1.5;
            break;
          case 'view':
            final completionRate = data['completionRate'] as double? ?? 0.0;
            weight = completionRate * 0.5; // Weight views by completion rate
            break;
        }

        videoEngagementScores[videoId] = (videoEngagementScores[videoId] ?? 0.0) + weight;
      }

      // Sort by engagement score and return top video IDs
      final sortedVideos = videoEngagementScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedVideos
          .take(limit)
          .map((entry) => entry.key)
          .toList();

    } catch (e) {
      debugPrint('Error getting trending videos: $e');
      return [];
    }
  }

  // Update feed algorithm data
  Future<void> _updateFeedAlgorithmData(
    String videoId,
    String userId,
    double engagementScore,
  ) async {
    try {
      final algorithmData = {
        'videoId': videoId,
        'userId': userId,
        'engagementScore': engagementScore,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(_feedCollection)
          .add(algorithmData);

    } catch (e) {
      debugPrint('Error updating feed algorithm data: $e');
    }
  }

  // Update video analytics
  Future<void> _updateVideoAnalytics(
    String videoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(_analyticsCollection)
          .doc(videoId)
          .set(updates, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Error updating video analytics: $e');
    }
  }

  // Update user's liked videos
  Future<void> _updateUserLikedVideos(
    String userId,
    String videoId,
    bool isLiked,
  ) async {
    try {
      final userLikesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('liked_videos')
          .doc(videoId);

      if (isLiked) {
        await userLikesRef.set({
          'videoId': videoId,
          'likedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userLikesRef.delete();
      }

    } catch (e) {
      debugPrint('Error updating user liked videos: $e');
    }
  }

  // Update user's favorite videos
  Future<void> _updateUserFavoriteVideos(
    String userId,
    String videoId,
    bool isFavorited,
  ) async {
    try {
      final userFavoritesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorite_videos')
          .doc(videoId);

      if (isFavorited) {
        await userFavoritesRef.set({
          'videoId': videoId,
          'favoritedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userFavoritesRef.delete();
      }

    } catch (e) {
      debugPrint('Error updating user favorite videos: $e');
    }
  }

  // Get user's engagement history
  Future<List<EngagementEvent>> getUserEngagementHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection(_engagementCollection)
          .where('viewerId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return EngagementEvent(
          id: doc.id,
          videoId: data['videoId'] as String,
          userId: data['viewerId'] as String? ?? data['userId'] as String,
          type: data['type'] as String,
          timestamp: data['timestamp'] as Timestamp,
          data: data,
        );
      }).toList();

    } catch (e) {
      debugPrint('Error getting user engagement history: $e');
      return [];
    }
  }
}

// Data classes
class VideoEngagementMetrics {
  final String videoId;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int favorites;
  final double averageCompletionRate;
  final double engagementRate;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const VideoEngagementMetrics({
    required this.videoId,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.favorites,
    required this.averageCompletionRate,
    required this.engagementRate,
    this.createdAt,
    this.updatedAt,
  });
}

class EngagementEvent {
  final String id;
  final String videoId;
  final String userId;
  final String type;
  final Timestamp timestamp;
  final Map<String, dynamic> data;

  const EngagementEvent({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.type,
    required this.timestamp,
    required this.data,
  });
}
