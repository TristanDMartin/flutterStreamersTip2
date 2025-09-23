import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/home_video.dart';
import '../models/trending_creator.dart';
import '../services/logging_service.dart';

class RealUserDataService {
  static final RealUserDataService _instance = RealUserDataService._internal();
  factory RealUserDataService() => _instance;
  RealUserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Get current user data from Firestore
  Future<User?> getCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggingService.instance.debug('No authenticated user', tag: 'RealUserDataService');
        return null;
      }

      final doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!doc.exists) {
        LoggingService.instance.error('User document not found: ${currentUser.uid}', tag: 'RealUserDataService');
        return null;
      }

      final data = doc.data()!;
      final user = User.fromMap(data);
      
      LoggingService.instance.debug('✅ Current user loaded: ${user.displayName}', tag: 'RealUserDataService');
      return user;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting current user', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        LoggingService.instance.error('User not found: $userId', tag: 'RealUserDataService');
        return null;
      }

      final data = doc.data()!;
      return User.fromMap(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user by ID', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get trending creators from Firestore
  Future<List<TrendingCreator>> getTrendingCreators({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      final creators = snapshot.docs.map((doc) {
        final data = doc.data();
        return TrendingCreator(
          id: doc.id,
          username: data['username'] ?? 'Unknown',
          avatarURL: data['avatarURL'],
          followers: data['followerCount'] ?? 0,
          isOnline: (data['onlineStatus'] ?? 'offline') == 'online',
        );
      }).toList();

      LoggingService.instance.debug('✅ Loaded ${creators.length} trending creators', tag: 'RealUserDataService');
      return creators;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting trending creators', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get user's videos
  Future<List<HomeVideo>> getUserVideos(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final videos = <HomeVideo>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Get creator data
        final creator = await getUserById(userId);
        if (creator == null) continue;

        final video = HomeVideo(
          id: doc.id,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: data['thumbnailUrl'] ?? '',
          creator: creator,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          caption: data['title'] ?? data['description'] ?? '',
          categoryId: data['category'] ?? 'general',
        );
        
        videos.add(video);
      }

      LoggingService.instance.debug('✅ Loaded ${videos.length} videos for user: $userId', tag: 'RealUserDataService');
      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user videos', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get for you videos (algorithmic feed)
  Future<List<HomeVideo>> getForYouVideos({int limit = 20, String? lastDocumentId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .where('privacy', isEqualTo: 'public')
          .orderBy('score', descending: true)
          .limit(limit);

      if (lastDocumentId != null) {
        final lastDoc = await _firestore.collection('videos').doc(lastDocumentId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      final snapshot = await query.get();
      final videos = <HomeVideo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        
        if (userId == null) continue;

        // Get creator data
        final creator = await getUserById(userId);
        if (creator == null) continue;

        final video = HomeVideo(
          id: doc.id,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: data['thumbnailUrl'] ?? '',
          creator: creator,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          caption: data['title'] ?? data['description'] ?? '',
          categoryId: data['category'] ?? 'general',
        );
        
        videos.add(video);
      }

      LoggingService.instance.debug('✅ Loaded ${videos.length} for you videos', tag: 'RealUserDataService');
      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting for you videos', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get following videos
  Future<List<HomeVideo>> getFollowingVideos(List<String> followingIds, {int limit = 20}) async {
    try {
      if (followingIds.isEmpty) {
        LoggingService.instance.debug('No following IDs provided', tag: 'RealUserDataService');
        return [];
      }

      final snapshot = await _firestore
          .collection('videos')
          .where('userId', whereIn: followingIds)
          .where('status', isEqualTo: 'published')
          .where('privacy', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final videos = <HomeVideo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        
        if (userId == null) continue;

        // Get creator data
        final creator = await getUserById(userId);
        if (creator == null) continue;

        final video = HomeVideo(
          id: doc.id,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: data['thumbnailUrl'] ?? '',
          creator: creator,
          views: data['views'] ?? 0,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          caption: data['title'] ?? data['description'] ?? '',
          categoryId: data['category'] ?? 'general',
        );
        
        videos.add(video);
      }

      LoggingService.instance.debug('✅ Loaded ${videos.length} following videos', tag: 'RealUserDataService');
      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting following videos', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Update user data
  Future<bool> updateUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'displayName': user.displayName,
        'username': user.username,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'hashtags': user.hashtags,
        'onlineStatus': user.onlineStatus,
        'aiSelf': user.aiSelf,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User updated: ${user.displayName}', tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error updating user', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Create new user
  Future<bool> createUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).set({
        'id': user.id,
        'displayName': user.displayName,
        'username': user.username,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'hashtags': user.hashtags,
        'onlineStatus': user.onlineStatus,
        'aiSelf': user.aiSelf,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'isActive': true,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User created: ${user.displayName}', tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error creating user', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get user's followers
  Future<List<User>> getUserFollowers(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get();

      final followers = <User>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final followerId = data['followerId'] as String?;
        
        if (followerId != null) {
          final follower = await getUserById(followerId);
          if (follower != null) {
            followers.add(follower);
          }
        }
      }

      LoggingService.instance.debug('✅ Loaded ${followers.length} followers for user: $userId', tag: 'RealUserDataService');
      return followers;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user followers', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get user's following
  Future<List<User>> getUserFollowing(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get();

      final following = <User>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final followingId = data['followingId'] as String?;
        
        if (followingId != null) {
          final user = await getUserById(followingId);
          if (user != null) {
            following.add(user);
          }
        }
      }

      LoggingService.instance.debug('✅ Loaded ${following.length} following for user: $userId', tag: 'RealUserDataService');
      return following;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user following', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Follow a user
  Future<bool> followUser(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final followData = {
        'followerId': currentUser.uid,
        'followingId': targetUserId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('follows').add(followData);

      // Update follower counts
      await _firestore.collection('users').doc(currentUser.uid).update({
        'followingCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(targetUserId).update({
        'followerCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User followed: $targetUserId', tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error following user', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'status': 'inactive',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update follower counts
      await _firestore.collection('users').doc(currentUser.uid).update({
        'followingCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(targetUserId).update({
        'followerCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ User unfollowed: $targetUserId', tag: 'RealUserDataService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error unfollowing user', tag: 'RealUserDataService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if user is following another user
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      LoggingService.instance.error('Error checking follow status', tag: 'RealUserDataService', error: e);
      return false;
    }
  }
}
