import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'creator_stats_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// TikTok-style Like Service with optimistic updates and offline queue
class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  // Local state cache
  final Map<String, LikeState> _localCache = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  StreamSubscription? _connectivitySub;

  // Offline queue for when network is unavailable
  final List<LikeOperation> _offlineQueue = [];
  bool _isOnline = true;

  // Rate limiting
  final Map<String, DateTime> _lastLikeTimes = {};
  static const Duration _rateLimit = Duration(milliseconds: 300);

  /// Initialize the service
  Future<void> initialize() async {
    // Load cached like states
    await _loadCachedStates();

    // Monitor connectivity
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      if (_isOnline) {
        _processOfflineQueue();
      }
    });

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);
  }

  /// Get like state for a video (optimistic)
  LikeState getLikeState(String videoId) {
    return _localCache[videoId] ??
        LikeState(
          videoId: videoId,
          isLiked: false,
          likeCount: 0,
          isLoading: false,
        );
  }

  /// Like a video with optimistic updates
  Future<void> likeVideo(String videoId, String userId,
      {String source = 'button'}) async {
    final currentState = getLikeState(videoId);

    // Rate limiting
    final now = DateTime.now();
    final lastTime = _lastLikeTimes[videoId];
    if (lastTime != null && now.difference(lastTime) < _rateLimit) {
      debugPrint('🚫 LikeService: Rate limited for video $videoId');
      return;
    }
    _lastLikeTimes[videoId] = now;

    // Optimistic update
    final newState = currentState.copyWith(
      isLiked: true,
      likeCount: currentState.isLiked
          ? currentState.likeCount
          : currentState.likeCount + 1,
      isLoading: true,
    );
    _updateLocalState(videoId, newState);

    // Track analytics
    _trackLikeEvent(videoId, source, wasLikedBefore: currentState.isLiked);

    // Network operation
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
      debugPrint(
          '📱 LikeService: Queued like operation for offline processing');
    }
  }

  /// Unlike a video with optimistic updates
  Future<void> unlikeVideo(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    // Rate limiting
    final now = DateTime.now();
    final lastTime = _lastLikeTimes[videoId];
    if (lastTime != null && now.difference(lastTime) < _rateLimit) {
      debugPrint('🚫 LikeService: Rate limited for video $videoId');
      return;
    }
    _lastLikeTimes[videoId] = now;

    // Optimistic update
    final newState = currentState.copyWith(
      isLiked: false,
      likeCount: (currentState.likeCount - 1).clamp(0, double.infinity).toInt(),
      isLoading: true,
    );
    _updateLocalState(videoId, newState);

    // Track analytics
    _trackUnlikeEvent(videoId);

    // Network operation
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
      debugPrint(
          '📱 LikeService: Queued unlike operation for offline processing');
    }
  }

  /// Double-tap like (never unlikes)
  Future<void> doubleTapLike(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    // Double-tap never unlikes - only likes if not already liked
    if (!currentState.isLiked) {
      await likeVideo(videoId, userId, source: 'double_tap');
    }
  }

  /// Subscribe to real-time like count updates
  StreamSubscription<LikeState> subscribeToVideo(String videoId) {
    if (_subscriptions.containsKey(videoId)) {
      _subscriptions[videoId]!.cancel();
    }

    final subscription = _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;

          final data = snapshot.data()!;
          final serverCount = data['likeCount'] ?? 0;

          final localState = _localCache[videoId];
          return LikeState(
            videoId: videoId,
            isLiked: localState?.isLiked ?? false,
            likeCount: serverCount,
            isLoading: false,
          );
        })
        .where((state) => state != null)
        .cast<LikeState>()
        .listen((serverState) {
          // Reconcile with local state
          _reconcileServerState(videoId, serverState);
        });

    _subscriptions[videoId] = subscription;
    return subscription;
  }

  /// Perform actual like operation on server
  Future<void> _performLikeOperation(LikeOperation operation) async {
    try {
      final batch = _firestore.batch();

      // Create/update like document
      final likeRef = _firestore
          .collection('likes')
          .doc(operation.videoId)
          .collection('byUser')
          .doc(operation.userId);

      if (operation.action == LikeAction.like) {
        batch.set(
            likeRef,
            {
              'createdAt': FieldValue.serverTimestamp(),
              'videoId': operation.videoId,
              'userId': operation.userId,
            },
            SetOptions(merge: true));

        // Increment counter atomically
        batch.update(
          _firestore.collection('videos').doc(operation.videoId),
          {'likeCount': FieldValue.increment(1)},
        );
      } else {
        batch.delete(likeRef);

        // Decrement counter atomically
        batch.update(
          _firestore.collection('videos').doc(operation.videoId),
          {'likeCount': FieldValue.increment(-1)},
        );
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

      debugPrint(
          '✅ LikeService: Successfully ${operation.action.name}d video ${operation.videoId}');
    } catch (e) {
      debugPrint(
          '❌ LikeService: Failed to ${operation.action.name} video ${operation.videoId}: $e');

      // Revert optimistic update after 2 seconds if still failing
      Timer(const Duration(seconds: 2), () async {
        try {
          await _performLikeOperation(operation);
        } catch (retryError) {
          debugPrint(
              '❌ LikeService: Retry failed, reverting optimistic update');
          await _revertOptimisticUpdate(operation);
        }
      });
    }
  }

  /// Process offline queue when coming back online
  Future<void> _processOfflineQueue() async {
    debugPrint(
        '📱 LikeService: Processing ${_offlineQueue.length} queued operations');

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
    // Notify listeners would go here if using ChangeNotifier
  }

  /// Reconcile server state with local state
  void _reconcileServerState(String videoId, LikeState serverState) {
    final localState = _localCache[videoId];
    if (localState != null && !localState.isLoading) {
      // Only update if not currently processing
      final reconciledState = serverState.copyWith(
        isLiked: localState.isLiked, // Keep local like state
      );
      _updateLocalState(videoId, reconciledState);
    }
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

      for (final key in keys) {
        final videoId = key.substring(5); // Remove 'like_' prefix
        final isLiked = prefs.getBool(key) ?? false;

        _localCache[videoId] = LikeState(
          videoId: videoId,
          isLiked: isLiked,
          likeCount: 0, // Will be updated by server sync
          isLoading: false,
        );
      }

      debugPrint(
          '📱 LikeService: Loaded ${_localCache.length} cached like states');
    } catch (e) {
      debugPrint('❌ LikeService: Failed to load cached states: $e');
    }
  }

  /// Save like state to local storage
  Future<void> _saveCachedState(String videoId, LikeState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('like_$videoId', state.isLiked);
    } catch (e) {
      debugPrint('❌ LikeService: Failed to save cached state: $e');
    }
  }

  /// Track analytics events
  void _trackLikeEvent(String videoId, String source,
      {required bool wasLikedBefore}) {
    debugPrint(
        '📊 LikeService: like_tap - video: $videoId, source: $source, wasLikedBefore: $wasLikedBefore');
    // Analytics tracking would go here
  }

  void _trackUnlikeEvent(String videoId) {
    debugPrint('📊 LikeService: unlike_tap - video: $videoId');
    // Analytics tracking would go here
  }

  /// Check if a video is liked
  Future<bool> isVideoLiked(String videoId) async {
    final state = getLikeState(videoId);
    return state.isLiked;
  }

  /// Get like count for a video
  Future<int> getLikeCount(String videoId) async {
    final state = getLikeState(videoId);
    return state.likeCount;
  }

  /// Set event trigger service (for compatibility)
  void setEventTriggerService(dynamic eventTriggerService) {
    // No-op for compatibility with existing code
  }

  /// Toggle like status (for compatibility with existing code)
  Future<void> toggleLike(String videoId, {String? userId}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final actualUserId = userId ?? currentUser?.uid;

    if (actualUserId == null) {
      debugPrint('❌ LikeService: No user ID available for toggleLike');
      return;
    }

    final currentState = getLikeState(videoId);
    if (currentState.isLiked) {
      await unlikeVideo(videoId, actualUserId);
    } else {
      await likeVideo(videoId, actualUserId);
    }
  }

  /// Track like engagement (for compatibility with existing code)
  void trackLikeEngagement(String videoId, bool isLiked) {
    if (isLiked) {
      final currentState = getLikeState(videoId);
      _trackLikeEvent(videoId, 'button', wasLikedBefore: currentState.isLiked);
    } else {
      _trackUnlikeEvent(videoId);
    }
  }

  /// Format like count for display
  String formatLikeCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  /// Cleanup resources
  void dispose() {
    _connectivitySub?.cancel();
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _localCache.clear();
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
