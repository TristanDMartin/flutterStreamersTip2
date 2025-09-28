import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// Load relationship state from actual Firestore subcollections
  Future<void> _loadRelationshipState() async {
    if (_currentUserId == null) return;

    try {
      debugPrint('🔄 CleanRelationshipService: Loading relationship state for user $_currentUserId');
      
      // Get following list from users/{userId}/following subcollection
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('following')
          .get();

      // Get followers list from users/{userId}/followers subcollection
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('followers')
          .get();

      // Convert to user IDs
      final following = followingSnapshot.docs.map((doc) => doc.id).toList();
      final followers = followersSnapshot.docs.map((doc) => doc.id).toList();

      debugPrint('📊 CleanRelationshipService: Following: ${following.length} (IDs: $following)');
      debugPrint('📊 CleanRelationshipService: Followers: ${followers.length} (IDs: $followers)');

      // If no relationships found in subcollections, check legacy relationships collection
      if (following.isEmpty && followers.isEmpty) {
        debugPrint('⚠️ CleanRelationshipService: No relationships found in subcollections, checking legacy collection...');
        await _migrateFromLegacyRelationships();
        
        // Retry after migration
        final followingSnapshotRetry = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('following')
            .get();

        final followersSnapshotRetry = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('followers')
            .get();

        final followingRetry = followingSnapshotRetry.docs.map((doc) => doc.id).toList();
        final followersRetry = followersSnapshotRetry.docs.map((doc) => doc.id).toList();
        
        debugPrint('📊 CleanRelationshipService: After migration - Following: ${followingRetry.length}, Followers: ${followersRetry.length}');
        
        _currentState = RelationshipState(
          userId: _currentUserId!,
          following: followingRetry,
          followers: followersRetry,
          connections: followingRetry.where((id) => followersRetry.contains(id)).toList(),
        );
      } else {
        // Calculate connections (mutual follows)
        final connections = following.where((id) => followers.contains(id)).toList();
        
        debugPrint('🤝 CleanRelationshipService: Connections: ${connections.length} (IDs: $connections)');

        _currentState = RelationshipState(
          userId: _currentUserId!,
          following: following,
          followers: followers,
          connections: connections,
        );
      }
      
      debugPrint('✅ CleanRelationshipService: Relationship state loaded successfully');
    } catch (e) {
      debugPrint('❌ CleanRelationshipService: Error loading relationship state: $e');
      _currentState = RelationshipState.empty(_currentUserId!);
    }
  }

  /// Migrate from legacy relationships collection to new subcollection structure
  Future<void> _migrateFromLegacyRelationships() async {
    try {
      debugPrint('🔄 CleanRelationshipService: Starting migration from legacy relationships...');
      
      // Get relationships where current user is follower
      final followingQuery = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: _currentUserId)
          .get();

      // Get relationships where current user is followed
      final followersQuery = await _firestore
          .collection('relationships')
          .where('followingId', isEqualTo: _currentUserId)
          .get();

      final batch = _firestore.batch();

      // Migrate following relationships
      for (final doc in followingQuery.docs) {
        final data = doc.data();
        final followingId = data['followingId'] as String?;
        if (followingId != null) {
          final followingRef = _firestore
              .collection('users')
              .doc(_currentUserId!)
              .collection('following')
              .doc(followingId);
          batch.set(followingRef, {
            'userId': followingId,
            'followedAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          });
        }
      }

      // Migrate followers relationships
      for (final doc in followersQuery.docs) {
        final data = doc.data();
        final followerId = data['followerId'] as String?;
        if (followerId != null) {
          final followersRef = _firestore
              .collection('users')
              .doc(_currentUserId!)
              .collection('followers')
              .doc(followerId);
          batch.set(followersRef, {
            'userId': followerId,
            'followedAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      debugPrint('✅ CleanRelationshipService: Migration completed successfully');
    } catch (e) {
      debugPrint('❌ CleanRelationshipService: Error during migration: $e');
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

      debugPrint('✅ Successfully unfollowed user: $themId');
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
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

      debugPrint('✅ Handled they unfollowed me: $themId');
    } catch (e) {
      debugPrint('❌ Error handling they unfollowed me: $e');
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

      debugPrint('✅ Successfully followed user: $themId');
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      // Rollback local state on error
      await _loadRelationshipState();
    }
  }

  /// Update local state after I unfollow someone
  void _updateLocalStateAfterUnfollow(String themId, bool wasMutual) {
    if (_currentState == null) return;

    final newFollowing = List<String>.from(_currentState!.following);
    final newFollowers = List<String>.from(_currentState!.followers);
    final newConnections = List<String>.from(_currentState!.connections);
    
    // Always remove from following and connections
    newFollowing.remove(themId);
    newConnections.remove(themId);
    
    // Check if they still follow me
    if (_currentState!.followers.contains(themId)) {
      // They still follow me, ensure they're in followers
      if (!newFollowers.contains(themId)) {
        newFollowers.add(themId);
      }
    } else {
      // They don't follow me, remove from followers too
      newFollowers.remove(themId);
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

    final newFollowing = List<String>.from(_currentState!.following);
    final newFollowers = List<String>.from(_currentState!.followers);
    final newConnections = List<String>.from(_currentState!.connections);
    
    // Always remove from followers and connections
    newFollowers.remove(themId);
    newConnections.remove(themId);
    
    // Check if I still follow them
    if (_currentState!.following.contains(themId)) {
      // I still follow them, ensure they're in following
      if (!newFollowing.contains(themId)) {
        newFollowing.add(themId);
      }
    } else {
      // I don't follow them, remove from following too
      newFollowing.remove(themId);
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
    final newConnections = List<String>.from(_currentState!.connections);
    
    // Check if they also follow me (mutual connection)
    final isMutual = _currentState!.followers.contains(themId);
    
    if (isMutual) {
      // If mutual, add to connections and remove from following
      if (!newConnections.contains(themId)) {
        newConnections.add(themId);
      }
      newFollowing.remove(themId); // Remove from following when mutual
    } else {
      // If not mutual, add to following
      if (!newFollowing.contains(themId)) {
        newFollowing.add(themId);
      }
      newConnections.remove(themId); // Remove from connections if not mutual
    }

    _currentState = _currentState!.copyWith(
      following: newFollowing,
      connections: newConnections,
    );
  }

  /// Get users for a specific section
  Future<List<user_model.User>> getUsersForSection(String section) async {
    if (_currentState == null) {
      debugPrint('❌ CleanRelationshipService: No current state for section $section');
      return [];
    }

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
        debugPrint('❌ CleanRelationshipService: Unknown section $section');
        return [];
    }

    debugPrint('🔍 CleanRelationshipService: Getting $section users, found ${userIds.length} IDs');

    if (userIds.isEmpty) {
      debugPrint('⚠️ CleanRelationshipService: No user IDs for section $section');
      return [];
    }

    try {
      final users = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      final userList = users.docs.map((doc) => user_model.User.fromMap(doc.data())).toList();
      debugPrint('✅ CleanRelationshipService: Retrieved ${userList.length} users for section $section');
      return userList;
    } catch (e) {
      debugPrint('❌ CleanRelationshipService: Error fetching users for $section: $e');
      return [];
    }
  }

  /// Refresh relationship state from database
  Future<void> refresh() async {
    await _loadRelationshipState();
  }

  /// Create test relationships for demonstration (only if no relationships exist)
  Future<void> createTestRelationshipsIfNeeded() async {
    if (_currentState == null || 
        (_currentState!.following.isEmpty && _currentState!.followers.isEmpty)) {
      
      debugPrint('🧪 CleanRelationshipService: Creating test relationships...');
      
      try {
        // Get some sample user IDs from the users collection
        final usersSnapshot = await _firestore
            .collection('users')
            .limit(5)
            .get();

        final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
        
        if (userIds.isNotEmpty && _currentUserId != null) {
          final batch = _firestore.batch();
          
          // Create some test following relationships
          for (int i = 0; i < 2 && i < userIds.length; i++) {
            if (userIds[i] != _currentUserId) {
              final followingRef = _firestore
                  .collection('users')
                  .doc(_currentUserId!)
                  .collection('following')
                  .doc(userIds[i]);
              batch.set(followingRef, {
                'userId': userIds[i],
                'followedAt': FieldValue.serverTimestamp(),
              });
            }
          }
          
          // Create some test followers (simulate other users following current user)
          for (int i = 2; i < userIds.length; i++) {
            if (userIds[i] != _currentUserId) {
              final followersRef = _firestore
                  .collection('users')
                  .doc(_currentUserId!)
                  .collection('followers')
                  .doc(userIds[i]);
              batch.set(followersRef, {
                'userId': userIds[i],
                'followedAt': FieldValue.serverTimestamp(),
              });
            }
          }
          
          await batch.commit();
          debugPrint('✅ CleanRelationshipService: Test relationships created');
          
          // Reload state after creating test data
          await _loadRelationshipState();
        }
      } catch (e) {
        debugPrint('❌ CleanRelationshipService: Error creating test relationships: $e');
      }
    }
  }
}
