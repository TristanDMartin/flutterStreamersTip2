import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';

class SampleUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Sample users that match the ones in home_provider.dart
  static const List<Map<String, dynamic>> _sampleUsers = [
    {
      'id': 'user1',
      'username': 'streamer1',
      'displayName': 'Streamer One',
      'avatarURL': 'https://i.pravatar.cc/200?img=1',
      'bio': 'Professional gamer and content creator. Love sharing amazing gaming moments! 🎮',
      'hashtags': ['gaming', 'streaming', 'esports'],
      'onlineStatus': 'online',
      'postCount': 42,
      'followerCount': 1250,
      'followingCount': 89,
      'aiSelf': 'Passionate gamer who loves creating content and connecting with the community.',
    },
    {
      'id': 'user2',
      'username': 'streamer2',
      'displayName': 'Streamer Two',
      'avatarURL': 'https://i.pravatar.cc/200?img=2',
      'bio': 'Creative content creator sharing cool tricks and entertaining moments! 🔥',
      'hashtags': ['entertainment', 'tricks', 'fun'],
      'onlineStatus': 'online',
      'postCount': 28,
      'followerCount': 890,
      'followingCount': 156,
      'aiSelf': 'Creative entertainer who loves sharing fun and engaging content.',
    },
  ];

  /// Ensure sample users exist in Firestore
  static Future<void> ensureSampleUsersExist() async {
    try {
      if (kDebugMode) {
        print('🔧 SampleUserService: Checking if sample users exist in Firestore...');
      }

      for (final userData in _sampleUsers) {
        final userRef = _firestore.collection('users').doc(userData['id']);
        
        try {
          // Check if user already exists
          final doc = await userRef.get();
          
          if (!doc.exists) {
            if (kDebugMode) {
              print('ℹ️ SampleUserService: User ${userData['username']} does not exist in Firestore');
              print('ℹ️ SampleUserService: This is expected for sample data - StreamerCardView will handle gracefully');
            }
          } else {
            if (kDebugMode) {
              print('✅ SampleUserService: User ${userData['username']} already exists in Firestore');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('ℹ️ SampleUserService: Cannot check user ${userData['username']} - this is expected for sample data');
          }
        }
      }
      
      if (kDebugMode) {
        print('✅ SampleUserService: Sample user check completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ SampleUserService: Sample user check failed - this is expected for sample data: $e');
      }
    }
  }

  /// Get sample user by ID
  static Future<User?> getSampleUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return User.fromMap(data);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SampleUserService: Error getting sample user $userId: $e');
      }
      return null;
    }
  }
}
