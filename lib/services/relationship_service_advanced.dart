import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'dart:async';
import '../models/user_model.dart';

/// RelationshipService - Complete implementation with real-time data synchronization
///
/// This service provides comprehensive relationship management including:
/// - Real-time data synchronization with Firebase listeners
/// - Follow/unfollow algorithms with proper error handling
/// - Connection calculation algorithms
/// - State management with reactive updates
class RelationshipServiceAdvanced extends ChangeNotifier {
  // ======== PUBLISHED PROPERTIES (Matching SwiftUI @Published) ========
  List<User> _following = [];
  List<User> _followers = [];
  List<User> _connections = [];
  final List<User> _suggested = [];
  bool _isLoading = false;

  // Getters for reactive updates
  List<User> get following => _following;
  List<User> get followers => _followers;
  List<User> get connections => _connections;
  List<User> get suggested => _suggested;
  bool get isLoading => _isLoading;

  // ======== FIREBASE SETUP ========
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;

  // Real-time listeners (matching SwiftUI ListenerRegistration)
  StreamSubscription<QuerySnapshot>? _followingListener;
  StreamSubscription<QuerySnapshot>? _followersListener;

  // Cancellables for cleanup
  final Set<StreamSubscription> _cancellables = <StreamSubscription>{};

  String? _currentUserId;
  static const String _relationshipsCollection = 'relationships';
  static const String _usersCollection = 'users';

  // ======== INITIALIZATION ========
  RelationshipServiceAdvanced() {
    _initializeService();
  }

  /// Manually refresh current user ID (useful for debugging timing issues)
  void refreshCurrentUserId() {
    final newUserId = _auth.currentUser?.uid;
    debugPrint(
        '🔄 RelationshipServiceAdvanced: Refreshing currentUserId from $_currentUserId to $newUserId');
    if (newUserId != _currentUserId) {
      _currentUserId = newUserId;
      if (_currentUserId != null) {
        _setupRealTimeListeners();
      } else {
        _cleanupListeners();
      }
    }
  }

  /// Validate that we have a current user ID before operations
  bool _validateCurrentUser() {
    if (_currentUserId == null) {
      debugPrint('❌ RelationshipServiceAdvanced: No current user ID available');
      // Try to refresh one more time
      refreshCurrentUserId();
      if (_currentUserId == null) {
        debugPrint(
            '❌ RelationshipServiceAdvanced: Still no user ID after refresh');
        return false;
      }
    }
    return true;
  }

  void _initializeService() {
    _currentUserId = _auth.currentUser?.uid;
    debugPrint(
        '🔄 RelationshipServiceAdvanced: Initializing with currentUserId: $_currentUserId');

    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      debugPrint(
          '🔄 RelationshipServiceAdvanced: Auth state changed - user: ${user?.uid}');
      if (user != null && user.uid != _currentUserId) {
        _currentUserId = user.uid;
        debugPrint(
            '🔄 RelationshipServiceAdvanced: Setting up listeners for user: $_currentUserId');
        _setupRealTimeListeners();
      } else if (user == null) {
        _currentUserId = null;
        debugPrint(
            '🔄 RelationshipServiceAdvanced: User signed out, cleaning up listeners');
        _cleanupListeners();
      }
    });

    if (_currentUserId != null) {
      debugPrint(
          '🔄 RelationshipServiceAdvanced: User already authenticated, setting up listeners');
      _setupRealTimeListeners();
    } else {
      debugPrint(
          '🔄 RelationshipServiceAdvanced: No authenticated user, waiting for auth state change');
    }
  }

  // ======== REAL-TIME LISTENERS SETUP ========
  /// Setup real-time listeners matching SwiftUI implementation
  void _setupRealTimeListeners() {
    if (_currentUserId == null) return;

    _cleanupListeners(); // Clean up existing listeners

    // Following relationships listener
    _followingListener = _db
        .collection(_relationshipsCollection)
        .where('followerId', isEqualTo: _currentUserId)
        .snapshots()
        .listen(
          (snapshot) => _updateFollowingList(snapshot),
          onError: (error) => debugPrint('❌ Following listener error: $error'),
        );
    if (_followingListener != null) {
      _cancellables.add(_followingListener!);
    }

    // Followers relationships listener
    _followersListener = _db
        .collection(_relationshipsCollection)
        .where('followingId', isEqualTo: _currentUserId)
        .snapshots()
        .listen(
          (snapshot) => _updateFollowersList(snapshot),
          onError: (error) => debugPrint('❌ Followers listener error: $error'),
        );
    if (_followersListener != null) {
      _cancellables.add(_followersListener!);
    }
  }

  /// Public hook for logout — stops relationship Firestore listeners immediately.
  void teardownForLogout() {
    _currentUserId = null;
    _cleanupListeners();
    _following = <User>[];
    _followers = <User>[];
    _connections = <User>[];
    _isLoading = false;
    notifyListeners();
  }

  /// Cleanup all listeners
  void _cleanupListeners() {
    for (final subscription in _cancellables) {
      subscription.cancel();
    }
    _cancellables.clear();
    _followingListener = null;
    _followersListener = null;
  }

  // ======== REAL-TIME DATA UPDATES ========
  /// Update following list from Firebase snapshot
  Future<void> _updateFollowingList(QuerySnapshot snapshot) async {
    try {
      final userIds = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['followingId'] as String)
          .toList();

      if (userIds.isEmpty) {
        _following = [];
        _updateConnections();
        notifyListeners();
        return;
      }

      final users = await _fetchUsers(userIds);
      _following = users;
      _updateConnections();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating following list: $e');
    }
  }

  /// Update followers list from Firebase snapshot
  Future<void> _updateFollowersList(QuerySnapshot snapshot) async {
    try {
      final userIds = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['followerId'] as String)
          .toList();

      if (userIds.isEmpty) {
        _followers = [];
        _updateConnections();
        notifyListeners();
        return;
      }

      final users = await _fetchUsers(userIds);
      _followers = users;
      _updateConnections();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating followers list: $e');
    }
  }

  /// Connections calculation algorithm matching SwiftUI implementation
  Future<void> _updateConnections() async {
    // Connections are users who follow each other mutually
    final followingIds = _following.map((user) => user.id).toSet();
    final followerIds = _followers.map((user) => user.id).toSet();
    final mutualIds = followingIds.intersection(followerIds);

    final newConnections = <User>[];
    for (final userId in mutualIds) {
      // Prefer the user from the following list since it's more complete
      final user = _following.firstWhere(
        (user) => user.id == userId,
        orElse: () => _followers.firstWhere(
          (user) => user.id == userId,
          orElse: () => User(
            id: userId,
            username: 'Unknown',
            displayName: 'Unknown User',
          ),
        ),
      );
      newConnections.add(user);
    }

    _connections = newConnections;
  }

  // ======== USER FETCHING ========
  /// Fetch users by IDs with batching for performance
  Future<List<User>> _fetchUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    const int batchSize = 10;
    final List<User> result = [];

    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.sublist(
        i,
        (i + batchSize).clamp(0, userIds.length),
      );

      try {
        final query = await _db
            .collection(_usersCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in query.docs) {
          final user = User.fromMap({
            'id': doc.id,
            ...doc.data(),
          });
          result.add(user);
        }
      } catch (e) {
        debugPrint('❌ Error fetching users batch: $e');
      }
    }

    return result;
  }

  // ======== FOLLOW/UNFOLLOW ALGORITHMS ========
  /// Follow user algorithm matching SwiftUI implementation
  Future<void> followUser(User user) async {
    debugPrint(
        '🔄 RelationshipServiceAdvanced: followUser called with currentUserId: $_currentUserId');
    debugPrint(
        '🔄 RelationshipServiceAdvanced: Stack trace: ${StackTrace.current}');
    if (!_validateCurrentUser()) {
      debugPrint('❌ No current user for follow operation');
      return;
    }

    // Prevent self-following
    if (_currentUserId == user.id) {
      debugPrint('❌ Cannot follow yourself');
      return;
    }

    try {
      _setLoading(true);

      // Check if already following
      final query = await _db
          .collection(_relationshipsCollection)
          .where('followerId', isEqualTo: _currentUserId)
          .where('followingId', isEqualTo: user.id)
          .get();

      if (query.docs.isEmpty) {
        // Create new relationship
        final relationshipData = {
          'followerId': _currentUserId,
          'followingId': user.id,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await _db.collection(_relationshipsCollection).add(relationshipData);

        // Update user's follower count
        await _updateUserFollowerCount(user.id, 1);

        debugPrint('✅ Successfully followed user: ${user.displayName}');
      } else {
        debugPrint('ℹ️ Already following user: ${user.displayName}');
      }
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Unfollow user algorithm matching SwiftUI implementation
  Future<void> unfollowUser(User user) async {
    debugPrint(
        '🔄 RelationshipServiceAdvanced: unfollowUser called with currentUserId: $_currentUserId');
    debugPrint(
        '🔄 RelationshipServiceAdvanced: Stack trace: ${StackTrace.current}');
    if (!_validateCurrentUser()) {
      debugPrint('❌ No current user for unfollow operation');
      return;
    }

    try {
      _setLoading(true);

      // Find the relationship document
      final query = await _db
          .collection(_relationshipsCollection)
          .where('followerId', isEqualTo: _currentUserId)
          .where('followingId', isEqualTo: user.id)
          .get();

      // Delete the relationship document
      for (final document in query.docs) {
        await document.reference.delete();
      }

      // Update user's follower count
      await _updateUserFollowerCount(user.id, -1);

      debugPrint('✅ Successfully unfollowed user: ${user.displayName}');
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove follower algorithm
  Future<void> removeFollower(User user) async {
    debugPrint(
        '🔄 RelationshipServiceAdvanced: removeFollower called with currentUserId: $_currentUserId');
    debugPrint(
        '🔄 RelationshipServiceAdvanced: Stack trace: ${StackTrace.current}');
    if (!_validateCurrentUser()) {
      debugPrint('❌ No current user for remove follower operation');
      return;
    }

    try {
      _setLoading(true);

      // Find the relationship document (reverse direction)
      final query = await _db
          .collection(_relationshipsCollection)
          .where('followerId', isEqualTo: user.id)
          .where('followingId', isEqualTo: _currentUserId)
          .get();

      // Delete the relationship document
      for (final document in query.docs) {
        await document.reference.delete();
      }

      // Update follower count
      if (_currentUserId != null) {
        await _updateUserFollowerCount(_currentUserId!, -1);
      }
      await _updateUserFollowingCount(user.id, -1);

      debugPrint('✅ Successfully removed follower: ${user.displayName}');
    } catch (e) {
      debugPrint('❌ Error removing follower: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ======== HELPER METHODS ========
  /// Update user follower count
  Future<void> _updateUserFollowerCount(String userId, int increment) async {
    try {
      await _db.collection(_usersCollection).doc(userId).update({
        'followerCount': FieldValue.increment(increment),
      });
    } catch (e) {
      debugPrint('❌ Error updating follower count: $e');
    }
  }

  /// Update user following count
  Future<void> _updateUserFollowingCount(String userId, int increment) async {
    try {
      await _db.collection(_usersCollection).doc(userId).update({
        'followingCount': FieldValue.increment(increment),
      });
    } catch (e) {
      debugPrint('❌ Error updating following count: $e');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ======== COMPUTED PROPERTIES ========
  /// Get non-mutual followers only (excluding connections)
  List<User> get nonMutualFollowers {
    final connectionIds = _connections.map((e) => e.id).toSet();
    return _followers
        .where((user) => !connectionIds.contains(user.id))
        .toList();
  }

  /// Get non-mutual following only (excluding connections)
  List<User> get nonMutualFollowing {
    final connectionIds = _connections.map((e) => e.id).toSet();
    return _following
        .where((user) => !connectionIds.contains(user.id))
        .toList();
  }

  // ======== CLEANUP ========
  @override
  void dispose() {
    _cleanupListeners();
    super.dispose();
  }
}
