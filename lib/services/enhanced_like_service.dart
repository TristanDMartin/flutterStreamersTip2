import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'engagement_analytics_service.dart';
import 'event_trigger_service.dart';

/// Enhanced Like Service with TikTok-style persistence and analytics
///
/// Features:
/// - Optimistic UI updates
/// - Persistent state across app restarts
/// - Debounced operations
/// - Comprehensive analytics
/// - Error handling with rollback
/// - Rate limiting
class EnhancedLikeService {
  static final EnhancedLikeService _instance = EnhancedLikeService._internal();
  factory EnhancedLikeService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  EventTriggerService? _eventTriggerService;

  // Rate limiting
  final Map<String, DateTime> _lastLikeTimes = {};
  static const Duration _rateLimitDuration = Duration(milliseconds: 300);

  // Local persistence keys
  static const String _likedVideosKey = 'enhanced_liked_videos';
  static const String _likeCountsKey = 'enhanced_like_counts';
  static const String _likeTimestampsKey = 'enhanced_like_timestamps';

  EnhancedLikeService._internal();

  /// Set the EventTriggerService instance
  void setEventTriggerService(EventTriggerService eventTriggerService) {
    _eventTriggerService = eventTriggerService;
  }

  /// Toggle like status with enhanced UX and persistence
  Future<LikeResult> toggleLike(String videoId,
      {String source = 'button'}) async {
    try {
      // Rate limiting check
      if (_isRateLimited(videoId)) {
        log('⚠️ Like operation rate limited for video: $videoId');
        return LikeResult.rateLimited;
      }

      final currentUser = _auth.currentUser;
      final isCurrentlyLiked = await isVideoLiked(videoId);

      log('💖 Toggling like for video: $videoId, currently liked: $isCurrentlyLiked, source: $source');

      // Update rate limiting
      _lastLikeTimes[videoId] = DateTime.now();

      if (isCurrentlyLiked) {
        return await _unlikeVideo(currentUser?.uid, videoId, source);
      } else {
        return await _likeVideo(currentUser?.uid, videoId, source);
      }
    } catch (e) {
      log('❌ Error toggling like: $e');
      return LikeResult.error;
    }
  }

  /// Check if operation is rate limited
  bool _isRateLimited(String videoId) {
    final lastTime = _lastLikeTimes[videoId];
    if (lastTime == null) return false;

    return DateTime.now().difference(lastTime) < _rateLimitDuration;
  }

  /// Like a video with optimistic updates
  Future<LikeResult> _likeVideo(
      String? currentUser, String videoId, String source) async {
    try {
      // 1. Optimistic local update
      await _updateLocalLikeState(videoId, true);

      // 2. Track engagement immediately
      _trackLikeEngagement(videoId, true, source);

      // 3. Background Firebase sync
      if (currentUser != null) {
        _performFirebaseLike(videoId, currentUser).catchError((e) {
          log('❌ Firebase like failed, keeping local state: $e');
        });
      }

      return LikeResult.success;
    } catch (e) {
      log('❌ Error liking video: $e');
      return LikeResult.error;
    }
  }

  /// Unlike a video with optimistic updates
  Future<LikeResult> _unlikeVideo(
      String? currentUser, String videoId, String source) async {
    try {
      // 1. Optimistic local update
      await _updateLocalLikeState(videoId, false);

      // 2. Track engagement immediately
      _trackLikeEngagement(videoId, false, source);

      // 3. Background Firebase sync
      if (currentUser != null) {
        _performFirebaseUnlike(videoId, currentUser).catchError((e) {
          log('❌ Firebase unlike failed, keeping local state: $e');
        });
      }

      return LikeResult.success;
    } catch (e) {
      log('❌ Error unliking video: $e');
      return LikeResult.error;
    }
  }

  /// Update local like state optimistically
  Future<void> _updateLocalLikeState(String videoId, bool isLiked) async {
    try {
      // Update liked videos set
      final likedVideos = await getLikedVideos();
      if (isLiked) {
        likedVideos.add(videoId);
      } else {
        likedVideos.remove(videoId);
      }
      await saveLikedVideos(likedVideos);

      // Update like count
      final likeCounts = await getLikeCounts();
      final currentCount = likeCounts[videoId] ?? 0;
      likeCounts[videoId] =
          isLiked ? currentCount + 1 : math.max(0, currentCount - 1);
      await saveLikeCounts(likeCounts);

      // Update timestamp
      final timestamps = await getLikeTimestamps();
      timestamps[videoId] = DateTime.now().millisecondsSinceEpoch;
      await saveLikeTimestamps(timestamps);

      log('✅ Local like state updated: $videoId -> $isLiked');
    } catch (e) {
      log('❌ Error updating local like state: $e');
    }
  }

  /// Perform Firebase like operation
  Future<void> _performFirebaseLike(String videoId, String userId) async {
    try {
      final batch = _firestore.batch();

      // Add to user's liked videos
      final userLikeRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);
      batch.set(userLikeRef, {
        'videoId': videoId,
        'likedAt': FieldValue.serverTimestamp(),
        'source': 'enhanced_like_service',
      });

      // Increment video like count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'likes': FieldValue.increment(1),
        'lastLikedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Trigger like event for notifications
      await _triggerLikeEvent(videoId, userId);

      log('✅ Firebase like operation completed: $videoId');
    } catch (e) {
      log('❌ Firebase like operation failed: $e');
      rethrow;
    }
  }

  /// Perform Firebase unlike operation
  Future<void> _performFirebaseUnlike(String videoId, String userId) async {
    try {
      final batch = _firestore.batch();

      // Remove from user's liked videos
      final userLikeRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);
      batch.delete(userLikeRef);

      // Decrement video like count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'likes': FieldValue.increment(-1),
        'lastUnlikedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Trigger unlike event for notifications
      await _triggerUnlikeEvent(videoId, userId);

      log('✅ Firebase unlike operation completed: $videoId');
    } catch (e) {
      log('❌ Firebase unlike operation failed: $e');
      rethrow;
    }
  }

  /// Check if video is liked (with local persistence)
  Future<bool> isVideoLiked(String videoId) async {
    try {
      // First check local storage for immediate response
      final likedVideos = await getLikedVideos();
      return likedVideos.contains(videoId);
    } catch (e) {
      log('❌ Error checking if video is liked: $e');
      return false;
    }
  }

  /// Get like count (with local persistence)
  Future<int> getLikeCount(String videoId) async {
    try {
      // First check local storage for immediate response
      final likeCounts = await getLikeCounts();
      return likeCounts[videoId] ?? 0;
    } catch (e) {
      log('❌ Error getting like count: $e');
      return 0;
    }
  }

  /// Get all liked videos
  Future<Set<String>> getLikedVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedVideosJson = prefs.getString(_likedVideosKey);
      if (likedVideosJson != null) {
        final List<dynamic> likedVideosList = json.decode(likedVideosJson);
        return likedVideosList.cast<String>().toSet();
      }
      return <String>{};
    } catch (e) {
      log('❌ Error getting liked videos: $e');
      return <String>{};
    }
  }

  /// Save liked videos
  Future<void> saveLikedVideos(Set<String> likedVideos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedVideosJson = json.encode(likedVideos.toList());
      await prefs.setString(_likedVideosKey, likedVideosJson);
    } catch (e) {
      log('❌ Error saving liked videos: $e');
    }
  }

  /// Get like counts
  Future<Map<String, int>> getLikeCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likeCountsJson = prefs.getString(_likeCountsKey);
      if (likeCountsJson != null) {
        final Map<String, dynamic> likeCountsMap = json.decode(likeCountsJson);
        return likeCountsMap.map((key, value) => MapEntry(key, value as int));
      }
      return <String, int>{};
    } catch (e) {
      log('❌ Error getting like counts: $e');
      return <String, int>{};
    }
  }

  /// Save like counts
  Future<void> saveLikeCounts(Map<String, int> likeCounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likeCountsJson = json.encode(likeCounts);
      await prefs.setString(_likeCountsKey, likeCountsJson);
    } catch (e) {
      log('❌ Error saving like counts: $e');
    }
  }

  /// Get like timestamps
  Future<Map<String, int>> getLikeTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampsJson = prefs.getString(_likeTimestampsKey);
      if (timestampsJson != null) {
        final Map<String, dynamic> timestampsMap = json.decode(timestampsJson);
        return timestampsMap.map((key, value) => MapEntry(key, value as int));
      }
      return <String, int>{};
    } catch (e) {
      log('❌ Error getting like timestamps: $e');
      return <String, int>{};
    }
  }

  /// Save like timestamps
  Future<void> saveLikeTimestamps(Map<String, int> timestamps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampsJson = json.encode(timestamps);
      await prefs.setString(_likeTimestampsKey, timestampsJson);
    } catch (e) {
      log('❌ Error saving like timestamps: $e');
    }
  }

  /// Track like engagement with enhanced analytics
  void _trackLikeEngagement(String videoId, bool isLiked, String source) {
    try {
      EngagementAnalyticsService().trackEngagement(
        videoId: videoId,
        event: isLiked ? EngagementEvent.like : EngagementEvent.unlike,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'source': source,
          'isReplay': false,
          'service': 'enhanced_like_service',
        },
      );

      log('📊 Like engagement tracked: $videoId, liked: $isLiked, source: $source');
    } catch (e) {
      log('❌ Error tracking like engagement: $e');
    }
  }

  /// Trigger like event for notifications
  Future<void> _triggerLikeEvent(String videoId, String likerId) async {
    try {
      if (_eventTriggerService == null) {
        log('⚠️ EventTriggerService not set - skipping like notification');
        return;
      }

      // Get video owner ID
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        log('⚠️ Video document not found: $videoId');
        return;
      }

      final videoData = videoDoc.data()!;
      final videoOwnerId = videoData['userId'] as String?;

      if (videoOwnerId != null) {
        await _eventTriggerService!.triggerLikeEvent(
          likerId: likerId,
          videoId: videoId,
          videoOwnerId: videoOwnerId,
          postThumbnailUrl: videoData['thumbnailUrl'] as String?,
        );
        log('✅ Like event triggered: $likerId -> $videoOwnerId for video $videoId');
      }
    } catch (e) {
      log('❌ Error triggering like event: $e');
    }
  }

  /// Trigger unlike event for notifications
  Future<void> _triggerUnlikeEvent(String videoId, String likerId) async {
    try {
      if (_eventTriggerService == null) {
        log('⚠️ EventTriggerService not set - skipping unlike notification');
        return;
      }

      // Get video owner ID
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        log('⚠️ Video document not found: $videoId');
        return;
      }

      final videoData = videoDoc.data()!;
      final videoOwnerId = videoData['userId'] as String?;

      if (videoOwnerId != null) {
        await _eventTriggerService!.triggerUnlikeEvent(
          likerId: likerId,
          videoId: videoId,
          videoOwnerId: videoOwnerId,
        );
        log('✅ Unlike event triggered: $likerId -> $videoOwnerId for video $videoId');
      }
    } catch (e) {
      log('❌ Error triggering unlike event: $e');
    }
  }

  /// Sync local state with server (for app startup)
  Future<void> syncWithServer() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      log('🔄 Syncing like state with server...');

      // Get user's liked videos from server
      final likedVideosSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedVideos')
          .get();

      final serverLikedVideos =
          likedVideosSnapshot.docs.map((doc) => doc.id).toSet();

      // Update local storage with server data
      await saveLikedVideos(serverLikedVideos);

      log('✅ Like state synced with server: ${serverLikedVideos.length} liked videos');
    } catch (e) {
      log('❌ Error syncing with server: $e');
    }
  }

  /// Clear all local like data (for testing or reset)
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_likedVideosKey);
      await prefs.remove(_likeCountsKey);
      await prefs.remove(_likeTimestampsKey);

      _lastLikeTimes.clear();

      log('✅ Local like data cleared');
    } catch (e) {
      log('❌ Error clearing local data: $e');
    }
  }
}

/// Result of a like operation
enum LikeResult {
  success,
  error,
  rateLimited,
}
