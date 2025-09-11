import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';

/// Service for managing calendar event bookmarks
/// Handles both local state and Firebase persistence
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local state management
  final Set<String> _bookmarkedEventIds = <String>{};
  final Map<String, BookmarkedEvent> _bookmarkedEvents = <String, BookmarkedEvent>{};
  
  // Stream controllers for reactive updates
  final StreamController<Set<String>> _bookmarksController = 
      StreamController<Set<String>>.broadcast();
  final StreamController<List<BookmarkedEvent>> _bookmarkedEventsController = 
      StreamController<List<BookmarkedEvent>>.broadcast();

  // State
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  Set<String> get bookmarkedEventIds => Set.from(_bookmarkedEventIds);
  List<BookmarkedEvent> get bookmarkedEvents => _bookmarkedEvents.values.toList();
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Streams
  Stream<Set<String>> get bookmarksStream => _bookmarksController.stream;
  Stream<List<BookmarkedEvent>> get bookmarkedEventsStream => _bookmarkedEventsController.stream;

  /// Initialize the service and load bookmarks
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    _notifyBookmarksChanged();
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _loadBookmarks(currentUser.uid);
      }
      
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
    // print('❌ BookmarkService: Error initializing: $e');
      }
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  /// Load bookmarks from Firebase
  Future<void> _loadBookmarks(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarkedEvents')
          .orderBy('bookmarkedAt', descending: true)
          .get();

      _bookmarkedEventIds.clear();
      _bookmarkedEvents.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final eventId = data['eventId'] as String?;
        final ownerId = data['ownerId'] as String?;
        
        if (eventId != null && ownerId != null) {
          _bookmarkedEventIds.add(eventId);
          _bookmarkedEvents[eventId] = BookmarkedEvent(
            id: doc.id,
            eventId: eventId,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            date: (data['date'] as Timestamp).toDate(),
            ownerId: ownerId,
            ownerDisplayName: data['ownerDisplayName'] ?? '',
            bookmarkedAt: (data['bookmarkedAt'] as Timestamp).toDate(),
          );
        }
      }

      _notifyBookmarksChanged();
    } catch (e) {
      if (kDebugMode) {
    // print('❌ BookmarkService: Error loading bookmarks: $e');
      }
    }
  }

  /// Add a calendar event to bookmarks
  Future<bool> addEventBookmark({
    required CalendarEvent event,
    required String ownerId,
    required String ownerDisplayName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    if (_bookmarkedEventIds.contains(event.id)) {
      return true; // Already bookmarked
    }

    _isLoading = true;
    _notifyBookmarksChanged();

    try {
      // Add to Firebase
      final bookmarkData = {
        'eventId': event.id,
        'title': event.title,
        'description': event.description,
        'date': Timestamp.fromDate(event.date),
        'ownerId': ownerId,
        'ownerDisplayName': ownerDisplayName,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarkedEvents')
          .add(bookmarkData);

      // Update local state
      _bookmarkedEventIds.add(event.id);
      _bookmarkedEvents[event.id] = BookmarkedEvent(
        id: '', // Will be updated on next load
        eventId: event.id,
        title: event.title,
        description: event.description,
        date: event.date,
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
        bookmarkedAt: DateTime.now(),
      );

      _notifyBookmarksChanged();
      
      if (kDebugMode) {
    // print('✅ BookmarkService: Bookmarked event: ${event.title}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
    // print('❌ BookmarkService: Error adding bookmark: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  /// Remove a calendar event from bookmarks
  Future<bool> removeEventBookmark({
    required String eventId,
    required String ownerId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    if (!_bookmarkedEventIds.contains(eventId)) {
      return true; // Not bookmarked
    }

    _isLoading = true;
    _notifyBookmarksChanged();

    try {
      // Find and delete from Firebase
      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarkedEvents')
          .where('eventId', isEqualTo: eventId)
          .where('ownerId', isEqualTo: ownerId)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      // Update local state
      _bookmarkedEventIds.remove(eventId);
      _bookmarkedEvents.remove(eventId);

      _notifyBookmarksChanged();
      
      if (kDebugMode) {
    // print('✅ BookmarkService: Unbookmarked event: $eventId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
    // print('❌ BookmarkService: Error removing bookmark: $e');
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
    required String ownerId,
    required String ownerDisplayName,
  }) async {
    if (_bookmarkedEventIds.contains(event.id)) {
      return await removeEventBookmark(eventId: event.id, ownerId: ownerId);
    } else {
      return await addEventBookmark(
        event: event,
        ownerId: ownerId,
        ownerDisplayName: ownerDisplayName,
      );
    }
  }

  /// Check if an event is bookmarked
  bool isEventBookmarked(String eventId) {
    return _bookmarkedEventIds.contains(eventId);
  }

  /// Get bookmarked events for a specific owner
  List<BookmarkedEvent> getBookmarkedEventsForOwner(String ownerId) {
    return _bookmarkedEvents.values
        .where((event) => event.ownerId == ownerId)
        .toList();
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
}

/// Model for bookmarked events
class BookmarkedEvent {
  final String id;
  final String eventId;
  final String title;
  final String description;
  final DateTime date;
  final String ownerId;
  final String ownerDisplayName;
  final DateTime bookmarkedAt;

  const BookmarkedEvent({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    required this.date,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.bookmarkedAt,
  });

  factory BookmarkedEvent.fromMap(Map<String, dynamic> data) {
    return BookmarkedEvent(
      id: data['id'] ?? '',
      eventId: data['eventId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      ownerId: data['ownerId'] ?? '',
      ownerDisplayName: data['ownerDisplayName'] ?? '',
      bookmarkedAt: (data['bookmarkedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'bookmarkedAt': Timestamp.fromDate(bookmarkedAt),
    };
  }
}
