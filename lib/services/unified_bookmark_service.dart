import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../features/bookmarks/data/calendar_event_bookmark_coordinator.dart';
import '../features/bookmarks/models/video_bookmark_stream_event.dart';
import '../models/bookmark_event.dart' as calendar;
import 'creator_intelligence_analytics_service.dart';
import '../features/gamification/emit_engagement_gamification.dart';
import '../features/gamification/gamification_event_types.dart';
import '../utils/video_document_rules.dart';
import 'progression_service.dart';

/// Unified Bookmark Service - Single source of truth for bookmark operations
///
/// - **Video favorites:** `users/{uid}/favorites`, `videos/{id}/bookmarks/{uid}`
/// - **Calendar events:** `users/{uid}/bookmarks/{eventId}` via
///   [CalendarEventBookmarkCoordinator]
class UnifiedBookmarkService extends ChangeNotifier {
  static final UnifiedBookmarkService _instance =
      UnifiedBookmarkService._internal();
  factory UnifiedBookmarkService() => _instance;
  static UnifiedBookmarkService get instance => _instance;
  UnifiedBookmarkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CalendarEventBookmarkCoordinator _calendarEventBookmarks =
      CalendarEventBookmarkCoordinator();

  // State management
  final Map<String, BookmarkState> _bookmarkStates = {};
  final Set<String> _pendingOperations = {};
  final StreamController<VideoBookmarkStreamEvent> _eventController =
      StreamController<VideoBookmarkStreamEvent>.broadcast();
  String? _initializedUserId;
  bool _hasLoadedInitialState = false;
  Future<void>? _initializationInFlight;
  String? _initializationInFlightUserId;

  // Getters
  Stream<VideoBookmarkStreamEvent> get eventStream => _eventController.stream;
  Map<String, BookmarkState> get bookmarkStates => Map.from(_bookmarkStates);

  /// Check if a video is bookmarked
  bool isBookmarked(String videoId) {
    final state = _bookmarkStates[videoId];
    return state?.isBookmarked ?? false;
  }

  /// Bookmarked video ids, newest `favoritedAt` first (nulls last).
  List<String> get orderedBookmarkedVideoIds {
    final List<MapEntry<String, BookmarkState>> entries = _bookmarkStates
        .entries
        .where((MapEntry<String, BookmarkState> e) => e.value.isBookmarked)
        .toList();
    entries.sort(_compareFavoritedAtDesc);
    return entries.map((MapEntry<String, BookmarkState> e) => e.key).toList();
  }

  static int _compareFavoritedAtDesc(
    MapEntry<String, BookmarkState> a,
    MapEntry<String, BookmarkState> b,
  ) {
    final DateTime? ta = a.value.favoritedAt;
    final DateTime? tb = b.value.favoritedAt;
    if (ta == null && tb == null) {
      return 0;
    }
    if (ta == null) {
      return 1;
    }
    if (tb == null) {
      return -1;
    }
    return tb.compareTo(ta);
  }

  /// Get bookmark state for a video
  BookmarkState? getBookmarkState(String videoId) {
    return _bookmarkStates[videoId];
  }

  /// Check if there's a pending operation for a video
  bool hasPendingOperation(String videoId) {
    return _pendingOperations.contains(videoId);
  }

  /// Initialize the service and load user's bookmarks
  Future<void> initialize(String userId) async {
    if (_initializedUserId == userId && _hasLoadedInitialState) {
      return;
    }
    final Future<void>? inFlight = _initializationInFlight;
    if (inFlight != null && _initializationInFlightUserId == userId) {
      return inFlight;
    }

    final Future<void> initialization = _initializeForUser(userId);
    _initializationInFlight = initialization;
    _initializationInFlightUserId = userId;
    return initialization.whenComplete(() {
      if (identical(_initializationInFlight, initialization)) {
        _initializationInFlight = null;
        _initializationInFlightUserId = null;
      }
    });
  }

  Future<void> _initializeForUser(String userId) async {
    try {
      debugPrint('🔄 UnifiedBookmarkService: Initializing for user $userId');
      if (_initializedUserId != null && _initializedUserId != userId) {
        _bookmarkStates.clear();
        _pendingOperations.clear();
      }
      _initializedUserId = userId;

      // Load user's bookmarks from Firebase
      await _loadUserBookmarks(userId);
      _hasLoadedInitialState = true;

      debugPrint('✅ UnifiedBookmarkService: Initialized successfully');
    } catch (e) {
      _hasLoadedInitialState = false;
      debugPrint('❌ UnifiedBookmarkService: Initialization failed: $e');
      _eventController.add(
        VideoBookmarkStreamEvent.error('Initialization failed: $e'),
      );
    }
  }

  /// Load user's bookmarks from Firebase
  Future<void> _loadUserBookmarks(String userId) async {
    try {
      final Map<String, DateTime?> favoritedAtByVideoId = <String, DateTime?>{};
      _bookmarkStates.clear();

      try {
        final canonicalBookmarks = await _firestore
            .collectionGroup('bookmarks')
            .where('userId', isEqualTo: userId)
            .limit(1000)
            .get();
        for (final doc in canonicalBookmarks.docs) {
          final Map<String, dynamic> data = doc.data();
          final String? videoId =
              (data['videoId'] as String?) ?? doc.reference.parent.parent?.id;
          if (videoId == null || videoId.isEmpty) {
            continue;
          }
          favoritedAtByVideoId[videoId] =
              _readFavoritedAt(data) ?? favoritedAtByVideoId[videoId];
        }
      } catch (e) {
        debugPrint(
            '⚠️ UnifiedBookmarkService: Canonical bookmark query failed: $e');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      for (final doc in snapshot.docs) {
        final String videoId = doc.id;
        final DateTime? at = _readFavoritedAt(doc.data());
        favoritedAtByVideoId[videoId] = at ?? favoritedAtByVideoId[videoId];
      }

      await _pruneDeletedVideoBookmarks(userId, favoritedAtByVideoId);

      for (final MapEntry<String, DateTime?> e
          in favoritedAtByVideoId.entries) {
        _bookmarkStates[e.key] = BookmarkState(
          videoId: e.key,
          isBookmarked: true,
          lastUpdated: DateTime.now(),
          status: BookmarkStatus.synced,
          favoritedAt: e.value,
        );
      }

      debugPrint(
          '📚 UnifiedBookmarkService: Loaded ${_bookmarkStates.length} bookmarks');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ UnifiedBookmarkService: Error loading bookmarks: $e');
      rethrow;
    }
  }

  Future<void> _pruneDeletedVideoBookmarks(
    String userId,
    Map<String, DateTime?> favoritedAtByVideoId,
  ) async {
    if (favoritedAtByVideoId.isEmpty) {
      return;
    }

    final Set<String> staleVideoIds = <String>{};
    const int batchSize = 10;
    final List<String> videoIds = favoritedAtByVideoId.keys.toList();

    for (int i = 0; i < videoIds.length; i += batchSize) {
      final List<String> batchIds = videoIds.skip(i).take(batchSize).toList();
      final QuerySnapshot<Map<String, dynamic>> videosSnapshot =
          await _firestore
              .collection('videos')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
      final Set<String> foundIds = videosSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
          .toSet();

      for (final String videoId in batchIds) {
        if (!foundIds.contains(videoId)) {
          staleVideoIds.add(videoId);
        }
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in videosSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        if (isVideoDeletedFromFirestore(data)) {
          staleVideoIds.add(doc.id);
        }
      }
    }

    if (staleVideoIds.isEmpty) {
      return;
    }

    for (final String videoId in staleVideoIds) {
      favoritedAtByVideoId.remove(videoId);
    }

    final List<String> staleList = staleVideoIds.toList();
    const int staleDeleteChunkSize = 150;
    for (int i = 0; i < staleList.length; i += staleDeleteChunkSize) {
      final WriteBatch writeBatch = _firestore.batch();
      for (final String videoId
          in staleList.skip(i).take(staleDeleteChunkSize)) {
        writeBatch.delete(
          _firestore
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .doc(videoId),
        );
        writeBatch.delete(
          _firestore
              .collection('videos')
              .doc(videoId)
              .collection('bookmarks')
              .doc(userId),
        );
        writeBatch.delete(
          _firestore
              .collection('user_favorites')
              .doc(userId)
              .collection('videos')
              .doc(videoId),
        );
      }
      await writeBatch.commit();
    }

    debugPrint(
      '🧹 UnifiedBookmarkService: Pruned ${staleVideoIds.length} deleted/missing video bookmarks',
    );
  }

  /// Atomic bookmark toggle operation
  Future<BookmarkResult> toggleBookmark(String videoId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return BookmarkResult.error('User not authenticated');
    }

    // Prevent duplicate operations
    if (_pendingOperations.contains(videoId)) {
      return BookmarkResult.error('Operation already in progress');
    }

    _pendingOperations.add(videoId);
    final currentState = _bookmarkStates[videoId];
    final isCurrentlyBookmarked = currentState?.isBookmarked ?? false;
    final DateTime? priorFavoritedAt = currentState?.favoritedAt;

    try {
      final newBookmarkState = !isCurrentlyBookmarked;

      // Optimistic update
      _updateLocalState(videoId, newBookmarkState, BookmarkStatus.pending);
      _eventController.add(
        VideoBookmarkStreamEvent.toggle(videoId, newBookmarkState),
      );

      // Perform atomic Firebase operation
      final result = await _performAtomicFirebaseOperation(
        videoId: videoId,
        userId: currentUser.uid,
        isBookmarking: newBookmarkState,
      );

      if (result.success) {
        // Update status to synced
        _updateLocalState(videoId, newBookmarkState, BookmarkStatus.synced);
        _eventController.add(
          VideoBookmarkStreamEvent.success(videoId, newBookmarkState),
        );
        if (newBookmarkState) {
          scheduleEngagementGamificationEvent(
            type: GamificationEventTypes.engagementBookmarkCreated,
            entityType: 'video',
            entityId: videoId,
            source: 'bookmarks',
          );
          unawaited(
            CreatorIntelligenceAnalyticsService()
                .trackPostSaved(videoId: videoId),
          );
          unawaited(ProgressionService.instance.markTaskCompleted(
            currentUser.uid,
            ProgressionTaskIds.firstBookmarkSaved,
            source: 'bookmarks',
          ));
        }

        return BookmarkResult.success(newBookmarkState);
      } else {
        // Revert optimistic update
        _updateLocalState(
          videoId,
          isCurrentlyBookmarked,
          BookmarkStatus.synced,
          favoritedAtOverride: isCurrentlyBookmarked ? priorFavoritedAt : null,
        );
        _eventController.add(
          VideoBookmarkStreamEvent.error(result.error ?? 'Unknown error'),
        );

        return BookmarkResult.error(result.error ?? 'Operation failed');
      }
    } catch (e) {
      // Revert optimistic update on error
      _updateLocalState(
        videoId,
        isCurrentlyBookmarked,
        BookmarkStatus.synced,
        favoritedAtOverride: isCurrentlyBookmarked ? priorFavoritedAt : null,
      );
      _eventController.add(
        VideoBookmarkStreamEvent.error('Operation failed: $e'),
      );

      return BookmarkResult.error('Operation failed: $e');
    } finally {
      _pendingOperations.remove(videoId);
    }
  }

  /// Perform atomic Firebase operation with retry logic
  Future<BookmarkResult> _performAtomicFirebaseOperation({
    required String videoId,
    required String userId,
    required bool isBookmarking,
  }) async {
    try {
      final userDocRef = _firestore.collection('users').doc(userId);
      final favoriteDocRef = userDocRef.collection('favorites').doc(videoId);
      final videoDocRef = _firestore.collection('videos').doc(videoId);
      final bookmarkDocRef = videoDocRef.collection('bookmarks').doc(userId);

      await _firestore.runTransaction<void>((transaction) async {
        final favoriteDoc = await transaction.get(favoriteDocRef);
        final bookmarkDoc = await transaction.get(bookmarkDocRef);
        final videoDoc = await transaction.get(videoDocRef);
        final bool exists = favoriteDoc.exists || bookmarkDoc.exists;

        int currentCount = 0;
        if (videoDoc.exists) {
          currentCount = _readBookmarkCount(videoDoc.data() ?? const {});
        }

        if (isBookmarking) {
          if (exists) {
            transaction.set(
              bookmarkDocRef,
              {
                'userId': userId,
                'videoId': videoId,
                'bookmarkedAt': FieldValue.serverTimestamp(),
                'favoritedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'source': 'mobile',
              },
              SetOptions(merge: true),
            );
            transaction.set(
              favoriteDocRef,
              {
                'videoId': videoId,
                'favoritedAt': FieldValue.serverTimestamp(),
                'timestamp': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'source': 'mobile',
              },
              SetOptions(merge: true),
            );
            if (videoDoc.exists) {
              final int nextCount = currentCount < 1 ? 1 : currentCount;
              transaction.set(
                videoDocRef,
                <String, dynamic>{
                  'bookmarkCount': nextCount,
                  'favorites': nextCount,
                  'favoriteCount': nextCount,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
            }
            return;
          }
          transaction.set(bookmarkDocRef, {
            'userId': userId,
            'videoId': videoId,
            'bookmarkedAt': FieldValue.serverTimestamp(),
            'favoritedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'source': 'mobile',
          });
          transaction.set(favoriteDocRef, {
            'videoId': videoId,
            'favoritedAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'source': 'mobile',
          });
          if (videoDoc.exists) {
            final nextCount = currentCount + 1;
            transaction.set(
              videoDocRef,
              <String, dynamic>{
                'bookmarkCount': nextCount,
                'favorites': nextCount,
                'favoriteCount': nextCount,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
          return;
        }

        if (!exists) {
          return;
        }
        transaction.delete(bookmarkDocRef);
        transaction.delete(favoriteDocRef);
        if (videoDoc.exists) {
          final nextCount = (currentCount - 1).clamp(0, 1 << 31).toInt();
          transaction.set(
            videoDocRef,
            <String, dynamic>{
              'bookmarkCount': nextCount,
              'favorites': nextCount,
              'favoriteCount': nextCount,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });

      debugPrint(
        isBookmarking
            ? '✅ UnifiedBookmarkService: Bookmark saved for $videoId'
            : '✅ UnifiedBookmarkService: Bookmark removed for $videoId',
      );

      return BookmarkResult.success(isBookmarking);
    } catch (e) {
      debugPrint('❌ UnifiedBookmarkService: Operation failed for $videoId: $e');
      return BookmarkResult.error('Operation failed: $e');
    }
  }

  int _readBookmarkCount(Map<String, dynamic> data) {
    for (final key in const [
      'bookmarkCount',
      'bookmarksCount',
      'savesCount',
      'bookmarks',
      'favoriteCount',
      'favorites',
    ]) {
      final value = data[key];
      if (value is num) return value.toInt().clamp(0, 1 << 31).toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed.clamp(0, 1 << 31).toInt();
      }
    }
    return 0;
  }

  static DateTime? _readFavoritedAt(Map<String, dynamic> data) {
    for (final String key in const <String>[
      'favoritedAt',
      'timestamp',
      'bookmarkedAt',
      'updatedAt',
    ]) {
      final Object? v = data[key];
      if (v is Timestamp) {
        return v.toDate();
      }
    }
    return null;
  }

  /// Update local state
  void _updateLocalState(
    String videoId,
    bool isBookmarked,
    BookmarkStatus status, {
    DateTime? favoritedAtOverride,
  }) {
    final BookmarkState? prev = _bookmarkStates[videoId];
    final DateTime? favoritedAt = !isBookmarked
        ? null
        : (favoritedAtOverride ??
            ((prev?.isBookmarked == true && prev?.favoritedAt != null)
                ? prev!.favoritedAt
                : DateTime.now()));
    _bookmarkStates[videoId] = BookmarkState(
      videoId: videoId,
      isBookmarked: isBookmarked,
      lastUpdated: DateTime.now(),
      status: status,
      favoritedAt: favoritedAt,
    );
    notifyListeners();
  }

  /// Force sync all pending operations
  Future<void> syncPendingOperations() async {
    final pendingStates = _bookmarkStates.values
        .where((state) => state.status == BookmarkStatus.pending)
        .toList();

    for (final state in pendingStates) {
      await toggleBookmark(state.videoId);
    }
  }

  /// Clear all bookmarks (for logout)
  Future<void> clearBookmarks() async {
    _bookmarkStates.clear();
    _pendingOperations.clear();
    _initializedUserId = null;
    _hasLoadedInitialState = false;
    _calendarEventBookmarks.reset();
    notifyListeners();
  }

  // ── Calendar event bookmarks (streamer schedule) ───────────────────────────

  Future<void> initializeCalendarEventBookmarks() =>
      _calendarEventBookmarks.initialize();

  Stream<List<calendar.BookmarkEvent>> calendarEventBookmarksStream() =>
      _calendarEventBookmarks.getBookmarksStream();

  Future<bool> bookmarkCalendarEvent({
    required String eventId,
    required String creatorId,
    String? creatorName,
    required String title,
    required DateTime startAt,
    DateTime? notifyAt,
    String source = 'streamerCardBackView',
  }) =>
      _calendarEventBookmarks.bookmarkEvent(
        eventId: eventId,
        creatorId: creatorId,
        creatorName: creatorName,
        title: title,
        startAt: startAt,
        notifyAt: notifyAt,
        source: source,
      );

  Future<bool> deleteCalendarEventBookmark({required String eventId}) =>
      _calendarEventBookmarks.deleteBookmark(eventId: eventId);

  Future<bool> toggleCalendarEventNotification({
    required String eventId,
    required bool notify,
  }) =>
      _calendarEventBookmarks.toggleNotification(
        eventId: eventId,
        notify: notify,
      );

  Future<Set<String>> fetchBookmarkedCalendarEventIds() =>
      _calendarEventBookmarks.fetchBookmarkedEventIds();

  bool isCalendarEventBookmarked(String eventId) =>
      _calendarEventBookmarks.isEventBookmarked(eventId);

  @override
  void dispose() {
    _calendarEventBookmarks.dispose();
    _eventController.close();
    super.dispose();
  }
}

/// Bookmark state model
class BookmarkState {
  final String videoId;
  final bool isBookmarked;
  final DateTime lastUpdated;
  final BookmarkStatus status;
  final DateTime? favoritedAt;

  BookmarkState({
    required this.videoId,
    required this.isBookmarked,
    required this.lastUpdated,
    required this.status,
    this.favoritedAt,
  });

  BookmarkState copyWith({
    String? videoId,
    bool? isBookmarked,
    DateTime? lastUpdated,
    BookmarkStatus? status,
    DateTime? favoritedAt,
  }) {
    return BookmarkState(
      videoId: videoId ?? this.videoId,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
      favoritedAt: favoritedAt ?? this.favoritedAt,
    );
  }
}

/// Bookmark status enum
enum BookmarkStatus {
  synced,
  pending,
  error,
}

/// Bookmark operation result
class BookmarkResult {
  final bool success;
  final bool? isBookmarked;
  final String? error;

  BookmarkResult._(this.success, {this.isBookmarked, this.error});

  factory BookmarkResult.success(bool isBookmarked) {
    return BookmarkResult._(true, isBookmarked: isBookmarked);
  }

  factory BookmarkResult.error(String error) {
    return BookmarkResult._(false, error: error);
  }
}
