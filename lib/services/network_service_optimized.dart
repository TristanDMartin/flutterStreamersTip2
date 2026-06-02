import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart' as app_user;
import '../models/user_count_fields.dart';

class NetworkServiceOptimized {
  static final NetworkServiceOptimized _instance =
      NetworkServiceOptimized._internal();
  factory NetworkServiceOptimized() => _instance;
  NetworkServiceOptimized._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Cache for better performance
  final Map<String, app_user.User> _userCache = {};
  final Map<String, List<app_user.User>> _listCache = {};

  /// Get user's connections (mutual follows)
  Future<List<app_user.User>> getConnections() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get followers and following in parallel
      final followers = await _getFollowers(currentUser.uid);
      final following = await _getFollowing(currentUser.uid);

      // Find mutual connections
      final followerIds = followers.map((u) => u.id).toSet();
      final followingIds = following.map((u) => u.id).toSet();
      final mutualIds = followerIds.intersection(followingIds);

      return following.where((user) => mutualIds.contains(user.id)).toList();
    } catch (e) {
      // appLog('Error getting connections: $e');
      return [];
    }
  }

  /// Get user's followers
  Future<List<app_user.User>> getFollowers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      return await _getFollowers(currentUser.uid);
    } catch (e) {
      // appLog('Error getting followers: $e');
      return [];
    }
  }

  /// Get user's following
  Future<List<app_user.User>> getFollowing() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      return await _getFollowing(currentUser.uid);
    } catch (e) {
      // appLog('Error getting following: $e');
      return [];
    }
  }

  /// Get non-mutual followers (excluding connections)
  Future<List<app_user.User>> getNonMutualFollowers() async {
    final connections = await getConnections();
    final followers = await getFollowers();

    final connectionIds = connections.map((u) => u.id).toSet();
    return followers.where((user) => !connectionIds.contains(user.id)).toList();
  }

  /// Get non-mutual following (excluding connections)
  Future<List<app_user.User>> getNonMutualFollowing() async {
    final connections = await getConnections();
    final following = await getFollowing();

    final connectionIds = connections.map((u) => u.id).toSet();
    return following.where((user) => !connectionIds.contains(user.id)).toList();
  }

  /// Follow a user
  Future<bool> followUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Create relationship document
      final relationshipRef = _firestore.collection('relationships').doc();
      batch.set(relationshipRef, {
        'followerId': currentUser.uid,
        'followingId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update follower count
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'followerCount': FieldValue.increment(1),
      });

      // Update following count
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Clear cache
      _clearCache();

      return true;
    } catch (e) {
      // appLog('Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Find and delete relationship
      final relationshipQuery = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: userId)
          .get();

      for (final doc in relationshipQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update follower count
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'followerCount': FieldValue.increment(-1),
      });

      // Update following count
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      await batch.commit();

      // Clear cache
      _clearCache();

      return true;
    } catch (e) {
      // appLog('Error unfollowing user: $e');
      return false;
    }
  }

  /// Remove a follower
  Future<bool> removeFollower(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Find and delete relationship (reverse direction)
      final relationshipQuery = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: userId)
          .where('followingId', isEqualTo: currentUser.uid)
          .get();

      for (final doc in relationshipQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update follower count
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followerCount': FieldValue.increment(-1),
      });

      // Update following count
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'followingCount': FieldValue.increment(-1),
      });

      await batch.commit();

      // Clear cache
      _clearCache();

      return true;
    } catch (e) {
      // appLog('Error removing follower: $e');
      return false;
    }
  }

  /// Get user suggestions
  Future<List<app_user.User>> getUserSuggestions({int limit = 10}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get users that the current user doesn't follow
      final following = await getFollowing();
      final followingIds = following.map((u) => u.id).toSet();

      final query = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
          .limit(limit * 2) // Get more to filter out following
          .get();

      final suggestions = <app_user.User>[];
      for (final doc in query.docs) {
        if (!followingIds.contains(doc.id)) {
          suggestions.add(_mapUser(doc.id, doc.data()));
          if (suggestions.length >= limit) break;
        }
      }

      return suggestions;
    } catch (e) {
      // appLog('Error getting user suggestions: $e');
      return [];
    }
  }

  /// Get followers for a specific user
  Future<List<app_user.User>> _getFollowers(String userId) async {
    try {
      final query = await _firestore
          .collection('relationships')
          .where('followingId', isEqualTo: userId)
          .get();

      final followerIds =
          query.docs.map((doc) => doc.data()['followerId'] as String).toList();
      return await _fetchUsers(followerIds);
    } catch (e) {
      // appLog('Error getting followers: $e');
      return [];
    }
  }

  /// Get following for a specific user
  Future<List<app_user.User>> _getFollowing(String userId) async {
    try {
      final query = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: userId)
          .get();

      final followingIds =
          query.docs.map((doc) => doc.data()['followingId'] as String).toList();
      return await _fetchUsers(followingIds);
    } catch (e) {
      // appLog('Error getting following: $e');
      return [];
    }
  }

  /// Fetch users by IDs with batching
  Future<List<app_user.User>> _fetchUsers(List<String> ids) async {
    if (ids.isEmpty) return [];

    // Check cache first
    final cachedUsers = <app_user.User>[];
    final uncachedIds = <String>[];

    for (final id in ids) {
      if (_userCache.containsKey(id)) {
        cachedUsers.add(_userCache[id]!);
      } else {
        uncachedIds.add(id);
      }
    }

    if (uncachedIds.isEmpty) return cachedUsers;

    try {
      // Batch fetch uncached users with optimized batch size
      const batchSize = 10; // Optimized batch size for better performance
      final fetchedUsers = <app_user.User>[];

      // Limit to prevent excessive queries
      final limitedIds = uncachedIds.take(50).toList(); // Limit to 50 users max

      for (int i = 0; i < limitedIds.length; i += batchSize) {
        final batch =
            limitedIds.sublist(i, (i + batchSize).clamp(0, limitedIds.length));

        try {
          final query = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in query.docs) {
            final user = _mapUser(doc.id, doc.data());
            _userCache[doc.id] = user; // Cache the user
            fetchedUsers.add(user);
          }
        } catch (e) {
          // Skip failed batches to prevent total failure
          continue;
        }
      }

      return [...cachedUsers, ...fetchedUsers];
    } catch (e) {
      // appLog('Error fetching users: $e');
      return cachedUsers;
    }
  }

  /// Map Firestore document to User model
  app_user.User _mapUser(String id, Map<String, dynamic> data) {
    return app_user.User(
      id: id,
      displayName: (data['displayName'] ?? 'User').toString(),
      username: (data['username'] ?? 'user').toString(),
      avatarURL: data['avatarURL'] as String?,
      onlineStatus: (data['onlineStatus'] ?? 'offline').toString(),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      aiSelf: data['aiSelf']?.toString() ?? '',
      postCount: data['postCount'] ?? 0,
      followerCount: UserCountFields.readFollowersCount(data),
      followingCount: UserCountFields.readFollowingCount(data),
      calendarEvents: [],
    );
  }

  /// Clear cache
  void _clearCache() {
    _userCache.clear();
    _listCache.clear();
  }

  /// Get user by ID
  Future<app_user.User?> getUserById(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = _mapUser(doc.id, doc.data()!);
        _userCache[userId] = user;
        return user;
      }
      return null;
    } catch (e) {
      // appLog('Error getting user by ID: $e');
      return null;
    }
  }
}
