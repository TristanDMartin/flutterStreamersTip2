import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../models/bookmark_event.dart';
import '../../../models/calendar_event.dart';

/// Calendar / streamer-schedule event bookmarks at `users/{uid}/bookmarks/{eventId}`.
///
/// Composed by [UnifiedBookmarkService] — not for video favorites.
class CalendarEventBookmarkCoordinator {
  CalendarEventBookmarkCoordinator({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;

  final Set<String> _bookmarkedEventIds = <String>{};
  final Map<String, BookmarkEvent> _bookmarkedEvents =
      <String, BookmarkEvent>{};
  final StreamController<Set<String>> _bookmarksController =
      StreamController<Set<String>>.broadcast();
  final StreamController<List<BookmarkEvent>> _bookmarkedEventsController =
      StreamController<List<BookmarkEvent>>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _bookmarksSubscription;

  String? _activeUserId;
  bool _isLoading = false;
  bool _isInitialized = false;

  Set<String> get bookmarkedEventIds => Set<String>.from(_bookmarkedEventIds);
  List<BookmarkEvent> get bookmarkedEvents => _bookmarkedEvents.values.toList();
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  Stream<Set<String>> get bookmarksStream => _bookmarksController.stream;
  Stream<List<BookmarkEvent>> get bookmarkedEventsStream =>
      _bookmarkedEventsController.stream;

  Future<void> initialize() async {
    final User? currentUser = _auth.currentUser;
    final String? userId = currentUser?.uid;
    if (_isInitialized && _activeUserId == userId) {
      return;
    }
    if (_activeUserId != userId) {
      await _bookmarksSubscription?.cancel();
      _bookmarksSubscription = null;
      _bookmarkedEventIds.clear();
      _bookmarkedEvents.clear();
      _isInitialized = false;
    }
    _activeUserId = userId;
    _isLoading = true;
    _notifyBookmarksChanged();
    try {
      if (currentUser != null) {
        await _registerFcmToken(currentUser.uid);
        await _loadBookmarks(currentUser.uid);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: init failed: $e');
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  Future<void> _registerFcmToken(String userId) async {
    try {
      final String? token = await _messaging.getToken();
      if (token == null) {
        return;
      }
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deviceTokens')
          .doc(token)
          .set(<String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'platform': _platformLabel(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: FCM token failed: $e');
    }
  }

  static String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unknown';
    }
  }

  Future<void> _loadBookmarks(String userId) async {
    try {
      _bookmarksSubscription?.cancel();
      _bookmarksSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .orderBy('notifyAt', descending: false)
          .snapshots()
          .listen(
        (QuerySnapshot<Map<String, dynamic>> snapshot) async {
          _bookmarkedEventIds.clear();
          _bookmarkedEvents.clear();
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            try {
              final Map<String, dynamic> data =
                  Map<String, dynamic>.from(doc.data());
              if (data['creatorName'] == null && data['creatorId'] != null) {
                try {
                  final String creatorId = data['creatorId'].toString();
                  final DocumentSnapshot<Map<String, dynamic>> creatorDoc =
                      await _firestore
                          .collection('users')
                          .doc(creatorId)
                          .get();
                  if (creatorDoc.exists) {
                    final Map<String, dynamic>? creatorData = creatorDoc.data();
                    data['creatorName'] =
                        creatorData?['displayName'] as String? ??
                            creatorData?['username'] as String? ??
                            creatorId;
                    await doc.reference.update(
                      <String, dynamic>{'creatorName': data['creatorName']},
                    );
                  }
                } catch (e) {
                  debugPrint('⚠️ CalendarEventBookmarkCoordinator: creator: $e');
                  data['creatorName'] = data['creatorId']?.toString();
                }
              }
              final BookmarkEvent? bookmark = BookmarkEvent.tryParse(data);
              if (bookmark == null) {
                continue;
              }
              _bookmarkedEventIds.add(bookmark.eventId);
              _bookmarkedEvents[bookmark.eventId] = bookmark;
            } catch (e) {
              debugPrint('❌ CalendarEventBookmarkCoordinator: parse: $e');
            }
          }
          _notifyBookmarksChanged();
        },
        onError: (Object error) {
          debugPrint('❌ CalendarEventBookmarkCoordinator: listener: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: listener setup: $e');
    }
  }

  Future<bool> bookmarkEvent({
    required String eventId,
    required String creatorId,
    String? creatorName,
    required String title,
    required DateTime startAt,
    DateTime? notifyAt,
    String source = 'streamerCardBackView',
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }
    if (_bookmarkedEventIds.contains(eventId)) {
      return true;
    }
    _isLoading = true;
    _notifyBookmarksChanged();
    try {
      final DateTime now = DateTime.now();
      final DateTime notificationTime = notifyAt ?? startAt;
      String finalCreatorName = creatorName ?? creatorId;
      if (creatorName == null) {
        try {
          final DocumentSnapshot<Map<String, dynamic>> creatorDoc =
              await _firestore.collection('users').doc(creatorId).get();
          if (creatorDoc.exists) {
            final Map<String, dynamic>? creatorData = creatorDoc.data();
            finalCreatorName = creatorData?['displayName'] as String? ??
                creatorData?['username'] as String? ??
                creatorId;
          }
        } catch (e) {
          debugPrint('⚠️ CalendarEventBookmarkCoordinator: creator name: $e');
        }
      }
      final Map<String, dynamic> bookmarkData = <String, dynamic>{
        'eventId': eventId,
        'creatorId': creatorId,
        'creatorName': finalCreatorName,
        'title': title,
        'startAt': Timestamp.fromDate(startAt),
        'notifyAt': Timestamp.fromDate(notificationTime),
        'notify': true,
        'createdAt': FieldValue.serverTimestamp(),
        'source': source,
      };
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(eventId)
          .set(bookmarkData, SetOptions(merge: true));
      final BookmarkEvent bookmark = BookmarkEvent(
        eventId: eventId,
        creatorId: creatorId,
        creatorName: finalCreatorName,
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
      return true;
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: bookmark failed: $e');
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  Future<bool> deleteBookmark({required String eventId}) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }
    if (!_bookmarkedEventIds.contains(eventId)) {
      return true;
    }
    _isLoading = true;
    _notifyBookmarksChanged();
    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(eventId)
          .delete();
      _bookmarkedEventIds.remove(eventId);
      _bookmarkedEvents.remove(eventId);
      _notifyBookmarksChanged();
      return true;
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: delete failed: $e');
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  Future<bool> toggleNotification({
    required String eventId,
    required bool notify,
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }
    _isLoading = true;
    _notifyBookmarksChanged();
    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(eventId)
          .update(<String, dynamic>{'notify': notify});
      if (_bookmarkedEvents.containsKey(eventId)) {
        _bookmarkedEvents[eventId] =
            _bookmarkedEvents[eventId]!.copyWith(notify: notify);
      }
      _notifyBookmarksChanged();
      return true;
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: notify toggle: $e');
      return false;
    } finally {
      _isLoading = false;
      _notifyBookmarksChanged();
    }
  }

  Future<bool> toggleEventBookmark({
    required CalendarEvent event,
    required String creatorId,
  }) async {
    if (_bookmarkedEventIds.contains(event.id)) {
      return deleteBookmark(eventId: event.id);
    }
    return bookmarkEvent(
      eventId: event.id,
      creatorId: creatorId,
      title: event.title,
      startAt: event.date,
    );
  }

  bool isEventBookmarked(String eventId) {
    return _bookmarkedEventIds.contains(eventId);
  }

  Stream<List<BookmarkEvent>> getBookmarksStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<List<BookmarkEvent>>.value(<BookmarkEvent>[]);
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .orderBy('notifyAt', descending: false)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    BookmarkEvent.tryParse(doc.data()),
              )
              .whereType<BookmarkEvent>()
              .toList(growable: false),
        );
  }

  Future<List<BookmarkEvent>> getBookmarks() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return <BookmarkEvent>[];
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .orderBy('notifyAt', descending: false)
          .get();
      return snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                BookmarkEvent.tryParse(doc.data()),
          )
          .whereType<BookmarkEvent>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: getBookmarks: $e');
      return <BookmarkEvent>[];
    }
  }

  Future<Set<String>> fetchBookmarkedEventIds() async {
    try {
      final List<BookmarkEvent> bookmarks = await getBookmarks();
      return bookmarks.map((BookmarkEvent b) => b.eventId).toSet();
    } catch (e) {
      debugPrint('❌ CalendarEventBookmarkCoordinator: fetch ids: $e');
      return <String>{};
    }
  }

  Future<void> refreshBookmarks() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _loadBookmarks(currentUser.uid);
    }
  }

  void _notifyBookmarksChanged() {
    _bookmarksController.add(Set<String>.from(_bookmarkedEventIds));
    _bookmarkedEventsController.add(_bookmarkedEvents.values.toList());
  }

  void reset() {
    _bookmarksSubscription?.cancel();
    _bookmarksSubscription = null;
    _bookmarkedEventIds.clear();
    _bookmarkedEvents.clear();
    _activeUserId = null;
    _isInitialized = false;
    _isLoading = false;
  }

  void dispose() {
    _bookmarksSubscription?.cancel();
    _bookmarksSubscription = null;
    if (!_bookmarksController.isClosed) {
      _bookmarksController.close();
    }
    if (!_bookmarkedEventsController.isClosed) {
      _bookmarkedEventsController.close();
    }
  }
}
