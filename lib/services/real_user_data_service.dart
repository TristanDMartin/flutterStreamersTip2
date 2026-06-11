import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/video_url_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_count_fields.dart';
import '../models/user.dart';
import '../models/home_video.dart';
import '../models/video_thumbnails.dart';
import '../models/trending_creator.dart';
import '../services/logging_service.dart';
import 'creator_follower_count_service.dart';
import 'follows_service.dart';

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
  final CreatorFollowerCountService _followerCountService =
      CreatorFollowerCountService.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  Future<List<TrendingCreator>> _mergeTrendingCreatorFollowerCounts(
    List<TrendingCreator> creators,
    Map<String, Map<String, dynamic>> userDataByCreatorId,
  ) async {
    if (creators.isEmpty) {
      return creators;
    }
    final List<TrendingCreator> merged = await Future.wait(
      creators.map((TrendingCreator c) async {
        final Map<String, dynamic>? fallback = userDataByCreatorId[c.id];
        final int n = await _followerCountService.resolveCreatorFollowerCount(
          c.id,
          fallback,
        );
        return c.copyWith(followerCount: n);
      }),
    );
    return merged;
  }

  int _readTrendingCreatorLevel(Map<String, dynamic> data) {
    const List<String> keys = <String>[
      'level',
      'creatorLevel',
      'gamificationLevel',
    ];
    for (final String k in keys) {
      final Object? v = data[k];
      if (v is int) {
        return v.clamp(0, 999999).toInt();
      }
      if (v is num) {
        return v.toInt().clamp(0, 999999).toInt();
      }
    }
    return 0;
  }

  String? _readTrendingTierStatusLabel(Map<String, dynamic> data) {
    final Object? title = data['tierStatusLabel'] ??
        data['rankTitle'] ??
        data['creatorRankTitle'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
    final String? raw = (data['subscriptionPlan'] ??
            data['effectivePlan'] ??
            data['plan'] ??
            data['tier'])
        ?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final String p = raw.toLowerCase();
    if (p.contains('studio')) {
      return 'Pro Creator';
    }
    if (p.contains('pro')) {
      return 'Pro Creator';
    }
    return null;
  }

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

      final data = <String, dynamic>{
        ...doc.data()!,
        'id': userId,
        'uid': userId,
      };
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

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final QuerySnapshot<Map<String, dynamic>> trendingVideosSnapshot =
          await _loadTrendingCandidateVideos(sevenDaysAgo);

      if (trendingVideosSnapshot.docs.isEmpty) {
        LoggingService.instance.debug(
            '⚠️ No feed-eligible videos found, falling back to active users',
            tag: 'RealUserDataService');
        return await _getFallbackTrendingCreators(limit);
      }

      // Step 2: Calculate trending scores for each creator
      final Map<String, TrendingCreatorScore> creatorScores = {};

      for (final videoDoc in trendingVideosSnapshot.docs) {
        final videoData = videoDoc.data();
        if (_isDraftVideo(videoData)) {
          continue;
        }
        final String? creatorId = getOwnerId(videoData);
        if (creatorId == null || creatorId.isEmpty) continue;

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
      final Map<String, Map<String, dynamic>> userDataByCreatorId = {};
      final List<TrendingCreator?> candidates = await Future.wait(
        sortedScores.take(limit * 2).map((TrendingCreatorScore score) async {
          try {
            final creatorDoc =
                await _firestore.collection('users').doc(score.creatorId).get();

            if (!creatorDoc.exists) return null;

            final creatorData = creatorDoc.data()!;

            userDataByCreatorId[score.creatorId] = creatorData;
            return TrendingCreator(
              id: score.creatorId,
              username: creatorData['username'] ?? 'Unknown',
              displayName:
                  creatorData['displayName'] ?? creatorData['username'],
              avatarURL: creatorData['avatarURL'],
              followerCount: UserCountFields.readFollowersCount(creatorData),
              isActive: true,
              creatorLevel: _readTrendingCreatorLevel(creatorData),
              tierStatusLabel: _readTrendingTierStatusLabel(creatorData),
            );
          } catch (e) {
            LoggingService.instance.warning(
                'Error loading creator ${score.creatorId}: $e',
                tag: 'RealUserDataService');
            return null;
          }
        }),
      );
      for (final TrendingCreator? creator in candidates) {
        if (creator == null) continue;
        trendingCreators.add(creator);
        if (trendingCreators.length >= limit) break;
      }

      LoggingService.instance.debug(
          '✅ Loaded ${trendingCreators.length} trending creators based on video performance',
          tag: 'RealUserDataService');
      return await _mergeTrendingCreatorFollowerCounts(
        trendingCreators,
        userDataByCreatorId,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting trending creators',
          tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return await _getFallbackTrendingCreators(limit);
    }
  }

  bool _isDraftVideo(Map<String, dynamic> data) {
    if (data['isDraft'] == true || data['draft'] == true) {
      return true;
    }
    final String status = (data['status'] as String? ?? '').toLowerCase();
    return status == 'draft';
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadTrendingCandidateVideos(
    DateTime sevenDaysAgo,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> recentSnapshot = await _firestore
          .collection('videos')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(sevenDaysAgo),
          )
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      if (recentSnapshot.docs.isNotEmpty) {
        return recentSnapshot;
      }
    } catch (e) {
      LoggingService.instance.warning(
        'Recent trending video query failed, using feed-ready fallback: $e',
        tag: 'RealUserDataService',
      );
    }
    return _firestore
        .collection('videos')
        .where(
          'status',
          whereIn: const <String>['ready', 'active', 'published'],
        )
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
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

      final Map<String, Map<String, dynamic>> userDataByCreatorId = {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs)
          doc.id: doc.data(),
      };
      final List<TrendingCreator> creators = snapshot.docs.map((doc) {
        final data = doc.data();
        return TrendingCreator(
          id: doc.id,
          username: data['username'] ?? 'Unknown',
          displayName: data['displayName'],
          avatarURL: resolveAvatarUrl(data),
          followerCount: UserCountFields.readFollowersCount(data),
          isActive: (data['onlineStatus'] ?? 'offline') == 'online',
          creatorLevel: _readTrendingCreatorLevel(data),
          tierStatusLabel: _readTrendingTierStatusLabel(data),
        );
      }).toList();

      LoggingService.instance.debug(
          '✅ Loaded ${creators.length} fallback trending creators',
          tag: 'RealUserDataService');
      return await _mergeTrendingCreatorFollowerCounts(
        creators,
        userDataByCreatorId,
      );
    } catch (e) {
      LoggingService.instance.error('Error getting fallback trending creators',
          tag: 'RealUserDataService', error: e);
      return [];
    }
  }

  /// Get user's videos
  /// Uses canonical owner: queries both userId and user_id, merges, then
  /// builds with getOwnerId so both paths match VideoService filtering.
  /// 🚀 NEWEST FIRST: Returns videos sorted by creation date (newest first)
  Future<List<HomeVideo>> getUserVideos(String userId, {int limit = 20}) async {
    try {
      final docMap = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      Future<void> addFromQuery(String ownerField) async {
        final query = _firestore
            .collection('videos')
            .where(ownerField, isEqualTo: userId)
            .where('status', whereIn: ['published', 'ready', 'active'])
            .orderBy('createdAt', descending: true)
            .limit(limit);
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          docMap[doc.id] = doc;
        }
      }

      await addFromQuery('userId');
      try {
        await addFromQuery('user_id');
      } catch (_) {
        // user_id composite index may not exist; userId query is enough
      }

      final videos = <HomeVideo>[];

      for (final doc in docMap.values) {
        final data = doc.data();
        final ownerId = getOwnerId(data);
        if (ownerId == null) continue;

        final creator = await getUserById(ownerId);
        if (creator == null) continue;

        final thumbnailUrl =
            (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;
        VideoThumbnails? thumbnails;
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
          videoURL: resolveVideoUrl(data),
          thumbnailURL: thumbnailUrl,
          thumbnails: thumbnails,
          creator: creator,
          views: (data['views'] as num?)?.toInt() ?? 0,
          likes: (data['likes'] as num?)?.toInt() ?? 0,
          comments: (data['comments'] as num?)?.toInt() ?? 0,
          caption: (data['title'] as String?) ??
              (data['description'] as String?) ??
              '',
          categoryId: (data['category'] as String?) ?? 'general',
          createdAt: data['createdAt'] as Timestamp?,
        );

        videos.add(video);
      }

      videos.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

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
          .where('status', whereIn: ['published', 'ready', 'active'])
          .where('privacy', whereIn: ['Everyone', 'Public'])
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
          videoURL: resolveVideoUrl(data),
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
          .where('status', whereIn: ['published', 'ready', 'active'])
          .where('privacy', whereIn: ['Everyone', 'Public', 'Connections'])
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
          videoURL: resolveVideoUrl(data),
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
    return FollowsService().followUser(targetUserId);
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String targetUserId) async {
    final success = await FollowsService().unfollowUser(targetUserId);
    if (success) {
      LoggingService.instance.debug('✅ User unfollowed: $targetUserId',
          tag: 'RealUserDataService');
    }
    return success;
  }

  /// Check if user is following another user
  Future<bool> isFollowing(String targetUserId) async {
    return FollowsService().isFollowing(targetUserId);
  }
}
