import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/bookmark_event.dart';
import '../models/calendar_event.dart';

/// Enhanced BookmarkService with notification scheduling and FCM integration
/// Implements the complete bookmark → notify → manage flow
class EnhancedBookmarkService {
  static final EnhancedBookmarkService _instance = EnhancedBookmarkService._internal();
  factory EnhancedBookmarkService() => _instance;
  EnhancedBookmarkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Local state management
  final Set<String> _bookmarkedEventIds = <String>{};
  final Map<String, BookmarkEvent> _bookmarkedEvents = <String, BookmarkEvent>{};
  
  // Stream controllers for reactive updates
  final StreamController<Set<String>> _bookmarksController = 
      StreamController<Set<String>>.broadcast();
  final StreamController<List<BookmarkEvent>> _bookmarkedEventsController = 
      StreamController<List<BookmarkEvent>>.broadcast();

  // State
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  Set<String> get bookmarkedEventIds => Set.from(_bookmarkedEventIds);
  List<BookmarkEvent> get bookmarkedEvents => _bookmarkedEvents.values.toList();
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Streams
  Stream<Set<String>> get bookmarksStream => _bookmarksController.stream;
  Stream<List<BookmarkEvent>> get bookmarkedEventsStream => _bookmarkedEventsController.stream;

  /// Initialize the service and load bookmarks
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    _notifyBookmarksChanged();
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _registerFCMToken();
        await _loadBookmarks(currentUser.uid);
      }
      
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error initializing: $e');
      }
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  /// Register FCM token for push notifications
  Future<void> _registerFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('deviceTokens')
          .doc(token)
          .set({
        'createdAt': FieldValue.serverTimestamp(),
        'platform': _getPlatform(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ EnhancedBookmarkService: FCM token registered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Failed to register FCM token: $e');
      }
    }
  }

  String _getPlatform() {
    // This would be determined by the platform
    return 'android'; // or 'ios' or 'web'
  }

  /// Load bookmarks from Firebase
  Future<void> _loadBookmarks(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .orderBy('notifyAt', descending: false)
          .get();

      _bookmarkedEventIds.clear();
      _bookmarkedEvents.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final bookmark = BookmarkEvent.fromMap(data);
        
        _bookmarkedEventIds.add(bookmark.eventId);
        _bookmarkedEvents[bookmark.eventId] = bookmark;
      }

      _notifyBookmarksChanged();
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error loading bookmarks: $e');
      }
    }
  }

  /// Bookmark an event with notification scheduling
  Future<bool> bookmarkEvent({
    required String eventId,
    required String creatorId,
    required String title,
    required DateTime startAt,
    DateTime? notifyAt,
    String source = 'streamerCardBackView',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: No authenticated user');
      }
      return false;
    }

    if (_bookmarkedEventIds.contains(eventId)) {
      if (kDebugMode) {
        print('✅ EnhancedBookmarkService: Event already bookmarked: $eventId');
      }
      return true; // Already bookmarked
    }

    _isLoading = true;
    _notifyBookmarksChanged();

    try {
      final now = DateTime.now();
      final notificationTime = notifyAt ?? startAt;

      final bookmarkData = {
        'eventId': eventId,
        'creatorId': creatorId,
        'title': title,
        'startAt': Timestamp.fromDate(startAt),
        'notifyAt': Timestamp.fromDate(notificationTime),
        'notify': true,
        'createdAt': FieldValue.serverTimestamp(),
        'source': source,
      };

      if (kDebugMode) {
        print('📝 EnhancedBookmarkService: Saving bookmark for event: $eventId');
        print('📝 EnhancedBookmarkService: User ID: ${currentUser.uid}');
        print('📝 EnhancedBookmarkService: Creator ID: $creatorId');
      }

      // Use merge to avoid overwriting existing data
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(eventId)
          .set(bookmarkData, SetOptions(merge: true));

      // Update local state
      final bookmark = BookmarkEvent(
        eventId: eventId,
        creatorId: creatorId,
        title: title,
        startAt: startAt,
        notifyAt: notificationTime,
        notify: true,
        createdAt: now,
        source: source,
      );

      _bookmarkedEventIds.add(eventId);
      _bookmarkedEvents[eventId] = bookmark;

      _notifyBookmarksChanged();
      
      if (kDebugMode) {
        print('✅ EnhancedBookmarkService: Successfully bookmarked event: $title');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error bookmarking event: $e');
        print('❌ EnhancedBookmarkService: Error type: ${e.runtimeType}');
        if (e is FirebaseException) {
          print('❌ EnhancedBookmarkService: Firebase error code: ${e.code}');
          print('❌ EnhancedBookmarkService: Firebase error message: ${e.message}');
        }
      }
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  /// Delete a bookmark and cancel notifications
  Future<bool> deleteBookmark({
    required String eventId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    if (!_bookmarkedEventIds.contains(eventId)) {
      return true; // Not bookmarked
    }

    _isLoading = true;
    _notifyBookmarksChanged();

    try {
      final docRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(eventId);

      // Read scheduledTaskId before deleting (for future backend integration)
      // final snap = await docRef.get();
      // final scheduledTaskId = snap.data()?['scheduledTaskId'] as String?;

      await docRef.delete();

      // Update local state
      _bookmarkedEventIds.remove(eventId);
      _bookmarkedEvents.remove(eventId);

      _notifyBookmarksChanged();
      
      if (kDebugMode) {
        print('✅ EnhancedBookmarkService: Deleted bookmark: $eventId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error deleting bookmark: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  /// Toggle notification for a bookmarked event
  Future<bool> toggleNotification({
    required String eventId,
    required bool notify,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    _isLoading = true;
    _notifyBookmarksChanged();

    try {
      final docRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(eventId);

      await docRef.update({
        'notify': notify,
      });

      // Update local state
      if (_bookmarkedEvents.containsKey(eventId)) {
        _bookmarkedEvents[eventId] = _bookmarkedEvents[eventId]!.copyWith(notify: notify);
      }

      _notifyBookmarksChanged();
      
      if (kDebugMode) {
        print('✅ EnhancedBookmarkService: Toggled notification for $eventId: $notify');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error toggling notification: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  /// Toggle bookmark status for an event
  Future<bool> toggleEventBookmark({
    required CalendarEvent event,
    required String creatorId,
  }) async {
    if (_bookmarkedEventIds.contains(event.id)) {
      return await deleteBookmark(eventId: event.id);
    } else {
      return await bookmarkEvent(
        eventId: event.id,
        creatorId: creatorId,
        title: event.title,
        startAt: event.date,
      );
    }
  }

  /// Check if an event is bookmarked
  bool isEventBookmarked(String eventId) {
    return _bookmarkedEventIds.contains(eventId);
  }

  /// Get bookmarks stream ordered by notifyAt
  Stream<List<BookmarkEvent>> getBookmarksStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .orderBy('notifyAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BookmarkEvent.fromMap(doc.data()))
          .toList();
    });
  }

  /// Get bookmarks grouped by status
  Map<EventStatus, List<BookmarkEvent>> getBookmarksByStatus() {
    final Map<EventStatus, List<BookmarkEvent>> grouped = {
      EventStatus.upcoming: [],
      EventStatus.live: [],
      EventStatus.past: [],
    };

    for (final bookmark in _bookmarkedEvents.values) {
      grouped[bookmark.status]!.add(bookmark);
    }

    return grouped;
  }

  /// Get bookmarks as a list
  Future<List<BookmarkEvent>> getBookmarks() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .orderBy('notifyAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => BookmarkEvent.fromMap(doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error getting bookmarks: $e');
      }
      return [];
    }
  }

  /// Get bookmarked event IDs as a set
  Future<Set<String>> fetchBookmarkedEventIds() async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.map((bookmark) => bookmark.eventId).toSet();
    } catch (e) {
      if (kDebugMode) {
        print('❌ EnhancedBookmarkService: Error fetching bookmarked event IDs: $e');
      }
      return <String>{};
    }
  }

  /// Refresh bookmarks from Firebase
  Future<void> refreshBookmarks() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _loadBookmarks(currentUser.uid);
    }
  }

  /// Notify listeners of changes
  void _notifyBookmarksChanged() {
    _bookmarksController.add(Set.from(_bookmarkedEventIds));
    _bookmarkedEventsController.add(_bookmarkedEvents.values.toList());
  }

  /// Dispose resources
  void dispose() {
    _bookmarksController.close();
    _bookmarkedEventsController.close();
  }

  // Legacy methods for backward compatibility
  Future<bool> addEventBookmark({
    required CalendarEvent event,
    required String ownerId,
    required String ownerDisplayName,
  }) async {
    return await bookmarkEvent(
      eventId: event.id,
      creatorId: ownerId,
      title: event.title,
      startAt: event.date,
    );
  }

  Future<bool> removeEventBookmark({
    required String eventId,
    required String ownerId,
  }) async {
    return await deleteBookmark(eventId: eventId);
  }
}
