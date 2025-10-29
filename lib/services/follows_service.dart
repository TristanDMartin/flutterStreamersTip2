import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart' as user_model;
import 'event_trigger_service.dart';

/// Service for managing follow relationships using the correct data model
///
/// Data Model:
/// - follows/{followerId}_{followedId} - single collection for all follow relationships
/// - users/{userId} - denormalized counters (followersCount, followingCount, connectionsCount)
///
/// Tab Logic:
/// - Connections: U -> X and X -> U (mutual follows)
/// - Followers: X -> U and NOT U -> X (one-way followers)
/// - Following: U -> X and NOT X -> U (one-way following)
class FollowsService {
  static final FollowsService _instance = FollowsService._internal();
  factory FollowsService() => _instance;
  FollowsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  EventTriggerService? _eventTriggerService;

  /// Set the EventTriggerService instance (should be called from provider)
  void setEventTriggerService(EventTriggerService eventTriggerService) {
    _eventTriggerService = eventTriggerService;
  }

  /// Follow a user
  /// Creates follows/{followerId}_{followedId} and handles mutual relationship logic
  Future<bool> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }

    if (currentUser.uid == targetUserId) {
      debugPrint('❌ FollowsService: Cannot follow yourself');
      return false;
    }

    try {
      final currentUserId = currentUser.uid;

      // First, ensure user documents have the required counter fields
      await _ensureCounterFields(currentUserId);
      await _ensureCounterFields(targetUserId);

      // Create the follow relationship
      final followDocId = '${currentUserId}_$targetUserId';
      final followRef = _firestore.collection('follows').doc(followDocId);

      // Check if the target user already follows the current user (mutual follow)
      final reverseFollowDocId = '${targetUserId}_$currentUserId';
      final reverseFollowRef =
          _firestore.collection('follows').doc(reverseFollowDocId);

      // We need to check this in a transaction to ensure consistency
      final success =
          await _firestore.runTransaction<bool>((transaction) async {
        // Check if reverse follow exists
        final reverseFollowDoc = await transaction.get(reverseFollowRef);
        final isMutual = reverseFollowDoc.exists;

        // Create the follow relationship
        transaction.set(followRef, {
          'followerId': currentUserId,
          'followedId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update counters
        if (isMutual) {
          // Both users now follow each other - update connections count
          transaction.update(
            _firestore.collection('users').doc(currentUserId),
            {
              'followingCount': FieldValue.increment(1),
              'connectionsCount': FieldValue.increment(1),
            },
          );
          transaction.update(
            _firestore.collection('users').doc(targetUserId),
            {
              'followersCount': FieldValue.increment(1),
              'connectionsCount': FieldValue.increment(1),
            },
          );
        } else {
          // One-way follow - update regular counts
          transaction.update(
            _firestore.collection('users').doc(currentUserId),
            {'followingCount': FieldValue.increment(1)},
          );
          transaction.update(
            _firestore.collection('users').doc(targetUserId),
            {'followersCount': FieldValue.increment(1)},
          );
        }

        return true;
      });

      // Trigger follow event for notifications AFTER transaction completes
      if (success && _eventTriggerService != null) {
        debugPrint('🔔 FollowsService: Triggering follow event notification');
        await _eventTriggerService!.triggerFollowEvent(
          followerId: currentUserId,
          followingId: targetUserId,
        );
      } else if (success && _eventTriggerService == null) {
        debugPrint(
            '⚠️ FollowsService: EventTriggerService not set - no notification will be created');
      }

      return success;
    } catch (e) {
      debugPrint('❌ FollowsService: Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  /// Removes follows/{followerId}_{followedId} and handles mutual relationship logic
  Future<bool> unfollowUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }

    try {
      final currentUserId = currentUser.uid;

      // First, ensure user documents have the required counter fields
      await _ensureCounterFields(currentUserId);
      await _ensureCounterFields(targetUserId);

      return await _firestore.runTransaction<bool>((transaction) async {
        // Check if reverse follow exists (mutual relationship)
        final reverseFollowDocId = '${targetUserId}_$currentUserId';
        final reverseFollowRef =
            _firestore.collection('follows').doc(reverseFollowDocId);
        final reverseFollowDoc = await transaction.get(reverseFollowRef);
        final isMutual = reverseFollowDoc.exists;

        // Remove the follow relationship
        final followDocId = '${currentUserId}_$targetUserId';
        final followRef = _firestore.collection('follows').doc(followDocId);
        transaction.delete(followRef);

        // Update counters with safe field handling
        if (isMutual) {
          // Breaking mutual relationship - move to followers/following
          transaction.update(
            _firestore.collection('users').doc(currentUserId),
            {
              'followingCount': FieldValue.increment(-1),
              'connectionsCount': FieldValue.increment(-1),
            },
          );
          transaction.update(
            _firestore.collection('users').doc(targetUserId),
            {
              'followersCount': FieldValue.increment(-1),
              'connectionsCount': FieldValue.increment(-1),
            },
          );
        } else {
          // One-way unfollow - update regular counts
          transaction.update(
            _firestore.collection('users').doc(currentUserId),
            {'followingCount': FieldValue.increment(-1)},
          );
          transaction.update(
            _firestore.collection('users').doc(targetUserId),
            {'followersCount': FieldValue.increment(-1)},
          );
        }

        return true;
      });
    } catch (e) {
      debugPrint('❌ FollowsService: Error unfollowing user: $e');
      return false;
    }
  }

  /// Ensure user document has required counter fields
  Future<void> _ensureCounterFields(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final Map<String, dynamic> updates = {};

      if (!data.containsKey('followingCount')) {
        updates['followingCount'] = 0;
      }
      if (!data.containsKey('followersCount')) {
        updates['followersCount'] = 0;
      }
      if (!data.containsKey('connectionsCount')) {
        updates['connectionsCount'] = 0;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
        debugPrint('✅ Added missing counter fields for user: $userId');
      }
    } catch (e) {
      debugPrint('⚠️ Could not ensure counter fields for user $userId: $e');
    }
  }

  /// Get users for a specific tab using the correct logic
  Future<List<user_model.User>> getUsersForTab(String tab) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return [];
    }

    try {
      final currentUserId = currentUser.uid;

      // DEBUG: Fetch ALL follows documents to inspect structure
      debugPrint(
          '🔍 DEBUG: Fetching ALL follows documents to inspect structure...');
      final allFollowsQuery =
          await _firestore.collection('follows').limit(10).get();
      debugPrint(
          '📋 Found ${allFollowsQuery.docs.length} total follows documents:');
      for (var doc in allFollowsQuery.docs) {
        debugPrint('   Doc ID: ${doc.id}');
        debugPrint('   Doc Data: ${doc.data()}');
        debugPrint('   Data Keys: ${doc.data().keys.toList()}');
      }

      // Get all follows where current user is the follower
      final followingQuery = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId)
          .get();

      debugPrint(
          '📋 Following query results for user $currentUserId: ${followingQuery.docs.length} documents');
      for (var doc in followingQuery.docs) {
        debugPrint('   Doc ID: ${doc.id}, Data: ${doc.data()}');
      }

      // Get all follows where current user is the followed
      final followersQuery = await _firestore
          .collection('follows')
          .where('followedId', isEqualTo: currentUserId)
          .get();

      debugPrint(
          '📋 Followers query results for user $currentUserId: ${followersQuery.docs.length} documents');
      for (var doc in followersQuery.docs) {
        debugPrint('   Doc ID: ${doc.id}, Data: ${doc.data()}');
      }

      // Extract user IDs
      final followingIds = followingQuery.docs
          .map((doc) => doc.data()['followedId'] as String)
          .toSet();
      final followerIds = followersQuery.docs
          .map((doc) => doc.data()['followerId'] as String)
          .toSet();

      debugPrint('📊 FollowsService: Following IDs: ${followingIds.length}');
      debugPrint('📊 FollowsService: Follower IDs: ${followerIds.length}');

      // Calculate tab-specific user IDs using set operations
      Set<String> targetUserIds;
      switch (tab) {
        case 'connections':
          // Mutual follows: U -> X and X -> U
          targetUserIds = followingIds.intersection(followerIds);
          debugPrint(
              '🔗 FollowsService: Connections (mutual): ${targetUserIds.length}');
          break;
        case 'followers':
          // One-way followers: X -> U and NOT U -> X
          targetUserIds = followerIds.difference(followingIds);
          debugPrint(
              '👥 FollowsService: Followers (one-way): ${targetUserIds.length}');
          break;
        case 'following':
          // One-way following: U -> X and NOT X -> U
          targetUserIds = followingIds.difference(followerIds);
          debugPrint(
              '➡️ FollowsService: Following (one-way): ${targetUserIds.length}');
          break;
        default:
          debugPrint('❌ FollowsService: Unknown tab: $tab');
          return [];
      }

      if (targetUserIds.isEmpty) {
        debugPrint('⚠️ FollowsService: No users found for tab $tab');
        return [];
      }

      // Fetch user profiles
      final usersQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: targetUserIds.toList())
          .get();

      final users = usersQuery.docs
          .map((doc) => user_model.User.fromMap(doc.data()))
          .toList();

      debugPrint(
          '✅ FollowsService: Retrieved ${users.length} users for tab $tab');
      return users;
    } catch (e) {
      debugPrint('❌ FollowsService: Error getting users for tab $tab: $e');
      return [];
    }
  }

  /// Check if current user follows a specific user
  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final followDocId = '${currentUser.uid}_$targetUserId';
      final followDoc =
          await _firestore.collection('follows').doc(followDocId).get();
      return followDoc.exists;
    } catch (e) {
      debugPrint('❌ FollowsService: Error checking follow status: $e');
      return false;
    }
  }

  /// Check if a specific user follows the current user
  Future<bool> isFollowedBy(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final followDocId = '${targetUserId}_${currentUser.uid}';
      final followDoc =
          await _firestore.collection('follows').doc(followDocId).get();
      return followDoc.exists;
    } catch (e) {
      debugPrint('❌ FollowsService: Error checking follow status: $e');
      return false;
    }
  }

  /// Check if users have a mutual follow relationship
  Future<bool> isMutualFollow(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final followDocId = '${currentUser.uid}_$targetUserId';
      final reverseFollowDocId = '${targetUserId}_${currentUser.uid}';

      final results = await Future.wait([
        _firestore.collection('follows').doc(followDocId).get(),
        _firestore.collection('follows').doc(reverseFollowDocId).get(),
      ]);

      return results[0].exists && results[1].exists;
    } catch (e) {
      debugPrint('❌ FollowsService: Error checking mutual follow: $e');
      return false;
    }
  }

  /// Get real-time updates for a specific tab
  Stream<List<user_model.User>> getUsersStreamForTab(String tab) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Simple implementation - refresh data every time follows collection changes
    return _firestore.collection('follows').snapshots().asyncMap((_) async {
      return await getUsersForTab(tab);
    });
  }
}
