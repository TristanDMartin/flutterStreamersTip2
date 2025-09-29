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

  // Note: Follow/unfollow actions are handled by FollowingService
  // This service is only responsible for reading relationship data

  // Note: Local state updates are no longer needed since this service only reads data
  // Follow/unfollow actions are handled by FollowingService and trigger real-time listeners

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
          
          // Create mutual relationships (connections) - both users follow each other
          for (int i = 0; i < 2 && i < userIds.length; i++) {
            if (userIds[i] != _currentUserId) {
              // Current user follows them
              final followingRef = _firestore
                  .collection('users')
                  .doc(_currentUserId!)
                  .collection('following')
                  .doc(userIds[i]);
              batch.set(followingRef, {
                'userId': userIds[i],
                'followedAt': FieldValue.serverTimestamp(),
              });
              
              // They follow current user back (mutual follow = connection)
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
          
          // Create some one-way followers (they follow you, but you don't follow them back)
          for (int i = 2; i < userIds.length && i < 4; i++) {
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
          
          // Create some one-way following (you follow them, but they don't follow you back)
          for (int i = 4; i < userIds.length && i < 6; i++) {
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
