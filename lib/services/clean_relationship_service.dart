import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/follow_edge.dart';
import '../models/user_model.dart' as user_model;

/// Clean Relationship Service - Single source of truth implementation
/// 
/// Follows the clean dev logic with FollowEdge as single source of truth
class CleanRelationshipService {
  static final CleanRelationshipService _instance = CleanRelationshipService._internal();
  factory CleanRelationshipService() => _instance;
  CleanRelationshipService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for current user's relationship state
  RelationshipState? _currentState;
  String? _currentUserId;

  /// Get current user's relationship state
  RelationshipState get currentState => _currentState ?? RelationshipState.empty(_currentUserId ?? '');

  /// Initialize service for current user
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;
    await _loadRelationshipState();
  }

  /// Load relationship state from FollowEdges
  Future<void> _loadRelationshipState() async {
    if (_currentUserId == null) return;

    try {
      // Get all edges where current user is involved
      final followingQuery = await _firestore
          .collection('followEdges')
          .where('followerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      final followersQuery = await _firestore
          .collection('followEdges')
          .where('followeeId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      // Convert to user IDs
      final following = followingQuery.docs.map((doc) => doc.data()['followeeId'] as String).toList();
      final followers = followersQuery.docs.map((doc) => doc.data()['followerId'] as String).toList();

      // Calculate connections (mutual follows)
      final connections = following.where((id) => followers.contains(id)).toList();

      _currentState = RelationshipState(
        userId: _currentUserId!,
        following: following,
        followers: followers,
        connections: connections,
      );
    } catch (e) {
      print('Error loading relationship state: $e');
      _currentState = RelationshipState.empty(_currentUserId!);
    }
  }

  /// A) I unfollow someone (me -> them)
  /// 
  /// Trigger: tap "Unfollow" on a card in Connections or Following
  Future<void> unfollowUser(String themId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // Get current edges
        final myToThemDoc = _firestore
            .collection('followEdges')
            .doc('${_currentUserId}_$themId');
        final themToMeDoc = _firestore
            .collection('followEdges')
            .doc('${themId}_$_currentUserId');

        final myToThemSnapshot = await transaction.get(myToThemDoc);
        final themToMeSnapshot = await transaction.get(themToMeDoc);

        final wasMutual = myToThemSnapshot.exists && 
                         themToMeSnapshot.exists &&
                         myToThemSnapshot.data()?['status'] == 'active' &&
                         themToMeSnapshot.data()?['status'] == 'active';

        // Set edge (me -> them) to status = none
        transaction.set(myToThemDoc, {
          'followerId': _currentUserId,
          'followeeId': themId,
          'status': 'none',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update local state optimistically
        _updateLocalStateAfterUnfollow(themId, wasMutual);
      });

      print('✅ Successfully unfollowed user: $themId');
    } catch (e) {
      print('❌ Error unfollowing user: $e');
      // Rollback local state on error
      await _loadRelationshipState();
    }
  }

  /// B) They unfollow me (them -> me)
  /// 
  /// Trigger: webhook/event or poll detects (them -> me) set to none
  Future<void> handleTheyUnfollowedMe(String themId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // Get current edges
        final myToThemDoc = _firestore
            .collection('followEdges')
            .doc('${_currentUserId}_$themId');
        final themToMeDoc = _firestore
            .collection('followEdges')
            .doc('${themId}_$_currentUserId');

        final myToThemSnapshot = await transaction.get(myToThemDoc);
        final themToMeSnapshot = await transaction.get(themToMeDoc);

        final wasMutual = myToThemSnapshot.exists && 
                         themToMeSnapshot.exists &&
                         myToThemSnapshot.data()?['status'] == 'active' &&
                         themToMeSnapshot.data()?['status'] == 'active';

        // Set edge (them -> me) to status = none
        transaction.set(themToMeDoc, {
          'followerId': themId,
          'followeeId': _currentUserId,
          'status': 'none',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update local state optimistically
        _updateLocalStateAfterTheyUnfollowed(themId, wasMutual);
      });

      print('✅ Handled they unfollowed me: $themId');
    } catch (e) {
      print('❌ Error handling they unfollowed me: $e');
      // Rollback local state on error
      await _loadRelationshipState();
    }
  }

  /// Follow a user (me -> them)
  Future<void> followUser(String themId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final edgeDoc = _firestore
            .collection('followEdges')
            .doc('${_currentUserId}_$themId');

        transaction.set(edgeDoc, {
          'followerId': _currentUserId,
          'followeeId': themId,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update local state optimistically
        _updateLocalStateAfterFollow(themId);
      });

      print('✅ Successfully followed user: $themId');
    } catch (e) {
      print('❌ Error following user: $e');
      // Rollback local state on error
      await _loadRelationshipState();
    }
  }

  /// Update local state after I unfollow someone
  void _updateLocalStateAfterUnfollow(String themId, bool wasMutual) {
    if (_currentState == null) return;

    // Remove from following
    final newFollowing = List<String>.from(_currentState!.following)..remove(themId);
    
    // Check if they still follow me (move to followers if so)
    final newFollowers = List<String>.from(_currentState!.followers);
    final newConnections = List<String>.from(_currentState!.connections);
    
    if (_currentState!.followers.contains(themId)) {
      // They still follow me, so they stay in followers
      // Remove from connections if it was mutual
      if (wasMutual) {
        newConnections.remove(themId);
      }
    } else {
      // They don't follow me, remove from all sections
      newFollowers.remove(themId);
      newConnections.remove(themId);
    }

    _currentState = _currentState!.copyWith(
      following: newFollowing,
      followers: newFollowers,
      connections: newConnections,
    );
  }

  /// Update local state after they unfollowed me
  void _updateLocalStateAfterTheyUnfollowed(String themId, bool wasMutual) {
    if (_currentState == null) return;

    // Remove from followers
    final newFollowers = List<String>.from(_currentState!.followers)..remove(themId);
    
    // Check if I still follow them (move to following if so)
    final newFollowing = List<String>.from(_currentState!.following);
    final newConnections = List<String>.from(_currentState!.connections);
    
    if (_currentState!.following.contains(themId)) {
      // I still follow them, so they stay in following
      // Remove from connections if it was mutual
      if (wasMutual) {
        newConnections.remove(themId);
      }
    } else {
      // I don't follow them, remove from all sections
      newFollowing.remove(themId);
      newConnections.remove(themId);
    }

    _currentState = _currentState!.copyWith(
      following: newFollowing,
      followers: newFollowers,
      connections: newConnections,
    );
  }

  /// Update local state after I follow someone
  void _updateLocalStateAfterFollow(String themId) {
    if (_currentState == null) return;

    final newFollowing = List<String>.from(_currentState!.following);
    if (!newFollowing.contains(themId)) {
      newFollowing.add(themId);
    }

    // Check if they also follow me (mutual connection)
    final newConnections = List<String>.from(_currentState!.connections);
    if (_currentState!.followers.contains(themId)) {
      if (!newConnections.contains(themId)) {
        newConnections.add(themId);
      }
    }

    _currentState = _currentState!.copyWith(
      following: newFollowing,
      connections: newConnections,
    );
  }

  /// Get users for a specific section
  Future<List<user_model.User>> getUsersForSection(String section) async {
    if (_currentState == null) return [];

    List<String> userIds;
    switch (section) {
      case 'following':
        userIds = _currentState!.following;
        break;
      case 'followers':
        userIds = _currentState!.followers;
        break;
      case 'connections':
        userIds = _currentState!.connections;
        break;
      default:
        return [];
    }

    if (userIds.isEmpty) return [];

    try {
      final users = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return users.docs.map((doc) => user_model.User.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error fetching users for $section: $e');
      return [];
    }
  }

  /// Refresh relationship state from database
  Future<void> refresh() async {
    await _loadRelationshipState();
  }
}
