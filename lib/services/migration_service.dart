import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to migrate from old data model to new follows collection
/// 
/// Old model: users/{userId}/following/{followingId} and users/{userId}/followers/{followerId}
/// New model: follows/{followerId}_{followedId}
class MigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Migrate all follow relationships to the new follows collection
  static Future<bool> migrateFollowRelationships() async {
    try {
      debugPrint('🔄 MigrationService: Starting migration of follow relationships...');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ MigrationService: No authenticated user');
        return false;
      }

      // Get all users to migrate their relationships
      final usersSnapshot = await _firestore.collection('users').get();
      debugPrint('📊 MigrationService: Found ${usersSnapshot.docs.length} users to migrate');

      int totalMigrated = 0;
      int totalErrors = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        debugPrint('🔄 MigrationService: Migrating relationships for user $userId');

        try {
          // Get following relationships
          final followingSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('following')
              .get();

          // Get followers relationships
          final followersSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('followers')
              .get();

          // Create batch for this user's relationships
          final batch = _firestore.batch();

          // Migrate following relationships
          for (final followingDoc in followingSnapshot.docs) {
            final followedId = followingDoc.id;
            final followDocId = '${userId}_$followedId';
            final followRef = _firestore.collection('follows').doc(followDocId);

            // Check if already exists
            final existingDoc = await followRef.get();
            if (!existingDoc.exists) {
              batch.set(followRef, {
                'followerId': userId,
                'followedId': followedId,
                'createdAt': followingDoc.data()['followedAt'] ?? FieldValue.serverTimestamp(),
                'migrated': true,
              });
              totalMigrated++;
            }
          }

          // Migrate followers relationships
          for (final followerDoc in followersSnapshot.docs) {
            final followerId = followerDoc.id;
            final followDocId = '${followerId}_$userId';
            final followRef = _firestore.collection('follows').doc(followDocId);

            // Check if already exists
            final existingDoc = await followRef.get();
            if (!existingDoc.exists) {
              batch.set(followRef, {
                'followerId': followerId,
                'followedId': userId,
                'createdAt': followerDoc.data()['followedAt'] ?? FieldValue.serverTimestamp(),
                'migrated': true,
              });
              totalMigrated++;
            }
          }

          // Commit batch for this user
          await batch.commit();
          debugPrint('✅ MigrationService: Migrated relationships for user $userId');

        } catch (e) {
          debugPrint('❌ MigrationService: Error migrating user $userId: $e');
          totalErrors++;
        }
      }

      debugPrint('🎯 MigrationService: Migration complete - $totalMigrated relationships migrated, $totalErrors errors');
      return totalErrors == 0;
    } catch (e) {
      debugPrint('❌ MigrationService: Migration failed: $e');
      return false;
    }
  }

  /// Update user documents with denormalized counters
  static Future<bool> updateUserCounters() async {
    try {
      debugPrint('🔄 MigrationService: Updating user counters...');
      
      final usersSnapshot = await _firestore.collection('users').get();
      debugPrint('📊 MigrationService: Found ${usersSnapshot.docs.length} users to update');

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        
        try {
          // Count following relationships
          final followingQuery = await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId)
              .get();
          
          // Count followers relationships
          final followersQuery = await _firestore
              .collection('follows')
              .where('followedId', isEqualTo: userId)
              .get();

          // Count mutual follows (connections)
          final followingIds = followingQuery.docs.map((doc) => doc.data()['followedId'] as String).toSet();
          final followerIds = followersQuery.docs.map((doc) => doc.data()['followerId'] as String).toSet();
          final connectionsCount = followingIds.intersection(followerIds).length;

          // Update user document with counters
          await _firestore.collection('users').doc(userId).update({
            'followingCount': followingQuery.docs.length,
            'followersCount': followersQuery.docs.length,
            'connectionsCount': connectionsCount,
            'countersUpdated': FieldValue.serverTimestamp(),
          });

          debugPrint('✅ MigrationService: Updated counters for user $userId - Following: ${followingQuery.docs.length}, Followers: ${followersQuery.docs.length}, Connections: $connectionsCount');

        } catch (e) {
          debugPrint('❌ MigrationService: Error updating counters for user $userId: $e');
        }
      }

      debugPrint('🎯 MigrationService: Counter updates complete');
      return true;
    } catch (e) {
      debugPrint('❌ MigrationService: Counter update failed: $e');
      return false;
    }
  }

  /// Clean up old subcollection data (optional - only run after confirming migration worked)
  static Future<bool> cleanupOldData() async {
    try {
      debugPrint('🔄 MigrationService: Cleaning up old subcollection data...');
      
      final usersSnapshot = await _firestore.collection('users').get();
      debugPrint('📊 MigrationService: Found ${usersSnapshot.docs.length} users to clean up');

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        
        try {
          // Delete following subcollection
          final followingSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('following')
              .get();
          
          for (final doc in followingSnapshot.docs) {
            await doc.reference.delete();
          }

          // Delete followers subcollection
          final followersSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('followers')
              .get();
          
          for (final doc in followersSnapshot.docs) {
            await doc.reference.delete();
          }

          debugPrint('✅ MigrationService: Cleaned up old data for user $userId');

        } catch (e) {
          debugPrint('❌ MigrationService: Error cleaning up user $userId: $e');
        }
      }

      debugPrint('🎯 MigrationService: Cleanup complete');
      return true;
    } catch (e) {
      debugPrint('❌ MigrationService: Cleanup failed: $e');
      return false;
    }
  }

  /// Run complete migration process
  static Future<bool> runCompleteMigration() async {
    try {
      debugPrint('🚀 MigrationService: Starting complete migration process...');
      
      // Step 1: Migrate follow relationships
      final relationshipsMigrated = await migrateFollowRelationships();
      if (!relationshipsMigrated) {
        debugPrint('❌ MigrationService: Relationship migration failed, stopping');
        return false;
      }

      // Step 2: Update user counters
      final countersUpdated = await updateUserCounters();
      if (!countersUpdated) {
        debugPrint('❌ MigrationService: Counter update failed, stopping');
        return false;
      }

      debugPrint('✅ MigrationService: Complete migration successful!');
      debugPrint('⚠️ MigrationService: Old subcollection data still exists - run cleanupOldData() when ready');
      
      return true;
    } catch (e) {
      debugPrint('❌ MigrationService: Complete migration failed: $e');
      return false;
    }
  }
}
