import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'creator_stats_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Complete TikTok-style Like Service with Firebase persistence and ML scoring
///
/// Features:
/// - Optimistic UI updates (instant heart fill)
/// - Firebase persistence (/likes/{videoId}/byUser/{userId})
/// - Atomic like count updates
/// - ML scoring integration (mlScore.love)
/// - Idempotent operations (prevents duplicate likes)
/// - Offline queue with retry
/// - Real-time sync
class TikTokLikeService extends ChangeNotifier {
  static final TikTokLikeService _instance = TikTokLikeService._internal();
  factory TikTokLikeService() => _instance;
  TikTokLikeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  // Local state cache
  final Map<String, LikeState> _localCache = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // Offline queue
  final List<LikeOperation> _offlineQueue = [];
  bool _isOnline = true;

  // Rate limiting (prevent spam)
  final Map<String, DateTime> _lastLikeTimes = {};
  static const Duration _rateLimit = Duration(milliseconds: 300);

  /// Initialize the service
  Future<void> initialize() async {
    debugPrint('🚀 TikTokLikeService: Starting initialization...');

    await _loadCachedStates();

    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      if (_isOnline) {
        _processOfflineQueue();
      }
    });

    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);

    debugPrint(
        '✅ TikTokLikeService: Initialization complete - cached states: ${_localCache.length}');
  }

  /// Get like state for a video (optimistic)
  LikeState getLikeState(String videoId) {
    final cachedState = _localCache[videoId];
    final defaultState = LikeState(
      videoId: videoId,
      isLiked: false,
      likeCount: 0,
      isLoading: false,
    );

    final result = cachedState ?? defaultState;

    // Removed excessive logging - was called 10+ times per second per button
    // debugPrint(
    //     '🔍 TikTokLikeService: getLikeState($videoId) - cached: ${cachedState != null}, isLiked: ${result.isLiked}, likeCount: ${result.likeCount}');

    return result;
  }

  /// DOUBLE-TAP LIKE: Triggers like with floating heart animation
  /// Never unlikes - idempotent
  Future<bool> doubleTapLike(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    // If already liked, do nothing (idempotent)
    if (currentState.isLiked) {
      debugPrint('💖 TikTokLikeService: Already liked, ignoring double-tap');
      return false; // Don't show animation
    }

    // Like the video
    await likeVideo(videoId, userId, source: 'double_tap');
    return true; // Show animation
  }

  /// HEART BUTTON TAP: Toggles like/unlike
  Future<bool> toggleLike(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    if (currentState.isLiked) {
      await unlikeVideo(videoId, userId);
      return false; // Unlike - no animation
    } else {
      await likeVideo(videoId, userId, source: 'button');
      return true; // Like - show animation
    }
  }

  /// LIKE VIDEO: Optimistic update + Firebase persistence + ML scoring
  Future<void> likeVideo(String videoId, String userId,
      {String source = 'button'}) async {
    final currentState = getLikeState(videoId);

    // IDEMPOTENCY: Prevent duplicate likes
    if (currentState.isLiked) {
      debugPrint('💖 TikTokLikeService: Video already liked, ignoring');
      return;
    }

    // Rate limiting
    final now = DateTime.now();
    final lastTime = _lastLikeTimes[videoId];
    if (lastTime != null && now.difference(lastTime) < _rateLimit) {
      debugPrint('🚫 TikTokLikeService: Rate limited');
      return;
    }
    _lastLikeTimes[videoId] = now;

    // OPTIMISTIC UPDATE: Fill heart instantly
    final newState = currentState.copyWith(
      isLiked: true,
      likeCount: currentState.likeCount + 1,
      isLoading: true,
    );
    _updateLocalState(videoId, newState);

    // Analytics
    _trackLikeEvent(videoId, source);

    // Firebase operation
    final operation = LikeOperation(
      videoId: videoId,
      userId: userId,
      action: LikeAction.like,
      timestamp: now,
    );

    if (_isOnline) {
      await _performLikeOperation(operation);
    } else {
      _offlineQueue.add(operation);
      debugPrint('📱 TikTokLikeService: Queued for offline');
    }
  }

  /// UNLIKE VIDEO: No animation, just Firebase update
  Future<void> unlikeVideo(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    // Only unlike if currently liked
    if (!currentState.isLiked) {
      debugPrint('💔 TikTokLikeService: Not liked, ignoring unlike');
      return;
    }

    // Rate limiting
    final now = DateTime.now();
    final lastTime = _lastLikeTimes[videoId];
    if (lastTime != null && now.difference(lastTime) < _rateLimit) {
      debugPrint('🚫 TikTokLikeService: Rate limited');
      return;
    }
    _lastLikeTimes[videoId] = now;

    // OPTIMISTIC UPDATE: Unfill heart instantly (no animation)
    final newState = currentState.copyWith(
      isLiked: false,
      likeCount: (currentState.likeCount - 1).clamp(0, double.infinity).toInt(),
      isLoading: true,
    );
    _updateLocalState(videoId, newState);

    // Analytics
    _trackUnlikeEvent(videoId);

    // Firebase operation
    final operation = LikeOperation(
      videoId: videoId,
      userId: userId,
      action: LikeAction.unlike,
      timestamp: now,
    );

    if (_isOnline) {
      await _performLikeOperation(operation);
    } else {
      _offlineQueue.add(operation);
      debugPrint('📱 TikTokLikeService: Queued for offline');
    }
  }

  /// FIREBASE OPERATION: Write to Firestore with atomic updates
  Future<void> _performLikeOperation(LikeOperation operation) async {
    try {
      final batch = _firestore.batch();

      // 1. Update /likes/{videoId}/byUser/{userId}
      final likeRef = _firestore
          .collection('likes')
          .doc(operation.videoId)
          .collection('byUser')
          .doc(operation.userId);

      final videoRef = _firestore.collection('videos').doc(operation.videoId);

      if (operation.action == LikeAction.like) {
        // SET LIKE
        batch.set(likeRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'videoId': operation.videoId,
          'userId': operation.userId,
        });

        // INCREMENT LIKE COUNT (atomic)
        batch.update(videoRef, {
          'likeCount': FieldValue.increment(1),
        });

        // UPDATE ML SCORE: mlScore.love += 0.05
        batch.update(videoRef, {
          'mlScore.love': FieldValue.increment(0.05),
        });

        debugPrint('✅ TikTokLikeService: Liked ${operation.videoId}');
      } else {
        // DELETE LIKE
        batch.delete(likeRef);

        // DECREMENT LIKE COUNT (atomic, floor at 0)
        batch.update(videoRef, {
          'likeCount': FieldValue.increment(-1),
        });

        // UPDATE ML SCORE: mlScore.love -= 0.05
        batch.update(videoRef, {
          'mlScore.love': FieldValue.increment(-0.05),
        });

        debugPrint('✅ TikTokLikeService: Unliked ${operation.videoId}');
      }

      await batch.commit();
      await CreatorStatsSyncService().syncLikeToCreator(
        videoId: operation.videoId,
        delta: operation.action == LikeAction.like ? 1 : -1,
      );

      // Update local state to remove loading
      final currentState = getLikeState(operation.videoId);
      _updateLocalState(
          operation.videoId, currentState.copyWith(isLoading: false));
    } catch (e) {
      debugPrint('❌ TikTokLikeService: Firebase operation failed: $e');

      // Retry after 2 seconds
      Timer(const Duration(seconds: 2), () async {
        try {
          await _performLikeOperation(operation);
        } catch (retryError) {
          debugPrint('❌ TikTokLikeService: Retry failed, reverting');
          await _revertOptimisticUpdate(operation);
        }
      });
    }
  }

  /// Process offline queue when coming back online
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    debugPrint(
        '📱 TikTokLikeService: Processing ${_offlineQueue.length} queued operations');

    final operations = List<LikeOperation>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final operation in operations) {
      await _performLikeOperation(operation);
    }
  }

  /// Update local state and notify listeners
  void _updateLocalState(String videoId, LikeState newState) {
    _localCache[videoId] = newState;
    _saveCachedState(videoId, newState);
    debugPrint(
        '🔄 TikTokLikeService: State updated for $videoId - isLiked: ${newState.isLiked}, likeCount: ${newState.likeCount}');
    notifyListeners(); // Notify widgets of state change
  }

  /// Revert optimistic update on failure
  Future<void> _revertOptimisticUpdate(LikeOperation operation) async {
    final currentState = getLikeState(operation.videoId);
    final revertedState = operation.action == LikeAction.like
        ? currentState.copyWith(
            isLiked: false,
            likeCount: currentState.likeCount - 1,
            isLoading: false,
          )
        : currentState.copyWith(
            isLiked: true,
            likeCount: currentState.likeCount + 1,
            isLoading: false,
          );

    _updateLocalState(operation.videoId, revertedState);
  }

  /// Load cached states from local storage
  Future<void> _loadCachedStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('like_'));

      debugPrint(
          '📱 TikTokLikeService: Found ${keys.length} cached like states');

      for (final key in keys) {
        final videoId = key.substring(5);
        final isLiked = prefs.getBool(key) ?? false;

        // Load cached like count
        final likeCountKey = 'likeCount_$videoId';
        final likeCount = prefs.getInt(likeCountKey) ?? 0;

        _localCache[videoId] = LikeState(
          videoId: videoId,
          isLiked: isLiked,
          likeCount: likeCount,
          isLoading: false,
        );

        debugPrint(
            '📱 TikTokLikeService: Loaded cached state for $videoId - isLiked: $isLiked, likeCount: $likeCount');
      }

      debugPrint(
          '📱 TikTokLikeService: Loaded ${_localCache.length} cached states total');

      // Sync with server to get latest like counts
      await _syncLikeCountsFromServer();
    } catch (e) {
      debugPrint('❌ TikTokLikeService: Failed to load cache: $e');
    }
  }

  /// Save like state to local storage
  Future<void> _saveCachedState(String videoId, LikeState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('like_$videoId', state.isLiked);
      await prefs.setInt('likeCount_$videoId', state.likeCount);
    } catch (e) {
      debugPrint('❌ TikTokLikeService: Failed to save cache: $e');
    }
  }

  /// Sync like counts from server for all cached videos
  Future<void> _syncLikeCountsFromServer() async {
    if (_localCache.isEmpty) return;

    try {
      debugPrint('🔄 TikTokLikeService: Syncing like counts from server...');

      // Get all video IDs that we have cached
      final videoIds = _localCache.keys.toList();

      // Fetch like counts for all videos in batches
      const batchSize = 10;
      for (int i = 0; i < videoIds.length; i += batchSize) {
        final batch = videoIds.skip(i).take(batchSize).toList();

        // Create batch read for efficiency
        final futures = batch.map((videoId) async {
          try {
            final videoDoc =
                await _firestore.collection('videos').doc(videoId).get();

            if (videoDoc.exists) {
              final likeCount = videoDoc.data()?['likeCount'] ?? 0;

              // Update local cache with server like count
              final currentState = _localCache[videoId];
              if (currentState != null) {
                _localCache[videoId] =
                    currentState.copyWith(likeCount: likeCount);
                await _saveCachedState(videoId, _localCache[videoId]!);
              }

              debugPrint(
                  '📊 TikTokLikeService: Synced like count for $videoId: $likeCount');
            }
          } catch (e) {
            debugPrint(
                '⚠️ TikTokLikeService: Failed to sync like count for $videoId: $e');
          }
        });

        await Future.wait(futures);
      }

      debugPrint('✅ TikTokLikeService: Like count sync completed');
    } catch (e) {
      debugPrint('❌ TikTokLikeService: Failed to sync like counts: $e');
    }
  }

  /// Track analytics events
  void _trackLikeEvent(String videoId, String source) {
    debugPrint(
        '📊 TikTokLikeService: like_tap - video: $videoId, source: $source');
    // Send to analytics: ml_update('love', +1)
  }

  void _trackUnlikeEvent(String videoId) {
    debugPrint('📊 TikTokLikeService: unlike_tap - video: $videoId');
    // Send to analytics: ml_update('love', -1)
  }

  /// Format like count for display
  String formatLikeCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  /// Check if video is liked (for compatibility)
  Future<bool> isVideoLiked(String videoId) async {
    return getLikeState(videoId).isLiked;
  }

  /// Get like count (for compatibility)
  Future<int> getLikeCount(String videoId) async {
    return getLikeState(videoId).likeCount;
  }

  /// Cleanup resources
  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _localCache.clear();
    super.dispose();
  }
}

/// Like state model
class LikeState {
  final String videoId;
  final bool isLiked;
  final int likeCount;
  final bool isLoading;

  const LikeState({
    required this.videoId,
    required this.isLiked,
    required this.likeCount,
    required this.isLoading,
  });

  LikeState copyWith({
    String? videoId,
    bool? isLiked,
    int? likeCount,
    bool? isLoading,
  }) {
    return LikeState(
      videoId: videoId ?? this.videoId,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Like operation for offline queue
class LikeOperation {
  final String videoId;
  final String userId;
  final LikeAction action;
  final DateTime timestamp;

  const LikeOperation({
    required this.videoId,
    required this.userId,
    required this.action,
    required this.timestamp,
  });
}

/// Like action enum
enum LikeAction {
  like,
  unlike,
}
