import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get list of user IDs that the current user follows/connects with
  Future<List<String>> getFollowingIds() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint(
            '🔍 UserService: No current user - returning empty following list');
        return [];
      }

      debugPrint(
          '🔍 UserService: Getting following IDs for user: ${currentUser.uid}');

      // Try multiple connection systems to find following relationships
      final followingIds = <String>{};

      // Method 1: Check connections collection (users/{userId}/connections)
      try {
        final connectionsSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('connections')
            .get();

        for (final doc in connectionsSnapshot.docs) {
          final data = doc.data();
          final peerId = data['peerId'] ?? doc.id;
          if (peerId.isNotEmpty) {
            followingIds.add(peerId);
            debugPrint('🔍 UserService: Found connection: $peerId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ UserService: Error fetching connections: $e');
      }

      // Method 2: Check follows collection (follows/{followerId}_{followedId})
      try {
        final followsSnapshot = await _firestore
            .collection('follows')
            .where('followerId', isEqualTo: currentUser.uid)
            .get();

        for (final doc in followsSnapshot.docs) {
          final data = doc.data();
          final followedId = data['followedId'] ?? '';
          if (followedId.isNotEmpty) {
            followingIds.add(followedId);
            debugPrint(
                '🔍 UserService: Found follow relationship: $followedId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ UserService: Error fetching follows: $e');
      }

      // Method 3: Check relationships collection (relationships/{relationshipId})
      try {
        final relationshipsSnapshot = await _firestore
            .collection('relationships')
            .where('followerId', isEqualTo: currentUser.uid)
            .get();

        for (final doc in relationshipsSnapshot.docs) {
          final data = doc.data();
          final followingId = data['followingId'] ?? '';
          if (followingId.isNotEmpty) {
            followingIds.add(followingId);
            debugPrint('🔍 UserService: Found relationship: $followingId');
          }
        }
      } catch (e) {
        debugPrint('⚠️ UserService: Error fetching relationships: $e');
      }

      final result = followingIds.toList();
      debugPrint(
          '✅ UserService: Found ${result.length} following users: $result');
      return result;
    } catch (e) {
      debugPrint('❌ UserService: Error getting following IDs: $e');
      return [];
    }
  }
}
