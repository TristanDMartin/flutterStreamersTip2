import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Follow a user
  static Future<bool> followUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('FollowingService: No authenticated user');
        return false;
      }
      
      print('FollowingService: Following user $userId by ${currentUser.uid}');

      final batch = _firestore.batch();
      
      // Add to current user's following list
      final followingRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId);
      batch.set(followingRef, {
        'userId': userId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Add to target user's followers list
      final followersRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(currentUser.uid);
      batch.set(followersRef, {
        'userId': currentUser.uid,
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Update follower counts
      final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      final targetUserRef = _firestore.collection('users').doc(userId);
      batch.update(targetUserRef, {
        'followerCount': FieldValue.increment(1),
      });

      // Create activity notification for the target user in the correct collection
      final activityRef = _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .doc('follow_${currentUser.uid}');
      batch.set(activityRef, {
        'type': 'follow',
        'user': {
          'id': currentUser.uid,
          'displayName': currentUser.displayName ?? 'User',
          'username': currentUser.displayName ?? 'user',
          'avatarURL': currentUser.photoURL,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Also create a relationship document for compatibility with existing listeners
      final relationshipRef = _firestore.collection('relationships').doc();
      batch.set(relationshipRef, {
        'followerId': currentUser.uid,
        'followingId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('FollowingService: Successfully followed user $userId');
      return true;
    } catch (e) {
      print('FollowingService: Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  static Future<bool> unfollowUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('FollowingService: No authenticated user for unfollow');
        return false;
      }
      
      print('FollowingService: Unfollowing user $userId by ${currentUser.uid}');

      final batch = _firestore.batch();
      
      // Remove from current user's following list
      final followingRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId);
      batch.delete(followingRef);

      // Remove from target user's followers list
      final followersRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(currentUser.uid);
      batch.delete(followersRef);

      // Update follower counts
      final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      final targetUserRef = _firestore.collection('users').doc(userId);
      batch.update(targetUserRef, {
        'followerCount': FieldValue.increment(-1),
      });

      // Remove activity notification for the target user from the correct collection
      final activityRef = _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .doc('follow_${currentUser.uid}');
      batch.delete(activityRef);

      // Remove relationship document for compatibility
      final relationshipQuery = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: userId)
          .get();
      
      for (final doc in relationshipQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('FollowingService: Successfully unfollowed user $userId');
      return true;
    } catch (e) {
      print('FollowingService: Error unfollowing user: $e');
      return false;
    }
  }

  /// Check if current user is following a specific user
  static Future<bool> isFollowing(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
    // print('Error checking follow status: $e');
      return false;
    }
  }

  /// Get list of users that current user is following
  static Future<List<String>> getFollowingList() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
    // print('Error getting following list: $e');
      return [];
    }
  }

  /// Get list of users following the current user
  static Future<List<String>> getFollowersList() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('followers')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
    // print('Error getting followers list: $e');
      return [];
    }
  }

  /// Toggle follow status
  static Future<bool> toggleFollow(String userId) async {
    final isCurrentlyFollowing = await isFollowing(userId);
    
    if (isCurrentlyFollowing) {
      return await unfollowUser(userId);
    } else {
      return await followUser(userId);
    }
  }

  /// Get user's follower count
  static Future<int> getFollowerCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['followerCount'] ?? 0;
    } catch (e) {
    // print('Error getting follower count: $e');
      return 0;
    }
  }

  /// Get user's following count
  static Future<int> getFollowingCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['followingCount'] ?? 0;
    } catch (e) {
    // print('Error getting following count: $e');
      return 0;
    }
  }
}
