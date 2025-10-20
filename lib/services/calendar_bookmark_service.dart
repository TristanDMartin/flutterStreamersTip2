import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';

/// Unified Calendar Event Bookmark Service
/// Syncs instantly between mobile app and website via Firestore real-time listeners
class CalendarBookmarkService {
  static final CalendarBookmarkService _instance =
      CalendarBookmarkService._internal();
  factory CalendarBookmarkService() => _instance;
  CalendarBookmarkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local state
  final Set<String> _bookmarkedEventIds = <String>{};
  final Map<String, BookmarkedCalendarEvent> _bookmarkedEvents = {};

  // Stream controllers
  final StreamController<Set<String>> _bookmarksController =
      StreamController<Set<String>>.broadcast();
  final StreamController<List<BookmarkedCalendarEvent>> _eventsController =
      StreamController<List<BookmarkedCalendarEvent>>.broadcast();

  // Real-time listener
  StreamSubscription<QuerySnapshot>? _bookmarksSubscription;

  // State
  bool _isInitialized = false;

  // Getters
  Set<String> get bookmarkedEventIds => Set.from(_bookmarkedEventIds);
  List<BookmarkedCalendarEvent> get bookmarkedEvents =>
      _bookmarkedEvents.values.toList();
  Stream<Set<String>> get bookmarksStream => _bookmarksController.stream;
  Stream<List<BookmarkedCalendarEvent>> get eventsStream =>
      _eventsController.stream;
  bool get isInitialized => _isInitialized;

  /// Initialize with real-time sync
  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      debugPrint('⚠️ CalendarBookmarkService: Already initialized');
      return;
    }

    try {
      debugPrint('🔄 CalendarBookmarkService: Initializing for user: $userId');

      // Set up real-time listener
      _setupRealtimeListener(userId);

      _isInitialized = true;
      debugPrint('✅ CalendarBookmarkService: Initialized with real-time sync');
    } catch (e) {
      debugPrint('❌ CalendarBookmarkService: Initialization error: $e');
    }
  }

  /// Set up real-time Firestore listener
  void _setupRealtimeListener(String userId) {
    _bookmarksSubscription?.cancel();

    _bookmarksSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('calendarBookmarks')
        .orderBy('bookmarkedAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        debugPrint(
            '📡 CalendarBookmarkService: Received ${snapshot.docs.length} bookmarks');

        _bookmarkedEventIds.clear();
        _bookmarkedEvents.clear();

        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final eventId = data['eventId'] as String;

            _bookmarkedEventIds.add(eventId);
            _bookmarkedEvents[eventId] =
                BookmarkedCalendarEvent.fromFirestore(data);
          } catch (e) {
            debugPrint('❌ Error parsing bookmark: $e');
          }
        }

        // Notify listeners
        _bookmarksController.add(Set.from(_bookmarkedEventIds));
        _eventsController.add(_bookmarkedEvents.values.toList());

        debugPrint('✅ Bookmarked events: ${_bookmarkedEventIds.length}');
      },
      onError: (error) {
        debugPrint('❌ CalendarBookmarkService: Listener error: $error');
      },
    );
  }

  /// Check if event is bookmarked
  bool isBookmarked(String eventId) {
    return _bookmarkedEventIds.contains(eventId);
  }

  /// Get bookmarked event details
  BookmarkedCalendarEvent? getBookmarkedEvent(String eventId) {
    return _bookmarkedEvents[eventId];
  }

  /// Toggle bookmark with instant sync
  Future<bool> toggleBookmark(
    CalendarEvent event,
    String eventOwnerId, {
    String? eventOwnerName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No authenticated user');
      return false;
    }

    final eventId = event.id;
    final isCurrentlyBookmarked = isBookmarked(eventId);
    final newBookmarkState = !isCurrentlyBookmarked;

    debugPrint(
        '🔖 Toggling bookmark for event: $eventId (${isCurrentlyBookmarked ? "unbookmark" : "bookmark"})');

    try {
      // Optimistic UI update
      if (newBookmarkState) {
        _bookmarkedEventIds.add(eventId);
        _bookmarkedEvents[eventId] = BookmarkedCalendarEvent(
          eventId: eventId,
          userId: eventOwnerId,
          userName: eventOwnerName ?? 'Unknown',
          title: event.title,
          description: event.description,
          date: event.date,
          bookmarkedAt: DateTime.now(),
          source: 'mobile',
        );
      } else {
        _bookmarkedEventIds.remove(eventId);
        _bookmarkedEvents.remove(eventId);
      }

      // Notify immediately (optimistic)
      _bookmarksController.add(Set.from(_bookmarkedEventIds));
      _eventsController.add(_bookmarkedEvents.values.toList());

      // Update Firestore
      final bookmarkRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('calendarBookmarks')
          .doc(eventId);

      if (newBookmarkState) {
        // Add bookmark
        await bookmarkRef.set({
          'eventId': eventId,
          'userId': eventOwnerId,
          'userName': eventOwnerName ?? 'Unknown',
          'title': event.title,
          'description': event.description,
          'date': Timestamp.fromDate(event.date),
          'bookmarkedAt': FieldValue.serverTimestamp(),
          'source': 'mobile',
        });
        debugPrint('✅ Bookmark added to Firestore');
      } else {
        // Remove bookmark
        await bookmarkRef.delete();
        debugPrint('✅ Bookmark removed from Firestore');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');

      // Revert optimistic update
      if (newBookmarkState) {
        _bookmarkedEventIds.remove(eventId);
        _bookmarkedEvents.remove(eventId);
      } else {
        _bookmarkedEventIds.add(eventId);
      }

      _bookmarksController.add(Set.from(_bookmarkedEventIds));
      _eventsController.add(_bookmarkedEvents.values.toList());

      return false;
    }
  }

  /// Get all bookmarked events (one-time fetch)
  Future<List<BookmarkedCalendarEvent>> fetchBookmarkedEvents() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('calendarBookmarks')
          .orderBy('bookmarkedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookmarkedCalendarEvent.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching bookmarked events: $e');
      return [];
    }
  }

  /// Clear all bookmarks (useful for logout)
  Future<void> clearBookmarks() async {
    _bookmarkedEventIds.clear();
    _bookmarkedEvents.clear();
    _bookmarksController.add(Set.from(_bookmarkedEventIds));
    _eventsController.add([]);
    _isInitialized = false;
  }

  /// Dispose resources
  void dispose() {
    _bookmarksSubscription?.cancel();
    _bookmarksController.close();
    _eventsController.close();
    _isInitialized = false;
  }
}

/// Model for bookmarked calendar event
class BookmarkedCalendarEvent {
  final String eventId;
  final String userId; // Event owner ID
  final String userName; // Event owner name
  final String title;
  final String description;
  final DateTime date;
  final DateTime bookmarkedAt;
  final String source; // "mobile" or "website"

  BookmarkedCalendarEvent({
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.date,
    required this.bookmarkedAt,
    required this.source,
  });

  factory BookmarkedCalendarEvent.fromFirestore(Map<String, dynamic> data) {
    return BookmarkedCalendarEvent(
      eventId: data['eventId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String? ?? 'Unknown',
      title: data['title'] as String,
      description: data['description'] as String,
      date: (data['date'] as Timestamp).toDate(),
      bookmarkedAt:
          (data['bookmarkedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'bookmarkedAt': Timestamp.fromDate(bookmarkedAt),
      'source': source,
    };
  }

  CalendarEvent toCalendarEvent() {
    return CalendarEvent(
      id: eventId,
      title: title,
      description: description,
      date: date,
    );
  }
}
