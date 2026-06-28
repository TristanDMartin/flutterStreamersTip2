import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'follows_service.dart';

class BlockedUserRecord {
  const BlockedUserRecord({
    required this.userId,
    this.blockedAt,
  });

  final String userId;
  final DateTime? blockedAt;
}

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

  /// Get list of blocked user IDs.
  Future<List<String>> getBlockedUsers() async {
    final List<BlockedUserRecord> records = await getBlockedUserRecords();
    return records.map((BlockedUserRecord record) => record.userId).toList();
  }

  /// Block edges authored by the current user, including block timestamps.
  Future<List<BlockedUserRecord>> getBlockedUserRecords() async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        return <BlockedUserRecord>[];
      }

      final QuerySnapshot<Map<String, dynamic>> query = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .get();

      return query.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final Object? createdAt = data['createdAt'];
        DateTime? blockedAt;
        if (createdAt is Timestamp) {
          blockedAt = createdAt.toDate();
        }
        return BlockedUserRecord(
          userId: data['blockedUserId'] as String,
          blockedAt: blockedAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting blocked users: $e');
      return <BlockedUserRecord>[];
    }
  }

  /// True when either user has blocked the other.
  Future<bool> hasBlockBetween({
    required String userId,
    required String otherUserId,
  }) async {
    if (userId.isEmpty || otherUserId.isEmpty || userId == otherUserId) {
      return false;
    }
    try {
      final List<QuerySnapshot<Map<String, dynamic>>> results =
          await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collection('user_blocks')
            .where('blockerId', isEqualTo: userId)
            .where('blockedUserId', isEqualTo: otherUserId)
            .limit(1)
            .get(),
        _firestore
            .collection('user_blocks')
            .where('blockerId', isEqualTo: otherUserId)
            .where('blockedUserId', isEqualTo: userId)
            .limit(1)
            .get(),
      ]);
      return results.any(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.isNotEmpty,
      );
    } catch (e) {
      debugPrint('❌ Error checking block between users: $e');
      return false;
    }
  }

  /// Whether the signed-in user can open a direct chat with [otherUserId].
  Future<bool> canOpenDirectMessageWith(String otherUserId) async {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return false;
    }
    return !(await hasBlockBetween(
      userId: currentUserId,
      otherUserId: otherUserId,
    ));
  }

  /// Legacy helper — checks only whether the current user blocked [targetUserId].
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
}
