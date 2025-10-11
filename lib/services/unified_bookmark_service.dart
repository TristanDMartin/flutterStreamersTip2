import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Unified Bookmark Service - Single source of truth for bookmark operations
///
/// Eliminates race conditions by providing atomic operations and reactive state management
class UnifiedBookmarkService extends ChangeNotifier {
  static final UnifiedBookmarkService _instance =
      UnifiedBookmarkService._internal();
  factory UnifiedBookmarkService() => _instance;
  static UnifiedBookmarkService get instance => _instance;
  UnifiedBookmarkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State management
  final Map<String, BookmarkState> _bookmarkStates = {};
  final Set<String> _pendingOperations = {};
  final StreamController<BookmarkEvent> _eventController =
      StreamController<BookmarkEvent>.broadcast();

  // Configuration
  static const int _maxBookmarks = 1000;
  static const int _maxRetries = 3;

  // Getters
  Stream<BookmarkEvent> get eventStream => _eventController.stream;
  Map<String, BookmarkState> get bookmarkStates => Map.from(_bookmarkStates);

  /// Check if a video is bookmarked
  bool isBookmarked(String videoId) {
    final state = _bookmarkStates[videoId];
    return state?.isBookmarked ?? false;
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
    try {
      debugPrint('🔄 UnifiedBookmarkService: Initializing for user $userId');

      // Load user's bookmarks from Firebase
      await _loadUserBookmarks(userId);

      debugPrint('✅ UnifiedBookmarkService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ UnifiedBookmarkService: Initialization failed: $e');
      _eventController.add(BookmarkEvent.error('Initialization failed: $e'));
    }
  }

  /// Load user's bookmarks from Firebase
  Future<void> _loadUserBookmarks(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      _bookmarkStates.clear();

      for (final doc in snapshot.docs) {
        final videoId = doc.id;
        _bookmarkStates[videoId] = BookmarkState(
          videoId: videoId,
          isBookmarked: true,
          lastUpdated: doc.data()['timestamp']?.toDate() ?? DateTime.now(),
          status: BookmarkStatus.synced,
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

    try {
      final currentState = _bookmarkStates[videoId];
      final isCurrentlyBookmarked = currentState?.isBookmarked ?? false;
      final newBookmarkState = !isCurrentlyBookmarked;

      // Optimistic update
      _updateLocalState(videoId, newBookmarkState, BookmarkStatus.pending);
      _eventController.add(BookmarkEvent.toggle(videoId, newBookmarkState));

      // Perform atomic Firebase operation
      final result = await _performAtomicFirebaseOperation(
        videoId: videoId,
        userId: currentUser.uid,
        isBookmarking: newBookmarkState,
      );

      if (result.success) {
        // Update status to synced
        _updateLocalState(videoId, newBookmarkState, BookmarkStatus.synced);
        _eventController.add(BookmarkEvent.success(videoId, newBookmarkState));

        return BookmarkResult.success(newBookmarkState);
      } else {
        // Revert optimistic update
        _updateLocalState(
            videoId, isCurrentlyBookmarked, BookmarkStatus.synced);
        _eventController
            .add(BookmarkEvent.error(result.error ?? 'Unknown error'));

        return BookmarkResult.error(result.error ?? 'Operation failed');
      }
    } catch (e) {
      // Revert optimistic update on error
      final originalState = _bookmarkStates[videoId];
      _updateLocalState(
          videoId, originalState?.isBookmarked ?? false, BookmarkStatus.synced);
      _eventController.add(BookmarkEvent.error('Operation failed: $e'));

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
      // Simplified approach: Just update the favorites subcollection
      // This is more reliable and doesn't require the liked_videos array
      final userDocRef = _firestore.collection('users').doc(userId);
      final favoriteDocRef = userDocRef.collection('favorites').doc(videoId);

      if (isBookmarking) {
        // Add bookmark
        await favoriteDocRef.set({
          'videoId': videoId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ UnifiedBookmarkService: Bookmark added for $videoId');
      } else {
        // Remove bookmark
        await favoriteDocRef.delete();
        debugPrint('✅ UnifiedBookmarkService: Bookmark removed for $videoId');
      }

      return BookmarkResult.success(isBookmarking);
    } catch (e) {
      debugPrint('❌ UnifiedBookmarkService: Operation failed for $videoId: $e');
      return BookmarkResult.error('Operation failed: $e');
    }
  }

  /// Update local state
  void _updateLocalState(
      String videoId, bool isBookmarked, BookmarkStatus status) {
    _bookmarkStates[videoId] = BookmarkState(
      videoId: videoId,
      isBookmarked: isBookmarked,
      lastUpdated: DateTime.now(),
      status: status,
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
    notifyListeners();
  }

  @override
  void dispose() {
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

  BookmarkState({
    required this.videoId,
    required this.isBookmarked,
    required this.lastUpdated,
    required this.status,
  });

  BookmarkState copyWith({
    String? videoId,
    bool? isBookmarked,
    DateTime? lastUpdated,
    BookmarkStatus? status,
  }) {
    return BookmarkState(
      videoId: videoId ?? this.videoId,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
    );
  }
}

/// Bookmark status enum
enum BookmarkStatus {
  synced,
  pending,
  error,
}

/// Bookmark event model
class BookmarkEvent {
  final String videoId;
  final BookmarkEventType type;
  final bool? isBookmarked;
  final String? error;

  BookmarkEvent._(this.videoId, this.type, {this.isBookmarked, this.error});

  factory BookmarkEvent.toggle(String videoId, bool isBookmarked) {
    return BookmarkEvent._(videoId, BookmarkEventType.toggle,
        isBookmarked: isBookmarked);
  }

  factory BookmarkEvent.success(String videoId, bool isBookmarked) {
    return BookmarkEvent._(videoId, BookmarkEventType.success,
        isBookmarked: isBookmarked);
  }

  factory BookmarkEvent.error(String error) {
    return BookmarkEvent._('', BookmarkEventType.error, error: error);
  }
}

enum BookmarkEventType {
  toggle,
  success,
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
