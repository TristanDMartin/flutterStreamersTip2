import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'network_connectivity_service.dart';

/// Like state for a video
class LikeState {
  final bool isLiked;
  final int likeCount;
  final DateTime timestamp;

  LikeState({
    required this.isLiked,
    required int likeCount,
    required this.timestamp,
  }) : likeCount = likeCount < 0 ? 0 : likeCount {
    // TikTok-style: Enforce non-negative counts at construction
    if (likeCount < 0) {
      debugPrint(
          '⚠️ LikeState: Negative count detected ($likeCount), clamping to 0');
    }
  }

  LikeState copyWith({
    bool? isLiked,
    int? likeCount,
    DateTime? timestamp,
  }) {
    return LikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount, // Constructor will validate
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Offline like operation
class LikeOperation {
  final String videoId;
  final String userId;
  final bool isLike;
  final DateTime timestamp;

  LikeOperation({
    required this.videoId,
    required this.userId,
    required this.isLike,
    required this.timestamp,
  });
}

/// Complete StreamersTip-style Like Service with Firebase persistence and ML scoring
///
/// Features:
/// - Optimistic UI updates (instant heart fill)
/// - Firebase persistence (/likes/{videoId}/byUser/{userId})
/// - Atomic like count updates
/// - ML scoring integration (mlScore.love)
/// - Idempotent operations (prevents duplicate likes)
/// - Offline queue with retry
/// - Real-time sync
class StreamersTipLikeService extends ChangeNotifier {
  static final StreamersTipLikeService _instance =
      StreamersTipLikeService._internal();
  factory StreamersTipLikeService() => _instance;
  static StreamersTipLikeService get instance => _instance;
  StreamersTipLikeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  // Backend API base URL for like/unlike operations
  // NOTE: update this to the actual backend host if different.
  static const String _apiBaseUrl = 'https://streamerstip.com';

  // Local state cache
  final Map<String, LikeState> _localCache = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // Offline queue
  final List<LikeOperation> _offlineQueue = [];
  Timer? _offlineTimer;

  // Rate limiting
  final Map<String, DateTime> _lastLikeTimes = {};
  static const Duration _rateLimit = Duration(seconds: 1);

  // State management
  bool _isInitialized = false;

  /// Initialize the service
  ///
  /// TikTok-Style initialization:
  /// 1. Load cached states from SharedPreferences (offline access)
  /// 2. Load user's liked_videos from Firestore (cross-device sync)
  /// 3. Start offline queue processing
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    debugPrint('🚀 StreamersTipLikeService: Starting initialization...');

    try {
      // 1. Load cached states from SharedPreferences (survives app restarts)
      await _loadCachedStates();

      // 2. TikTok-Style: Load user's liked videos from Firestore (survives device changes)
      if (userId != null) {
        await loadUserLikedVideos(userId);
      } else {
        debugPrint('⚠️ No userId provided, skipping liked_videos sync');
      }

      // 3. Start offline sync timer
      _startOfflineSyncTimer();

      // 4. Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen((_) {
        _processOfflineQueue();
      });

      _isInitialized = true;
      debugPrint(
          '✅ StreamersTipLikeService: Initialization complete - cached states: ${_localCache.length}');
    } catch (e) {
      debugPrint('❌ StreamersTipLikeService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Get like state for a video
  LikeState getLikeState(String videoId) {
    final cachedState = _localCache[videoId];
    final result = cachedState ??
        LikeState(isLiked: false, likeCount: 0, timestamp: DateTime.now());

    //     debugPrint(
    //     '🔍 StreamersTipLikeService: getLikeState($videoId) - cached: ${cachedState != null}, isLiked: ${result.isLiked}, likeCount: ${result.likeCount}');

    return result;
  }

  /// Load like count from Firebase for a specific video
  Future<void> loadVideoLikeCount(String videoId) async {
    try {
      // Check network connectivity first
      final networkService = NetworkConnectivityService();
      if (!await networkService.checkFirebaseConnectivity()) {
        debugPrint(
            '🌐 StreamersTipLikeService: No Firebase connectivity, skipping like count load');
        return;
      }

      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (videoDoc.exists) {
        final data = videoDoc.data()!;
        final likeCount = (data['likeCount'] ?? 0) as int;

        // Always update/create state (not just when currentState exists)
        final currentState = _localCache[videoId];
        final updatedState = currentState != null
            ? currentState.copyWith(
                likeCount: likeCount,
                timestamp: DateTime.now(),
              )
            : LikeState(
                isLiked: false,
                likeCount: likeCount,
                timestamp: DateTime.now(),
              );

        _localCache[videoId] = updatedState;
        notifyListeners();

        debugPrint(
            '📊 StreamersTipLikeService: Loaded like count for $videoId: $likeCount');
      } else {
        debugPrint(
            '⚠️ StreamersTipLikeService: Video document not found for $videoId');
      }
    } catch (e) {
      debugPrint(
          '❌ StreamersTipLikeService: Failed to load like count for $videoId: $e');
    }
  }

  /// TikTok-Style: Load user's liked videos when app opens or feed loads
  ///
  /// This fetches the user's `liked_videos` array from their profile.
  /// As videos load in the feed, the app cross-checks each video ID.
  /// If it exists in this list, the heart appears filled immediately.
  ///
  /// Benefits:
  /// - Survives app closes (persisted in Firestore)
  /// - Works across devices (same user profile)
  /// - Fast lookup (single array check vs. querying each video)
  Future<void> loadUserLikedVideos(String userId) async {
    try {
      debugPrint('🔄 Loading liked videos for user: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found: $userId');
        return;
      }

      final data = userDoc.data();
      final likedVideos =
          (data?['liked_videos'] as List<dynamic>?)?.cast<String>() ?? [];

      debugPrint(
          '✅ Found ${likedVideos.length} liked videos for user: $userId');

      // Update local cache with liked state
      for (final videoId in likedVideos) {
        final currentState = _localCache[videoId];
        final updatedState = LikeState(
          isLiked: true,
          likeCount: currentState?.likeCount ??
              0, // Keep existing count or default to 0
          timestamp: DateTime.now(),
        );
        _localCache[videoId] = updatedState;
      }

      notifyListeners();
      debugPrint(
          '💾 Cached ${likedVideos.length} liked video states (survives app restarts)');
    } catch (e) {
      debugPrint('❌ Error loading liked videos: $e');
    }
  }

  /// TikTok-Style: Check if a specific video is liked by current user
  ///
  /// This is called when videos load in the feed to determine initial heart state.
  /// Uses the cached liked_videos array for fast lookup.
  Future<bool> isVideoLikedByUser(String videoId, String userId) async {
    try {
      // First check local cache
      final cachedState = _localCache[videoId];
      if (cachedState != null) {
        return cachedState.isLiked;
      }

      // If not in cache, check Firestore user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final likedVideos =
          (userDoc.data()?['liked_videos'] as List<dynamic>?)?.cast<String>() ??
              [];

      final isLiked = likedVideos.contains(videoId);

      // Update cache
      _localCache[videoId] = LikeState(
        isLiked: isLiked,
        likeCount: 0, // Will be updated when video data loads
        timestamp: DateTime.now(),
      );

      return isLiked;
    } catch (e) {
      debugPrint('❌ Error checking if video is liked: $e');
      return false;
    }
  }

  /// Like a video (idempotent)
  Future<bool> likeVideo(String videoId, String userId,
      {String source = 'tap'}) async {
    // Check if already liked
    final currentState = getLikeState(videoId);
    if (currentState.isLiked) {
      debugPrint(
          '💖 StreamersTipLikeService: Already liked, ignoring double-tap');
      return false; // Already liked, return false to prevent animation
    }

    // Rate limiting
    if (_isRateLimited(videoId)) {
      debugPrint('🚫 StreamersTipLikeService: Rate limited');
      return false;
    }

    // Optimistic update
    final newState = currentState.copyWith(
      isLiked: true,
      likeCount: currentState.likeCount + 1,
      timestamp: DateTime.now(),
    );
    _updateLocalState(videoId, newState);

    try {
      await _performLikeOperation(videoId, userId, true);
      _lastLikeTimes[videoId] = DateTime.now();
      _trackLikeEngagement(videoId, source);
      debugPrint('💖 StreamersTipLikeService: Video liked successfully');
      return true;
    } catch (e) {
      debugPrint('⚠️ StreamersTipLikeService: Like sync deferred: $e');
      _enqueueOfflineOperation(videoId, userId, true);
      return true; // keep optimistic state for persistence
    }
  }

  /// Double-tap like (returns true if animation should show)
  Future<bool> doubleTapLike(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    // Always show animation for double-tap, even if already liked
    // This provides better user feedback and feels more responsive
    if (currentState.isLiked) {
      debugPrint(
          '💖 StreamersTipLikeService: Already liked, but showing animation for feedback');
      // Trigger a brief animation even if already liked
      _triggerLikeAnimation(videoId);
      return true; // Show animation for better UX
    }

    return await likeVideo(videoId, userId, source: 'double_tap');
  }

  /// Trigger a brief like animation for visual feedback
  void _triggerLikeAnimation(String videoId) {
    // This could be used to trigger a subtle animation
    // even when the video is already liked
    debugPrint(
        '✨ StreamersTipLikeService: Triggering like animation for $videoId');
  }

  /// Toggle like state (like if not liked, unlike if liked)
  Future<bool> toggleLike(String videoId, String userId) async {
    final currentState = getLikeState(videoId);

    if (currentState.isLiked) {
      return await unlikeVideo(videoId, userId);
    } else {
      return await likeVideo(videoId, userId, source: 'button_tap');
    }
  }

  /// Unlike a video (idempotent)
  Future<bool> unlikeVideo(String videoId, String userId) async {
    // Check if already not liked
    final currentState = getLikeState(videoId);
    if (!currentState.isLiked) {
      debugPrint('💔 StreamersTipLikeService: Not liked, ignoring unlike');
      return true; // Already not liked, consider it successful
    }

    // TikTok-style: Prevent negative counts - don't unlike if count is already 0
    if (currentState.likeCount <= 0) {
      debugPrint(
          '⚠️ StreamersTipLikeService: Cannot unlike - count already at 0 (TikTok-style protection)');
      // Still mark as not liked locally, but don't decrement count
      final newState = currentState.copyWith(
        isLiked: false,
        likeCount: 0,
        timestamp: DateTime.now(),
      );
      _updateLocalState(videoId, newState);
      return true;
    }

    // Rate limiting
    if (_isRateLimited(videoId)) {
      debugPrint('🚫 StreamersTipLikeService: Rate limited');
      return false;
    }

    // Optimistic update with TikTok-style protection
    final newLikeCount =
        (currentState.likeCount - 1).clamp(0, double.infinity).toInt();
    final newState = currentState.copyWith(
      isLiked: false,
      likeCount: newLikeCount,
      timestamp: DateTime.now(),
    );
    _updateLocalState(videoId, newState);

    try {
      await _performLikeOperation(videoId, userId, false);
      _lastLikeTimes[videoId] = DateTime.now();
      debugPrint('💔 StreamersTipLikeService: Video unliked successfully');
      return true;
    } catch (e) {
      debugPrint('⚠️ StreamersTipLikeService: Unlike sync deferred: $e');
      _enqueueOfflineOperation(videoId, userId, false);
      return true; // keep optimistic state for persistence
    }
  }

  /// Perform the actual Firebase like operation
  ///
  /// TikTok-Style Data Storage:
  /// A. Video Document (Shared Data):
  ///    - likeCount: Total number of likes (global counter)
  ///    - lastLikedAt: Timestamp of most recent like
  ///
  /// B. Like Document (Relationship):
  ///    - /likes/{videoId}/byUser/{userId}: Individual like records
  ///    - Used for validation and querying who liked what
  ///
  /// C. User Profile (Personal State):
  ///    - /users/{userId}/liked_videos: Array of video IDs user has liked
  ///    - Enables fast lookup when loading feed ("is this video liked by me?")
  ///    - Survives app closes, device changes, and logouts
  Future<void> _performLikeOperation(
      String videoId, String userId, bool isLike) async {
    final endpoint = isLike ? '/api/like' : '/api/unlike';
    final uri = Uri.parse('$_apiBaseUrl$endpoint');
    final payload = {
      'videoId': videoId,
      'userId': userId,
    };

    // Primary attempt: JSON body
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
          '⚠️ Like API primary failed ${response.statusCode}: ${response.body}');

      // Fallback 1: trailing slash
      final altUri = Uri.parse('$_apiBaseUrl$endpoint/');
      final altResponse = await http.post(
        altUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (altResponse.statusCode >= 200 && altResponse.statusCode < 300) {
        debugPrint(
            '✅ Like API succeeded via trailing slash for $videoId (isLike=$isLike)');
        return;
      }

      // Fallback 2: form-encoded (in case server expects it)
      final formResponse = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      );

      if (formResponse.statusCode >= 200 && formResponse.statusCode < 300) {
        debugPrint(
            '✅ Like API succeeded via form-encoded for $videoId (isLike=$isLike)');
        return;
      }

      throw Exception(
        'Like API failed: primary ${response.statusCode}, '
        'alt ${altResponse.statusCode}, form ${formResponse.statusCode}',
      );
    }

    debugPrint(
        '✅ Like API ${isLike ? 'like' : 'unlike'} succeeded for video=$videoId user=$userId');
  }

  void _enqueueOfflineOperation(String videoId, String userId, bool isLike) {
    _offlineQueue.add(LikeOperation(
      videoId: videoId,
      userId: userId,
      isLike: isLike,
      timestamp: DateTime.now(),
    ));
  }

  /// Check if operation is rate limited
  bool _isRateLimited(String videoId) {
    final lastTime = _lastLikeTimes[videoId];
    if (lastTime == null) return false;

    return DateTime.now().difference(lastTime) < _rateLimit;
  }

  /// Process offline queue when connectivity is restored
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint(
          '📱 StreamersTipLikeService: Processing ${_offlineQueue.length} queued operations');

      return;
    }

    final operations = List<LikeOperation>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final operation in operations) {
      try {
        if (operation.isLike) {
          await _performLikeOperation(
              operation.videoId, operation.userId, true);
          debugPrint('✅ StreamersTipLikeService: Liked ${operation.videoId}');
        } else {
          await _performLikeOperation(
              operation.videoId, operation.userId, false);
          debugPrint('✅ StreamersTipLikeService: Unliked ${operation.videoId}');
        }
      } catch (e) {
        debugPrint('❌ StreamersTipLikeService: Firebase operation failed: $e');
        // Re-queue for retry
        _offlineQueue.add(operation);
      }
    }

    if (_offlineQueue.isNotEmpty) {
      debugPrint('❌ StreamersTipLikeService: Retry failed, reverting');
      // Could implement exponential backoff here
    }
  }

  /// Start offline sync timer
  void _startOfflineSyncTimer() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _processOfflineQueue();
    });
  }

  /// Update local state and notify listeners
  void _updateLocalState(String videoId, LikeState newState) {
    _localCache[videoId] = newState;
    _saveCachedState(videoId, newState);
    notifyListeners();

    debugPrint(
        '🔄 StreamersTipLikeService: State updated for $videoId - isLiked: ${newState.isLiked}, likeCount: ${newState.likeCount}');
  }

  /// Save state to local cache
  Future<void> _saveCachedState(String videoId, LikeState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'like_state_$videoId';
      final data = jsonEncode({
        'isLiked': state.isLiked,
        'likeCount': state.likeCount,
        'timestamp': state.timestamp.millisecondsSinceEpoch,
      });
      await prefs.setString(key, data);
    } catch (e) {
      debugPrint('❌ StreamersTipLikeService: Failed to save cache: $e');
    }
  }

  /// Load cached states
  Future<void> _loadCachedStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('like_state_'));
      debugPrint(
          '📱 StreamersTipLikeService: Found ${keys.length} cached like states');

      for (final key in keys) {
        final videoId = key.replaceFirst('like_state_', '');
        final value = prefs.getString(key);

        if (value != null) {
          try {
            final data = jsonDecode(value) as Map<String, dynamic>;
            final isLiked = data['isLiked'] as bool? ?? false;
            final likeCount = data['likeCount'] as int? ?? 0;
            final tsMs = data['timestamp'] as int? ?? 0;
            final timestamp = tsMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(tsMs)
                : DateTime.now();

            _localCache[videoId] = LikeState(
              isLiked: isLiked,
              likeCount: likeCount,
              timestamp: timestamp,
            );

            debugPrint(
                '📱 StreamersTipLikeService: Loaded cached state for $videoId - isLiked: $isLiked, likeCount: $likeCount');
          } catch (e) {
            debugPrint(
                '⚠️ StreamersTipLikeService: Failed to parse cache for $videoId: $e');
          }
        }
      }

      debugPrint(
          '📱 StreamersTipLikeService: Loaded ${_localCache.length} cached states total');
    } catch (e) {
      debugPrint('❌ StreamersTipLikeService: Failed to load cache: $e');
    }
  }

  /// Sync like counts from server
  Future<void> syncLikeCounts(List<String> videoIds) async {
    if (videoIds.isEmpty) return;

    debugPrint(
        '🔄 StreamersTipLikeService: Syncing like counts from server...');

    try {
      final futures = <Future>[];

      for (final videoId in videoIds) {
        final videoDocRef = _firestore.collection('videos').doc(videoId);

        final future = videoDocRef.get().then((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            final likeCount = (data['likeCount'] ?? 0) as int;
            final currentState = _localCache[videoId];

            if (currentState != null) {
              final updatedState = currentState.copyWith(
                likeCount: likeCount,
                timestamp: DateTime.now(),
              );
              _localCache[videoId] = updatedState;
            }

            debugPrint(
                '📊 StreamersTipLikeService: Synced like count for $videoId: $likeCount (from video document)');
          } else {
            debugPrint(
                '⚠️ StreamersTipLikeService: Video document not found for $videoId');
          }
        }).catchError((e) {
          debugPrint(
              '⚠️ StreamersTipLikeService: Failed to sync like count for $videoId: $e');
        });

        futures.add(future);
      }

      await Future.wait(futures);
      notifyListeners();
      debugPrint('✅ StreamersTipLikeService: Like count sync completed');
    } catch (e) {
      debugPrint('❌ StreamersTipLikeService: Failed to sync like counts: $e');
    }
  }

  /// Track like engagement for analytics
  void _trackLikeEngagement(String videoId, String source) {
    // Analytics tracking
    debugPrint(
        '📊 StreamersTipLikeService: like_tap - video: $videoId, source: $source');
  }

  /// Dispose resources
  @override
  void dispose() {
    _offlineTimer?.cancel();
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
