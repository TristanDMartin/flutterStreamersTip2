import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';
import '../models/home_video.dart';
import '../models/video_thumbnails.dart';
import '../models/trending_creator.dart';
import '../services/logging_service.dart';

/// Helper class to track trending scores for creators
class TrendingCreatorScore {
  final String creatorId;
  double totalScore;
  int videoCount;
  double bestVideoScore;
  Timestamp? latestVideoTime;

  TrendingCreatorScore({
    required this.creatorId,
    required this.totalScore,
    required this.videoCount,
    required this.bestVideoScore,
    this.latestVideoTime,
  });

  void addVideoScore(double videoScore) {
    totalScore += videoScore;
    videoCount++;
    if (videoScore > bestVideoScore) {
      bestVideoScore = videoScore;
    }
  }

  /// Calculate final trending score with various factors
  double getFinalScore() {
    // Base score from total video performance
    double finalScore = totalScore;

    // Consistency boost (creators with multiple trending videos)
    if (videoCount > 1) {
      finalScore *=
          (1.0 + (videoCount * 0.1)); // 10% boost per additional video
    }

    // Recency boost (creators with recent trending videos)
    if (latestVideoTime != null) {
      final hoursAgo =
          DateTime.now().difference(latestVideoTime!.toDate()).inHours;
      final recencyBoost = 1.0 + (24.0 / (hoursAgo + 1));
      finalScore *= recencyBoost;
    }

    return finalScore;
  }
}

class RealUserDataService {
  static final RealUserDataService _instance = RealUserDataService._internal();
  factory RealUserDataService() => _instance;
  RealUserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Get current user data from Firestore
  Future<User?> getCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggingService.instance
            .debug('No authenticated user', tag: 'RealUserDataService');
        return null;
      }

      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!doc.exists) {
        LoggingService.instance.error(
            'User document not found: ${currentUser.uid}',
            tag: 'RealUserDataService');
        return null;
      }

      final data = doc.data()!;
      final user = User.fromMap(data);

      LoggingService.instance.debug(
          '✅ Current user loaded: ${user.displayName}',
          tag: 'RealUserDataService');
      return user;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting current user',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        LoggingService.instance
            .error('User not found: $userId', tag: 'RealUserDataService');
        return null;
      }

      final data = doc.data()!;
      return User.fromMap(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user by ID',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 🔥 ENHANCED: Get trending creators based on video performance and category relevance
  Future<List<TrendingCreator>> getTrendingCreators({int limit = 10}) async {
    try {
      LoggingService.instance.debug(
          '🔥 Loading trending creators based on video performance...',
          tag: 'RealUserDataService');

      // Step 1: Get recent videos with high engagement (last 7 days)
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final trendingVideosSnapshot = await _firestore
          .collection('videos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .where('isDraft', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(100) // Get more videos to analyze
          .get();

      if (trendingVideosSnapshot.docs.isEmpty) {
        LoggingService.instance.debug(
            '⚠️ No recent videos found, falling back to active users',
            tag: 'RealUserDataService');
        return await _getFallbackTrendingCreators(limit);
      }

      // Step 2: Calculate trending scores for each creator
      final Map<String, TrendingCreatorScore> creatorScores = {};

      for (final videoDoc in trendingVideosSnapshot.docs) {
        final videoData = videoDoc.data();
        final creatorId = videoData['userId'] ??
            videoData['creatorId'] ??
            videoData['creator_id'];

        if (creatorId == null) continue;

        // Calculate video trending score
        final videoScore = _calculateVideoTrendingScore(videoData, now);

        if (creatorScores.containsKey(creatorId)) {
          creatorScores[creatorId]!.addVideoScore(videoScore);
        } else {
          creatorScores[creatorId] = TrendingCreatorScore(
            creatorId: creatorId,
            totalScore: videoScore,
            videoCount: 1,
            bestVideoScore: videoScore,
            latestVideoTime: videoData['createdAt'] as Timestamp?,
          );
        }
      }

      // Step 3: Get creator details and sort by trending score
      final List<TrendingCreatorScore> sortedScores = creatorScores.values
          .toList()
        ..sort((a, b) => b.getFinalScore().compareTo(a.getFinalScore()));

      final List<TrendingCreator> trendingCreators = [];

      for (final score in sortedScores.take(limit * 2)) {
        // Get more to filter
        try {
          final creatorDoc =
              await _firestore.collection('users').doc(score.creatorId).get();

          if (!creatorDoc.exists) continue;

          final creatorData = creatorDoc.data()!;

          // Only include active creators
          if ((creatorData['onlineStatus'] ?? 'offline') != 'online') continue;

          trendingCreators.add(TrendingCreator(
            id: score.creatorId,
            username: creatorData['username'] ?? 'Unknown',
            displayName: creatorData['displayName'] ?? creatorData['username'],
            avatarURL: creatorData['avatarURL'],
            followerCount: creatorData['followerCount'] ?? 0,
            isActive: true,
          ));

          if (trendingCreators.length >= limit) break;
        } catch (e) {
          LoggingService.instance.warning(
              'Error loading creator ${score.creatorId}: $e',
              tag: 'RealUserDataService');
        }
      }

      LoggingService.instance.debug(
          '✅ Loaded ${trendingCreators.length} trending creators based on video performance',
          tag: 'RealUserDataService');
      return trendingCreators;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting trending creators',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return await _getFallbackTrendingCreators(limit);
    }
  }

  /// Calculate trending score for a video based on engagement and recency
  double _calculateVideoTrendingScore(
      Map<String, dynamic> videoData, DateTime now) {
    // Base metrics
    final views = (videoData['views'] ?? 0) as int;
    final likes = (videoData['likes'] ?? 0) as int;
    final comments = (videoData['comments'] ?? 0) as int;
    final shares = (videoData['shares'] ?? 0) as int;

    // Engagement rate (likes + comments + shares) / views
    final engagementRate =
        views > 0 ? (likes + comments + shares) / views : 0.0;

    // Recency boost (more recent = higher score)
    final createdAt = videoData['createdAt'] as Timestamp?;
    double recencyBoost = 1.0;
    if (createdAt != null) {
      final hoursAgo = now.difference(createdAt.toDate()).inHours;
      recencyBoost = 1.0 + (24.0 / (hoursAgo + 1)); // Boost decreases over time
    }

    // Category relevance boost (videos in popular categories get boost)
    final categoryId =
        videoData['categoryId'] ?? videoData['category_id'] ?? '';
    final categoryBoost = _getCategoryRelevanceBoost(categoryId);

    // Calculate final score
    final baseScore =
        (views * 0.1) + (likes * 0.3) + (comments * 0.5) + (shares * 0.7);
    final engagementMultiplier =
        1.0 + (engagementRate * 2.0); // Higher engagement = higher multiplier
    final finalScore =
        baseScore * engagementMultiplier * recencyBoost * categoryBoost;

    return finalScore;
  }

  /// Get category relevance boost based on current trending categories
  double _getCategoryRelevanceBoost(String categoryId) {
    // Define trending categories and their boost values
    const trendingCategories = {
      'gaming': 1.5, // Gaming is always trending
      'music': 1.3, // Music content performs well
      'art': 1.2, // Art content has good engagement
      'comedy': 1.4, // Comedy is highly shareable
      'dance': 1.3, // Dance videos are viral
      'sports': 1.1, // Sports content
      'tech': 1.2, // Tech reviews
      'food': 1.1, // Food content
      'fashion': 1.2, // Fashion content
      'fitness': 1.1, // Fitness content
    };

    return trendingCategories[categoryId] ?? 1.0; // Default boost
  }

  /// Fallback method to get active users when no trending videos are found
  Future<List<TrendingCreator>> _getFallbackTrendingCreators(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      final creators = snapshot.docs.map((doc) {
        final data = doc.data();
        return TrendingCreator(
          id: doc.id,
          username: data['username'] ?? 'Unknown',
          displayName: data['displayName'],
          avatarURL: data['avatarURL'],
          followerCount: data['followerCount'] ?? 0,
          isActive: (data['onlineStatus'] ?? 'offline') == 'online',
        );
      }).toList();

      LoggingService.instance.debug(
          '✅ Loaded ${creators.length} fallback trending creators',
          tag: 'RealUserDataService');
      return creators;
    } catch (e) {
      LoggingService.instance.error('Error getting fallback trending creators',
          tag: 'RealUserDataService', error: e);
      return [];
    }
  }

  /// Get user's videos
  Future<List<HomeVideo>> getUserVideos(String userId, {int limit = 20}) async {
    try {
      // Simple query - just get all videos for this user, filter in memory
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .limit(50) // Get more to filter in memory
          .get();

      final videos = <HomeVideo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Filter for published videos only
        if (data['status'] != 'published') {
          continue;
        }

        // Get creator data
        final creator = await getUserById(userId);
        if (creator == null) continue;

        // Create thumbnails object from legacy thumbnailUrl
        VideoThumbnails? thumbnails;
        final thumbnailUrl = data['thumbnailUrl'] as String?;
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          thumbnails = VideoThumbnails(
            urls: {
              360: thumbnailUrl,
              540: thumbnailUrl,
              720: thumbnailUrl,
            },
            generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          );
        }

        final video = HomeVideo(
          id: doc.id,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: thumbnailUrl,
          thumbnails: thumbnails,
          creator: creator,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          caption: data['title'] ?? data['description'] ?? '',
          categoryId: data['category'] ?? 'general',
        );

        videos.add(video);
      }

      // Sort by creation date (newest first) and limit
      // Videos are already sorted by Firestore query
      final limitedVideos = videos.take(limit).toList();

      LoggingService.instance.debug(
          '✅ Loaded ${limitedVideos.length} videos for user: $userId',
          tag: 'RealUserDataService');
      return limitedVideos;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user videos',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get for you videos (algorithmic feed)
  Future<List<HomeVideo>> getForYouVideos(
      {int limit = 20, String? lastDocumentId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .where('privacy', isEqualTo: 'Everyone')
          .orderBy('score', descending: true)
          .limit(limit);

      if (lastDocumentId != null) {
        final lastDoc =
            await _firestore.collection('videos').doc(lastDocumentId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      final snapshot = await query.get();
      final videos = <HomeVideo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId == null) continue;

        // Get creator data
        final creator = await getUserById(userId);
        if (creator == null) continue;

        // Create thumbnails object from legacy thumbnailUrl
        VideoThumbnails? thumbnails;
        final thumbnailUrl = data['thumbnailUrl'] as String?;
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          thumbnails = VideoThumbnails(
            urls: {
              360: thumbnailUrl,
              540: thumbnailUrl,
              720: thumbnailUrl,
            },
            generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          );
        }

        final video = HomeVideo(
          id: doc.id,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: thumbnailUrl,
          thumbnails: thumbnails,
          creator: creator,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          caption: data['title'] ?? data['description'] ?? '',
          categoryId: data['category'] ?? 'general',
        );

        videos.add(video);
      }

      LoggingService.instance.debug('✅ Loaded ${videos.length} for you videos',
          tag: 'RealUserDataService');
      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting for you videos',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get following videos
  Future<List<HomeVideo>> getFollowingVideos(List<String> followingIds,
      {int limit = 20}) async {
    try {
      if (followingIds.isEmpty) {
        LoggingService.instance
            .debug('No following IDs provided', tag: 'RealUserDataService');
        return [];
      }

      final snapshot = await _firestore
          .collection('videos')
          .where('userId', whereIn: followingIds)
          .where('status', isEqualTo: 'published')
          .where('privacy', whereIn: ['Everyone', 'Connections'])
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final videos = <HomeVideo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId == null) continue;

        // Get creator data
        final creator = await getUserById(userId);
        if (creator == null) continue;

        // Create thumbnails object from legacy thumbnailUrl
        VideoThumbnails? thumbnails;
        final thumbnailUrl = data['thumbnailUrl'] as String?;
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          thumbnails = VideoThumbnails(
            urls: {
              360: thumbnailUrl,
              540: thumbnailUrl,
              720: thumbnailUrl,
            },
            generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          );
        }

        final video = HomeVideo(
          id: doc.id,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: thumbnailUrl,
          thumbnails: thumbnails,
          creator: creator,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          caption: data['title'] ?? data['description'] ?? '',
          categoryId: data['category'] ?? 'general',
        );

        videos.add(video);
      }

      LoggingService.instance.debug(
          '✅ Loaded ${videos.length} following videos',
          tag: 'RealUserDataService');
      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting following videos',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Update user data
  Future<bool> updateUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'displayName': user.displayName,
        'username': user.username,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'hashtags': user.hashtags,
        'onlineStatus': user.onlineStatus,
        'aiSelf': user.aiSelf,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User updated: ${user.displayName}',
          tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error updating user',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Create new user
  Future<bool> createUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).set({
        'id': user.id,
        'displayName': user.displayName,
        'username': user.username,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'hashtags': user.hashtags,
        'onlineStatus': user.onlineStatus,
        'aiSelf': user.aiSelf,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'isActive': true,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User created: ${user.displayName}',
          tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error creating user',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get user's followers
  Future<List<User>> getUserFollowers(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get();

      final followers = <User>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final followerId = data['followerId'] as String?;

        if (followerId != null) {
          final follower = await getUserById(followerId);
          if (follower != null) {
            followers.add(follower);
          }
        }
      }

      LoggingService.instance.debug(
          '✅ Loaded ${followers.length} followers for user: $userId',
          tag: 'RealUserDataService');
      return followers;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user followers',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get user's following
  Future<List<User>> getUserFollowing(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get();

      final following = <User>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final followingId = data['followingId'] as String?;

        if (followingId != null) {
          final user = await getUserById(followingId);
          if (user != null) {
            following.add(user);
          }
        }
      }

      LoggingService.instance.debug(
          '✅ Loaded ${following.length} following for user: $userId',
          tag: 'RealUserDataService');
      return following;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user following',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Follow a user
  Future<bool> followUser(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final followData = {
        'followerId': currentUser.uid,
        'followingId': targetUserId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('follows').add(followData);

      // Update follower counts
      await _firestore.collection('users').doc(currentUser.uid).update({
        'followingCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(targetUserId).update({
        'followerCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance
          .debug('✅ User followed: $targetUserId', tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error following user',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'status': 'inactive',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update follower counts
      await _firestore.collection('users').doc(currentUser.uid).update({
        'followingCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(targetUserId).update({
        'followerCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User unfollowed: $targetUserId',
          tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error unfollowing user',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if user is following another user
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      LoggingService.instance.error('Error checking follow status',
          tag: 'RealUserDataService', error: e);
      return false;
    }
  }
}
