import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'follows_service.dart';

/// Service for managing user blocking functionality
class UserBlockingService {
  static final UserBlockingService _instance = UserBlockingService._internal();
  factory UserBlockingService() => _instance;
  UserBlockingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ValueNotifier<int> _blockListRevision = ValueNotifier<int>(0);

  ValueListenable<int> get blockListRevision => _blockListRevision;

  void _notifyBlockListChanged() {
    _blockListRevision.value++;
  }

  /// Block a user
  Future<void> blockUser({
    required String targetUserId,
    String? reason,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (currentUserId == targetUserId) {
        throw Exception('Cannot block yourself');
      }

      // Add to blocked users collection
      await _firestore.collection('user_blocks').add({
        'blockerId': currentUserId,
        'blockedUserId': targetUserId,
        'reason': reason ?? 'User blocked',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user's blocked list
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      });

      await FollowsService().removeRelationshipBothWays(targetUserId);

      _notifyBlockListChanged();
      debugPrint('✅ User blocked: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Remove from blocked users collection
      final query = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .where('blockedUserId', isEqualTo: targetUserId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }

      // Update user's blocked list
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([targetUserId]),
      });

      _notifyBlockListChanged();
      debugPrint('✅ User unblocked: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error unblocking user: $e');
      rethrow;
    }
  }

  /// Check if a user is blocked by current user
  Future<bool> isUserBlocked(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      final query = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .where('blockedUserId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Get list of blocked users
  Future<List<String>> getBlockedUsers() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      final query = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .get();

      return query.docs
          .map((doc) => doc.data()['blockedUserId'] as String)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting blocked users: $e');
      return [];
    }
  }
}
