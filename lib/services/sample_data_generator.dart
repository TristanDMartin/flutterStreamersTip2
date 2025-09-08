import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Sample Data Generator - Complete implementation matching SwiftUI
/// 
/// This service provides comprehensive sample data generation including:
/// - Sample users creation with realistic data
/// - Sample relationships with proper structure
/// - Data integrity validation
/// - Performance optimization
class SampleDataGenerator {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;
  
  static const String _usersCollection = 'users';
  static const String _relationshipsCollection = 'relationships';
  static const String _notificationsCollection = 'notifications';

  /// Create sample relationships algorithm (matching SwiftUI implementation)
  Future<void> createSampleRelationships() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('❌ No current user for sample data creation');
      return;
    }

    try {
      // Create sample users first if they don't exist
      final sampleUsers = [
        {
          'id': 'user1',
          'username': 'gamer_girl',
          'displayName': 'Gamer Girl',
          'bio': 'Professional gamer and streamer',
          'platforms': [
            Platform(
              id: 'twitch_1',
              type: PlatformType.twitch,
              username: 'gamer_girl',
              followers: 1250,
              url: 'https://twitch.tv/gamer_girl',
            ).toMap(),
          ],
        },
        {
          'id': 'user2',
          'username': 'art_streamer',
          'displayName': 'Art Streamer',
          'bio': 'Digital artist and creative streamer',
          'platforms': [
            Platform(
              id: 'youtube_2',
              type: PlatformType.youtube,
              username: 'art_streamer',
              followers: 890,
              url: 'https://youtube.com/@art_streamer',
            ).toMap(),
          ],
        },
        {
          'id': 'user3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'bio': 'Music enthusiast and DJ',
          'platforms': [
            Platform(
              id: 'tiktok_3',
              type: PlatformType.tiktok,
              username: 'music_lover',
              followers: 2100,
              url: 'https://tiktok.com/@music_lover',
            ).toMap(),
          ],
        },
        {
          'id': 'user4',
          'username': 'tech_reviewer',
          'displayName': 'Tech Reviewer',
          'bio': 'Technology reviewer and gadget enthusiast',
          'platforms': [
            Platform(
              id: 'youtube_4',
              type: PlatformType.youtube,
              username: 'tech_reviewer',
              followers: 3400,
              url: 'https://youtube.com/@tech_reviewer',
            ).toMap(),
          ],
        },
        {
          'id': 'user5',
          'username': 'fitness_coach',
          'displayName': 'Fitness Coach',
          'bio': 'Personal trainer and fitness influencer',
          'platforms': [
            Platform(
              id: 'instagram_5',
              type: PlatformType.instagram,
              username: 'fitness_coach',
              followers: 5600,
              url: 'https://instagram.com/fitness_coach',
            ).toMap(),
          ],
        },
      ];

      // Create sample users
      for (final userData in sampleUsers) {
        final userId = userData['id']! as String;
        final userRef = _db.collection(_usersCollection).doc(userId);
        
        await userRef.set({
          'id': userId,
          'username': userData['username']!,
          'displayName': userData['displayName']!,
          'bio': userData['bio']!,
          'platforms': userData['platforms']!,
          'onlineStatus': OnlineStatus.online.value,
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'hashtags': _generateHashtags(userData['username']! as String),
          'aiSelf': userData['bio']!,
          'socialLinks': [],
          'calendarEvents': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Create sample relationships
      final relationships = [
        // Mutual connections
        {'followerId': currentUserId, 'followingId': 'user1'},
        {'followerId': 'user1', 'followingId': currentUserId},
        {'followerId': currentUserId, 'followingId': 'user2'},
        {'followerId': 'user2', 'followingId': currentUserId},
        
        // Follower only
        {'followerId': 'user3', 'followingId': currentUserId},
        {'followerId': 'user4', 'followingId': currentUserId},
        
        // Following only
        {'followerId': currentUserId, 'followingId': 'user5'},
        
        // Additional connections between sample users
        {'followerId': 'user1', 'followingId': 'user2'},
        {'followerId': 'user2', 'followingId': 'user1'},
        {'followerId': 'user3', 'followingId': 'user1'},
        {'followerId': 'user4', 'followingId': 'user2'},
        {'followerId': 'user5', 'followingId': 'user3'},
      ];

      // Create relationships with proper timestamps
      for (final relationshipData in relationships) {
        await _db.collection(_relationshipsCollection).add({
          'followerId': relationshipData['followerId']!,
          'followingId': relationshipData['followingId']!,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update follower counts
      await _updateFollowerCounts();
      
      // Create sample notifications
      await _createSampleNotifications(currentUserId);

      debugPrint('✅ Successfully created sample relationships and users');
    } catch (e) {
      debugPrint('❌ Error creating sample relationships: $e');
      rethrow;
    }
  }

  /// Generate hashtags based on username
  List<String> _generateHashtags(String username) {
    final hashtagMap = {
      'gamer_girl': ['gaming', 'streaming', 'twitch', 'esports', 'gamer'],
      'art_streamer': ['art', 'digital', 'creative', 'drawing', 'design'],
      'music_lover': ['music', 'dj', 'sound', 'audio', 'beat'],
      'tech_reviewer': ['tech', 'gadgets', 'reviews', 'technology', 'innovation'],
      'fitness_coach': ['fitness', 'workout', 'health', 'training', 'gym'],
    };
    
    return hashtagMap[username] ?? ['general', 'content', 'creator'];
  }

  /// Update follower counts for all users
  Future<void> _updateFollowerCounts() async {
    try {
      // Get all relationships
      final relationshipsSnapshot = await _db.collection(_relationshipsCollection).get();
      
      // Count followers for each user
      final Map<String, int> followerCounts = {};
      final Map<String, int> followingCounts = {};
      
      for (final doc in relationshipsSnapshot.docs) {
        final data = doc.data();
        final followerId = data['followerId'] as String;
        final followingId = data['followingId'] as String;
        
        // Count followers
        followerCounts[followingId] = (followerCounts[followingId] ?? 0) + 1;
        
        // Count following
        followingCounts[followerId] = (followingCounts[followerId] ?? 0) + 1;
      }
      
      // Update user documents
      for (final userId in followerCounts.keys) {
        await _db.collection(_usersCollection).doc(userId).update({
          'followerCount': followerCounts[userId] ?? 0,
        });
      }
      
      for (final userId in followingCounts.keys) {
        await _db.collection(_usersCollection).doc(userId).update({
          'followingCount': followingCounts[userId] ?? 0,
        });
      }
      
      debugPrint('✅ Updated follower and following counts');
    } catch (e) {
      debugPrint('❌ Error updating follower counts: $e');
    }
  }

  /// Create sample notifications
  Future<void> _createSampleNotifications(String currentUserId) async {
    try {
      final notifications = [
        {
          'userId': currentUserId,
          'type': 'follow',
          'fromUserId': 'user1',
          'fromUserName': 'Gamer Girl',
          'message': 'Gamer Girl started following you',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        },
        {
          'userId': currentUserId,
          'type': 'follow',
          'fromUserId': 'user2',
          'fromUserName': 'Art Streamer',
          'message': 'Art Streamer started following you',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        },
        {
          'userId': currentUserId,
          'type': 'follow',
          'fromUserId': 'user3',
          'fromUserName': 'Music Lover',
          'message': 'Music Lover started following you',
          'timestamp': FieldValue.serverTimestamp(),
          'read': true,
        },
      ];
      
      for (final notification in notifications) {
        await _db.collection(_notificationsCollection).add(notification);
      }
      
      debugPrint('✅ Created sample notifications');
    } catch (e) {
      debugPrint('❌ Error creating sample notifications: $e');
    }
  }

  /// Clear all sample data
  Future<void> clearSampleData() async {
    try {
      // Clear relationships
      final relationshipsSnapshot = await _db.collection(_relationshipsCollection).get();
      for (final doc in relationshipsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Clear sample users
      final sampleUserIds = ['user1', 'user2', 'user3', 'user4', 'user5'];
      for (final userId in sampleUserIds) {
        await _db.collection(_usersCollection).doc(userId).delete();
      }
      
      // Clear sample notifications
      final notificationsSnapshot = await _db.collection(_notificationsCollection).get();
      for (final doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      debugPrint('✅ Cleared all sample data');
    } catch (e) {
      debugPrint('❌ Error clearing sample data: $e');
    }
  }
}
