import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'network_connectivity_service.dart';
import '../features/gamification/emit_engagement_gamification.dart';
import '../features/gamification/gamification_event_types.dart';
import 'progression_service.dart';

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
  String? _syncedUserId;

  /// Initialize the service
  ///
  /// TikTok-Style initialization:
  /// 1. Load cached states from SharedPreferences (offline access)
  /// 2. Load user's liked_videos from Firestore (cross-device sync)
  /// 3. Start offline queue processing
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) {
      if (userId != null && userId != _syncedUserId) {
        await loadUserLikedVideos(userId);
      }
      return;
    }

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
        final serverLikeCount = _readLikeCount(data);

        // Always update/create state (not just when currentState exists)
        final currentState = _localCache[videoId];
        final likeCount = _coerceServerLikeCount(
          serverLikeCount: serverLikeCount,
          currentState: currentState,
        );
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

      final likedVideos = <String>{};

      // Canonical cross-platform likes (/likes/{videoId}/byUser/{userId}).
      try {
        final canonicalLikes = await _firestore
            .collectionGroup('byUser')
            .where('userId', isEqualTo: userId)
            .limit(1000)
            .get();
        for (final doc in canonicalLikes.docs) {
          final data = doc.data();
          final videoId =
              (data['videoId'] as String?) ?? doc.reference.parent.parent?.id;
          if (videoId != null && videoId.isNotEmpty) {
            likedVideos.add(videoId);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Canonical liked videos query failed: $e');
      }

      // Compatibility mirrors from older mobile/web implementations.
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      likedVideos.addAll(
        (data?['liked_videos'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const <String>[],
      );

      try {
        final likedVideoDocs = await _firestore
            .collection('users')
            .doc(userId)
            .collection('likedVideos')
            .limit(1000)
            .get();
        for (final doc in likedVideoDocs.docs) {
          likedVideos.add((doc.data()['videoId'] as String?) ?? doc.id);
        }
      } catch (e) {
        debugPrint('⚠️ Legacy likedVideos query failed: $e');
      }

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

      // Clear stale local hearts that were unliked on another device/site.
      for (final entry in List<MapEntry<String, LikeState>>.from(
        _localCache.entries,
      )) {
        if (entry.value.isLiked && !likedVideos.contains(entry.key)) {
          final updatedState = entry.value.copyWith(
            isLiked: false,
            timestamp: DateTime.now(),
          );
          _localCache[entry.key] = updatedState;
          unawaited(_saveCachedState(entry.key, updatedState));
        }
      }

      _syncedUserId = userId;
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
      if (cachedState?.isLiked == true) {
        return true;
      }

      final videoScopedDoc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(userId)
          .get();
      if (videoScopedDoc.exists) {
        _localCache[videoId] = LikeState(
          isLiked: true,
          likeCount: cachedState?.likeCount ?? 0,
          timestamp: DateTime.now(),
        );
        return true;
      }

      final canonicalDoc = await _firestore
          .collection('likes')
          .doc(videoId)
          .collection('byUser')
          .doc(userId)
          .get();
      if (canonicalDoc.exists) {
        _localCache[videoId] = LikeState(
          isLiked: true,
          likeCount: cachedState?.likeCount ?? 0,
          timestamp: DateTime.now(),
        );
        return true;
      }

      final legacyDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId)
          .get();
      if (legacyDoc.exists) {
        _localCache[videoId] = LikeState(
          isLiked: true,
          likeCount: cachedState?.likeCount ?? 0,
          timestamp: DateTime.now(),
        );
        return true;
      }

      // Final compatibility check for the legacy array field.
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final likedVideos = (userDoc.data()?['liked_videos'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];

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
      scheduleEngagementGamificationEvent(
        type: GamificationEventTypes.engagementLikeGiven,
        entityType: 'video',
        entityId: videoId,
        source: 'likes',
      );
      unawaited(ProgressionService.instance.markTaskCompleted(
        userId,
        ProgressionTaskIds.firstLikeGiven,
        source: 'likes',
      ));
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
    final legacyLikeRef = _firestore
        .collection('likes')
        .doc(videoId)
        .collection('byUser')
        .doc(userId);
    final userRef = _firestore.collection('users').doc(userId);
    final legacyLikedRef = userRef.collection('likedVideos').doc(videoId);
    final videoRef = _firestore.collection('videos').doc(videoId);
    final videoLikeRef = videoRef.collection('likes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(videoLikeRef);
      final legacyLikeSnapshot = await transaction.get(legacyLikeRef);
      final videoSnapshot = await transaction.get(videoRef);
      final videoData = videoSnapshot.data();
      final currentCount = videoData == null ? 0 : _readLikeCount(videoData);
      final alreadyLiked = likeSnapshot.exists || legacyLikeSnapshot.exists;

      if (isLike) {
        transaction.set(
          videoLikeRef,
          {
            'userId': userId,
            'videoId': videoId,
            'likedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          legacyLikeRef,
          {
            'userId': userId,
            'videoId': videoId,
            'likedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          legacyLikedRef,
          {
            'videoId': videoId,
            'likedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          userRef,
          {
            'liked_videos': FieldValue.arrayUnion([videoId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (!alreadyLiked && videoSnapshot.exists) {
          final nextCount = currentCount + 1;
          transaction.update(videoRef, {
            'likes': nextCount,
            'likeCount': nextCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        transaction.delete(videoLikeRef);
        transaction.delete(legacyLikeRef);
        transaction.delete(legacyLikedRef);
        transaction.set(
          userRef,
          {
            'liked_videos': FieldValue.arrayRemove([videoId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (alreadyLiked && videoSnapshot.exists) {
          final nextCount = (currentCount - 1).clamp(0, 1 << 31).toInt();
          transaction.update(videoRef, {
            'likes': nextCount,
            'likeCount': nextCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    debugPrint(
        '✅ Firestore ${isLike ? 'like' : 'unlike'} persisted for video=$videoId user=$userId');
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
            final currentState = _localCache[videoId];
            final likeCount = _coerceServerLikeCount(
              serverLikeCount: _readLikeCount(data),
              currentState: currentState,
            );

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

  int _readLikeCount(Map<String, dynamic> data) {
    for (final key in const ['likeCount', 'likesCount', 'likes']) {
      final dynamic value = data[key];
      if (value is num) {
        return value.toInt().clamp(0, 1 << 31).toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed.clamp(0, 1 << 31).toInt();
        }
      }
    }
    return 0;
  }

  int _coerceServerLikeCount({
    required int serverLikeCount,
    required LikeState? currentState,
  }) {
    if (serverLikeCount > 0) return serverLikeCount;
    if (currentState?.isLiked == true) {
      final optimisticCount = currentState?.likeCount ?? 0;
      return optimisticCount > 0 ? optimisticCount : 1;
    }
    return 0;
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
