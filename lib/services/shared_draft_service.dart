import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/connection.dart';
import '../models/shared_draft.dart';
import 'draft_sharing_service.dart';

class SharedDraftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DraftSharingService _draftSharingService = DraftSharingService();

  final StreamController<List<SharedDraft>> _sharedDraftsController =
      StreamController<List<SharedDraft>>.broadcast();
  final StreamController<List<Connection>> _connectionsController =
      StreamController<List<Connection>>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _receivedDraftsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _sentDraftsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _connectionsSubscription;

  List<SharedDraft> _sharedDrafts = [];
  List<Connection> _connections = [];

  Stream<List<SharedDraft>> get sharedDraftsStream =>
      _sharedDraftsController.stream;
  Stream<List<Connection>> get connectionsStream =>
      _connectionsController.stream;

  List<SharedDraft> get sharedDrafts => List.unmodifiable(_sharedDrafts);
  List<Connection> get connections => List.unmodifiable(_connections);

  Future<void> initialize() async {
    await _bindToUser(_auth.currentUser);
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      _bindToUser(user);
    });
  }

  void dispose() {
    _authSubscription?.cancel();
    _receivedDraftsSubscription?.cancel();
    _sentDraftsSubscription?.cancel();
    _connectionsSubscription?.cancel();
    _sharedDraftsController.close();
    _connectionsController.close();
  }

  Future<void> _bindToUser(User? user) async {
    await _receivedDraftsSubscription?.cancel();
    await _sentDraftsSubscription?.cancel();
    await _connectionsSubscription?.cancel();
    _receivedDraftsSubscription = null;
    _sentDraftsSubscription = null;
    _connectionsSubscription = null;

    if (user == null) {
      _sharedDrafts = [];
      _connections = [];
      _notifyDataChanged();
      return;
    }

    await Future.wait([
      _refreshSharedDrafts(),
      _refreshConnections(),
    ]);

    _receivedDraftsSubscription = _firestore
        .collection('shared_drafts')
        .where('recipients', arrayContains: user.uid)
        .where('status', isEqualTo: 'shared')
        .snapshots()
        .listen(
      (_) => _refreshSharedDrafts(),
      onError: (error) => debugPrint(
        '❌ SharedDraftService: received drafts listener error: $error',
      ),
    );

    _sentDraftsSubscription = _firestore
        .collection('shared_drafts')
        .where('sharerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'shared')
        .snapshots()
        .listen(
      (_) => _refreshSharedDrafts(),
      onError: (error) => debugPrint(
        '❌ SharedDraftService: sent drafts listener error: $error',
      ),
    );

    _connectionsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('connections')
        .snapshots()
        .listen(
      (snapshot) {
        _connections = snapshot.docs
            .map((doc) => _mapConnection(doc.id, doc.data()))
            .toList();
        _connectionsController.add(_connections);
      },
      onError: (error) => debugPrint(
        '❌ SharedDraftService: connections listener error: $error',
      ),
    );
  }

  Future<void> _refreshSharedDrafts() async {
    final user = _auth.currentUser;
    if (user == null) {
      _sharedDrafts = [];
      _sharedDraftsController.add(_sharedDrafts);
      return;
    }

    try {
      final receivedQuery = await _firestore
          .collection('shared_drafts')
          .where('recipients', arrayContains: user.uid)
          .where('status', isEqualTo: 'shared')
          .orderBy('createdAt', descending: true)
          .get();

      final sentQuery = await _firestore
          .collection('shared_drafts')
          .where('sharerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'shared')
          .orderBy('createdAt', descending: true)
          .get();

      final drafts = <SharedDraft>[];
      final seenIds = <String>{};

      for (final doc in receivedQuery.docs) {
        final mapped = _mapSharedDraft(
          id: doc.id,
          data: doc.data(),
          currentUserId: user.uid,
          receiverId: user.uid,
        );
        if (seenIds.add(mapped.id)) {
          drafts.add(mapped);
        }
      }

      for (final doc in sentQuery.docs) {
        final data = doc.data();
        final recipients =
            List<String>.from(data['recipients'] as List<dynamic>? ?? const []);
        for (final recipientId in recipients) {
          final mapped = _mapSharedDraft(
            id: '${doc.id}_$recipientId',
            data: data,
            currentUserId: user.uid,
            receiverId: recipientId,
          );
          if (seenIds.add(mapped.id)) {
            drafts.add(mapped);
          }
        }
      }

      drafts.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      _sharedDrafts = drafts;
      _sharedDraftsController.add(_sharedDrafts);
    } catch (e) {
      debugPrint('❌ SharedDraftService: error refreshing shared drafts: $e');
    }
  }

  Future<void> _refreshConnections() async {
    final user = _auth.currentUser;
    if (user == null) {
      _connections = [];
      _connectionsController.add(_connections);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('connections')
          .get();
      _connections = snapshot.docs
          .map((doc) => _mapConnection(doc.id, doc.data()))
          .toList();
      _connectionsController.add(_connections);
    } catch (e) {
      debugPrint('❌ SharedDraftService: error refreshing connections: $e');
    }
  }

  void _notifyDataChanged() {
    _sharedDraftsController.add(_sharedDrafts);
    _connectionsController.add(_connections);
  }

  Future<bool> shareDraft({
    required String draftId,
    required String receiverId,
    required String draftTitle,
    required String draftThumbnailUrl,
    required int draftDuration,
    String? message,
  }) {
    return _draftSharingService.shareDraftWithConnections(
      draftId: draftId,
      connectionIds: [receiverId],
      message: message,
    );
  }

  Future<void> markAsViewed(String sharedDraftId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('shared_drafts').doc(sharedDraftId).update({
        'viewedBy': FieldValue.arrayUnion([user.uid]),
        'viewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ SharedDraftService: error marking draft viewed: $e');
    }
  }

  Future<void> declineDraft(String sharedDraftId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('shared_drafts').doc(sharedDraftId).update({
        'declinedBy': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ SharedDraftService: error declining draft: $e');
    }
  }

  Future<void> deleteSharedDraft(String sharedDraftId) async {
    try {
      await _firestore.collection('shared_drafts').doc(sharedDraftId).delete();
    } catch (e) {
      debugPrint('❌ SharedDraftService: error deleting draft: $e');
    }
  }

  List<SharedDraft> getSharedDraftsForUser(String userId) {
    return _sharedDrafts.where((draft) => draft.receiverId == userId).toList();
  }

  int getUnreadCount() {
    return _sharedDrafts
        .where((draft) => draft.status != SharedDraftStatus.viewed)
        .length;
  }

  Future<bool> addConnection({
    required String userId,
    required String name,
    required String avatar,
    required String username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('connections')
          .doc();
      await ref.set({
        'id': ref.id,
        'displayName': name,
        'username': username,
        'avatarUrl': avatar,
        'isOnline': false,
        'lastSeen': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ SharedDraftService: error adding connection: $e');
      return false;
    }
  }

  Future<void> removeConnection(String connectionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('connections')
          .doc(connectionId)
          .delete();
    } catch (e) {
      debugPrint('❌ SharedDraftService: error removing connection: $e');
    }
  }

  SharedDraft _mapSharedDraft({
    required String id,
    required Map<String, dynamic> data,
    required String currentUserId,
    required String receiverId,
  }) {
    final senderId = data['sharerId'] as String? ?? data['senderId'] as String? ?? '';
    final sharedAt = (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['sharedAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final viewedAt = (data['viewedAt'] as Timestamp?)?.toDate();
    final status = _deriveSharedDraftStatus(
      data: data,
      currentUserId: currentUserId,
      receiverId: receiverId,
    );

    return SharedDraft(
      id: id,
      draftId: data['originalDraftId'] as String? ??
          data['draftId'] as String? ??
          id,
      senderId: senderId,
      receiverId: receiverId,
      senderName: data['sharerUsername'] as String? ??
          data['senderName'] as String? ??
          'Unknown User',
      senderAvatar: data['sharerAvatarUrl'] as String? ??
          data['senderAvatar'] as String? ??
          '',
      draftTitle: (data['draftTitle'] as String?)?.trim().isNotEmpty == true
          ? data['draftTitle'] as String
          : ((data['caption'] as String?)?.trim().isNotEmpty == true
              ? data['caption'] as String
              : 'Draft'),
      draftThumbnailUrl: data['draftThumbnailUrl'] as String? ??
          data['thumbnailUrl'] as String? ??
          data['thumbnailPath'] as String? ??
          '',
      draftDuration: _readDraftDuration(data),
      sharedAt: sharedAt,
      status: status,
      message: data['message'] as String?,
      viewedAt: viewedAt,
    );
  }

  SharedDraftStatus _deriveSharedDraftStatus({
    required Map<String, dynamic> data,
    required String currentUserId,
    required String receiverId,
  }) {
    final declinedBy =
        List<String>.from(data['declinedBy'] as List<dynamic>? ?? const []);
    final acceptedBy =
        List<String>.from(data['acceptedBy'] as List<dynamic>? ?? const []);
    final viewedBy =
        List<String>.from(data['viewedBy'] as List<dynamic>? ?? const []);
    final targetUserId = currentUserId == receiverId ? currentUserId : receiverId;

    if (declinedBy.contains(targetUserId)) {
      return SharedDraftStatus.declined;
    }
    if (viewedBy.contains(targetUserId) || data['viewedAt'] != null) {
      return SharedDraftStatus.viewed;
    }
    if (acceptedBy.contains(targetUserId)) {
      return SharedDraftStatus.delivered;
    }
    return SharedDraftStatus.pending;
  }

  int _readDraftDuration(Map<String, dynamic> data) {
    final draftDuration = data['draftDuration'];
    if (draftDuration is int) return draftDuration;
    if (draftDuration is num) return draftDuration.round();

    final metadata = data['metadata'];
    if (metadata is Map<String, dynamic>) {
      final duration = metadata['duration'];
      if (duration is int) return duration;
      if (duration is num) return duration.round();
    }

    return 0;
  }

  Connection _mapConnection(String id, Map<String, dynamic> data) {
    final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Connection(
      id: data['id'] as String? ?? id,
      displayName: data['displayName'] as String? ?? 'User',
      username: data['username'] as String? ?? 'user',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: lastSeen,
    );
  }
}
