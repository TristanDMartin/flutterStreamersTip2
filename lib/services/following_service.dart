import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Follow a user
  static Future<bool> followUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

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

      await batch.commit();
      return true;
    } catch (e) {
    // print('Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  static Future<bool> unfollowUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

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

      await batch.commit();
      return true;
    } catch (e) {
    // print('Error unfollowing user: $e');
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
