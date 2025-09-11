import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shared_draft.dart';
import '../models/connection.dart';

class SharedDraftService {
  static const String _sharedDraftsKey = 'shared_drafts';
  static const String _connectionsKey = 'connections';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<List<SharedDraft>> _sharedDraftsController =
      StreamController<List<SharedDraft>>.broadcast();
  final StreamController<List<Connection>> _connectionsController =
      StreamController<List<Connection>>.broadcast();

  List<SharedDraft> _sharedDrafts = [];
  List<Connection> _connections = [];

  Stream<List<SharedDraft>> get sharedDraftsStream => _sharedDraftsController.stream;
  Stream<List<Connection>> get connectionsStream => _connectionsController.stream;

  List<SharedDraft> get sharedDrafts => List.unmodifiable(_sharedDrafts);
  List<Connection> get connections => List.unmodifiable(_connections);

  /// Initialize the service and load data
  Future<void> initialize() async {
    await _loadLocalData();
    _setupAuthListener();
    _listenToSharedDrafts();
    _listenToConnections();
  }

  /// Dispose resources
  void dispose() {
    _sharedDraftsController.close();
    _connectionsController.close();
  }

  /// Load local data from SharedPreferences
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load shared drafts
    final sharedDraftsJson = prefs.getStringList(_sharedDraftsKey) ?? [];
    _sharedDrafts = sharedDraftsJson
        .map((json) => SharedDraft.fromJson(json as Map<String, dynamic>))
        .toList();

    // Load connections
    final connectionsJson = prefs.getStringList(_connectionsKey) ?? [];
    _connections = connectionsJson
        .map((json) => Connection.fromJson(json as Map<String, dynamic>))
        .toList();

    _notifyDataChanged();
  }

  /// Save data to SharedPreferences
  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setStringList(
      _sharedDraftsKey,
      _sharedDrafts.map((draft) => draft.toJson().toString()).toList(),
    );
    
    await prefs.setStringList(
      _connectionsKey,
      _connections.map((conn) => conn.toJson().toString()).toList(),
    );
  }

  /// Setup authentication listener
  void _setupAuthListener() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _clearUserData();
      } else {
        _loadRemoteData();
      }
    });
  }

  /// Clear user data on logout
  void _clearUserData() {
    _sharedDrafts.clear();
    _connections.clear();
    _notifyDataChanged();
  }

  /// Load remote data from Firebase
  Future<void> _loadRemoteData() async {
    await Future.wait([
      _loadSharedDraftsFromFirebase(),
      _loadConnectionsFromFirebase(),
    ]);
  }

  /// Listen to shared drafts changes in Firebase
  void _listenToSharedDrafts() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('shared_drafts')
        .where('receiverId', isEqualTo: user.uid)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _sharedDrafts = snapshot.docs
          .map((doc) => SharedDraft.fromJson(doc.data()))
          .toList();
      _notifyDataChanged();
      _saveLocalData();
    });
  }

  /// Listen to connections changes in Firebase
  void _listenToConnections() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('connections')
        .snapshots()
        .listen((snapshot) {
      _connections = snapshot.docs
          .map((doc) => Connection.fromJson(doc.data()))
          .toList();
      _notifyDataChanged();
      _saveLocalData();
    });
  }

  /// Load shared drafts from Firebase
  Future<void> _loadSharedDraftsFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('shared_drafts')
          .where('receiverId', isEqualTo: user.uid)
          .orderBy('sharedAt', descending: true)
          .get();

      _sharedDrafts = snapshot.docs
          .map((doc) => SharedDraft.fromJson(doc.data()))
          .toList();
      _notifyDataChanged();
    } catch (e) {
    // print('Error loading shared drafts: $e');
    }
  }

  /// Load connections from Firebase
  Future<void> _loadConnectionsFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('connections')
          .get();

      _connections = snapshot.docs
          .map((doc) => Connection.fromJson(doc.data()))
          .toList();
      _notifyDataChanged();
    } catch (e) {
    // print('Error loading connections: $e');
    }
  }

  /// Notify listeners of data changes
  void _notifyDataChanged() {
    _sharedDraftsController.add(_sharedDrafts);
    _connectionsController.add(_connections);
  }

  /// Share a draft with a friend
  Future<bool> shareDraft({
    required String draftId,
    required String receiverId,
    required String draftTitle,
    required String draftThumbnailUrl,
    required int draftDuration,
    String? message,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final sharedDraft = SharedDraft(
        id: _firestore.collection('shared_drafts').doc().id,
        draftId: draftId,
        senderId: user.uid,
        receiverId: receiverId,
        senderName: user.displayName ?? 'Unknown User',
        senderAvatar: user.photoURL ?? '',
        draftTitle: draftTitle,
        draftThumbnailUrl: draftThumbnailUrl,
        draftDuration: draftDuration,
        sharedAt: DateTime.now(),
        status: SharedDraftStatus.pending,
        message: message,
      );

      await _firestore
          .collection('shared_drafts')
          .doc(sharedDraft.id)
          .set(sharedDraft.toJson());

      return true;
    } catch (e) {
    // print('Error sharing draft: $e');
      return false;
    }
  }

  /// Mark a shared draft as viewed
  Future<void> markAsViewed(String sharedDraftId) async {
    try {
      await _firestore
          .collection('shared_drafts')
          .doc(sharedDraftId)
          .update({
        'status': SharedDraftStatus.viewed.name,
        'viewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    // print('Error marking draft as viewed: $e');
    }
  }

  /// Decline a shared draft
  Future<void> declineDraft(String sharedDraftId) async {
    try {
      await _firestore
          .collection('shared_drafts')
          .doc(sharedDraftId)
          .update({
        'status': SharedDraftStatus.declined.name,
      });
    } catch (e) {
    // print('Error declining draft: $e');
    }
  }

  /// Delete a shared draft
  Future<void> deleteSharedDraft(String sharedDraftId) async {
    try {
      await _firestore
          .collection('shared_drafts')
          .doc(sharedDraftId)
          .delete();
    } catch (e) {
    // print('Error deleting shared draft: $e');
    }
  }

  /// Get shared drafts for a specific user
  List<SharedDraft> getSharedDraftsForUser(String userId) {
    return _sharedDrafts.where((draft) => draft.receiverId == userId).toList();
  }

  /// Get unread shared drafts count
  int getUnreadCount() {
    return _sharedDrafts
        .where((draft) => draft.status != SharedDraftStatus.viewed)
        .length;
  }

  /// Add a connection
  Future<bool> addConnection({
    required String userId,
    required String name,
    required String avatar,
    required String username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final connection = Connection(
        id: _firestore.collection('connections').doc().id,
        displayName: name,
        username: username,
        avatarUrl: avatar,
        isOnline: false,
        lastSeen: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('connections')
          .doc(connection.id)
          .set(connection.toJson());

      return true;
    } catch (e) {
    // print('Error adding connection: $e');
      return false;
    }
  }

  /// Remove a connection
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
    // print('Error removing connection: $e');
    }
  }
}
