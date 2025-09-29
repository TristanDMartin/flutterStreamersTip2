import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Debug service to check database state and troubleshoot issues
class DebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check what data exists in the database
  static Future<void> debugDatabaseState() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ DebugService: No current user');
        return;
      }

      final currentUserId = currentUser.uid;
      debugPrint('🔍 DebugService: Current user ID: $currentUserId');

      // Check follows collection
      final followsSnapshot = await _firestore.collection('follows').get();
      debugPrint('📊 DebugService: Follows collection has ${followsSnapshot.docs.length} documents');
      
      for (final doc in followsSnapshot.docs) {
        final data = doc.data();
        debugPrint('  - ${doc.id}: ${data['followerId']} -> ${data['followedId']}');
      }

      // Check old subcollections
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();
      debugPrint('📊 DebugService: Old following subcollection has ${followingSnapshot.docs.length} documents');
      
      for (final doc in followingSnapshot.docs) {
        debugPrint('  - Following: ${doc.id}');
      }

      final followersSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('followers')
          .get();
      debugPrint('📊 DebugService: Old followers subcollection has ${followersSnapshot.docs.length} documents');
      
      for (final doc in followersSnapshot.docs) {
        debugPrint('  - Follower: ${doc.id}');
      }

      // Check user document
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        debugPrint('📊 DebugService: User document counters:');
        debugPrint('  - followingCount: ${userData['followingCount'] ?? 'not set'}');
        debugPrint('  - followersCount: ${userData['followersCount'] ?? 'not set'}');
        debugPrint('  - connectionsCount: ${userData['connectionsCount'] ?? 'not set'}');
      }

      // Check if there are any users in the system
      final usersSnapshot = await _firestore.collection('users').limit(5).get();
      debugPrint('📊 DebugService: Found ${usersSnapshot.docs.length} users in system');
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        debugPrint('  - User: ${doc.id} (${userData['displayName'] ?? 'no name'})');
      }

    } catch (e) {
      debugPrint('❌ DebugService: Error checking database state: $e');
    }
  }

  /// Force run migration
  static Future<void> forceMigration() async {
    try {
      debugPrint('🔄 DebugService: Force running migration...');
      
      // Import the migration service
      // Note: This is a simple migration for testing
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ DebugService: No current user');
        return;
      }

      final currentUserId = currentUser.uid;
      
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      
      debugPrint('📊 DebugService: Found ${userIds.length} users to migrate');
      
      // Create some test relationships
      final batch = _firestore.batch();
      
      // Create mutual follow between first two users (if they exist)
      if (userIds.length >= 2) {
        final user1 = userIds[0];
        final user2 = userIds[1];
        
        if (user1 != currentUserId && user2 != currentUserId) {
          // User1 follows User2
          final follow1Ref = _firestore.collection('follows').doc('${user1}_$user2');
          batch.set(follow1Ref, {
            'followerId': user1,
            'followedId': user2,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          // User2 follows User1 (mutual)
          final follow2Ref = _firestore.collection('follows').doc('${user2}_$user1');
          batch.set(follow2Ref, {
            'followerId': user2,
            'followedId': user1,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          debugPrint('✅ DebugService: Created mutual follow between $user1 and $user2');
        }
      }
      
      // Create one-way follow from current user to first other user
      if (userIds.isNotEmpty) {
        final otherUser = userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
        if (otherUser.isNotEmpty) {
          final followRef = _firestore.collection('follows').doc('${currentUserId}_$otherUser');
          batch.set(followRef, {
            'followerId': currentUserId,
            'followedId': otherUser,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          debugPrint('✅ DebugService: Created follow from $currentUserId to $otherUser');
        }
      }
      
      await batch.commit();
      debugPrint('✅ DebugService: Migration completed');
      
    } catch (e) {
      debugPrint('❌ DebugService: Error in force migration: $e');
    }
  }
}
