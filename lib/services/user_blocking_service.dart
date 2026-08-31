import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'follows_service.dart';

bool isBlockedByEitherStore({
  required bool inUserBlocks,
  required bool inBlockedUsers,
}) {
  return inUserBlocks || inBlockedUsers;
}

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

  static FirebaseFirestore? _firestoreOverride;
  static FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  final ValueNotifier<int> _blockListRevision = ValueNotifier<int>(0);

  @visibleForTesting
  static void debugSetOverrides({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    _firestoreOverride = firestore;
    _authOverride = auth;
  }

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

      // Relationship only. Never writes accountStatus. No notify to B.
      await _firestore.collection('user_blocks').add({
        'blockerId': currentUserId,
        'blockedUserId': targetUserId,
        'reason': reason ?? 'User blocked',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .set(<String, dynamic>{
        'blockedUserId': targetUserId,
        'blockedAt': FieldValue.serverTimestamp(),
      });
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

      try {
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blockedUsers')
            .doc(targetUserId)
            .delete();
      } catch (_) {}
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

      QuerySnapshot<Map<String, dynamic>>? rootSnap;
      QuerySnapshot<Map<String, dynamic>>? subSnap;
      try {
        rootSnap = await _firestore
            .collection('user_blocks')
            .where('blockerId', isEqualTo: currentUserId)
            .get();
      } catch (_) {}
      try {
        subSnap = await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blockedUsers')
            .get();
      } catch (_) {}
      final Map<String, BlockedUserRecord> byId = <String, BlockedUserRecord>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in rootSnap?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        final Map<String, dynamic> data = doc.data();
        final Object? rawId = data['blockedUserId'];
        if (rawId is! String || rawId.isEmpty) {
          continue;
        }
        final Object? createdAt = data['createdAt'];
        byId[rawId] = BlockedUserRecord(
          userId: rawId,
          blockedAt: createdAt is Timestamp ? createdAt.toDate() : null,
        );
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in subSnap?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        final Map<String, dynamic> data = doc.data();
        final String userId =
            (data['blockedUserId'] as String?)?.trim().isNotEmpty == true
                ? data['blockedUserId'] as String
                : doc.id;
        if (userId.isEmpty) {
          continue;
        }
        final Object? blockedAtRaw = data['blockedAt'];
        final DateTime? blockedAt =
            blockedAtRaw is Timestamp ? blockedAtRaw.toDate() : null;
        final BlockedUserRecord? existing = byId[userId];
        byId[userId] = BlockedUserRecord(
          userId: userId,
          blockedAt: blockedAt ?? existing?.blockedAt,
        );
      }
      return byId.values.toList();
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
      bool inUserBlocks = false;
      bool inBlockedUsers = false;
      try {
        final List<QuerySnapshot<Map<String, dynamic>>> root =
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
        inUserBlocks = root.any(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.isNotEmpty,
        );
      } catch (_) {}
      try {
        final DocumentSnapshot<Map<String, dynamic>> own = await _firestore
            .collection('users')
            .doc(userId)
            .collection('blockedUsers')
            .doc(otherUserId)
            .get();
        if (own.exists) {
          inBlockedUsers = true;
        }
      } catch (_) {}
      try {
        final DocumentSnapshot<Map<String, dynamic>> theirs = await _firestore
            .collection('users')
            .doc(otherUserId)
            .collection('blockedUsers')
            .doc(userId)
            .get();
        if (theirs.exists) {
          inBlockedUsers = true;
        }
      } catch (_) {}
      return isBlockedByEitherStore(
        inUserBlocks: inUserBlocks,
        inBlockedUsers: inBlockedUsers,
      );
    } catch (e) {
      debugPrint('❌ Error checking block between users: $e');
      return true;
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

      bool inUserBlocks = false;
      bool inBlockedUsers = false;
      try {
        final QuerySnapshot<Map<String, dynamic>> query = await _firestore
            .collection('user_blocks')
            .where('blockerId', isEqualTo: currentUserId)
            .where('blockedUserId', isEqualTo: targetUserId)
            .limit(1)
            .get();
        inUserBlocks = query.docs.isNotEmpty;
      } catch (_) {}
      try {
        final DocumentSnapshot<Map<String, dynamic>> blockedUserDoc =
            await _firestore
                .collection('users')
                .doc(currentUserId)
                .collection('blockedUsers')
                .doc(targetUserId)
                .get();
        inBlockedUsers = blockedUserDoc.exists;
      } catch (_) {}
      return isBlockedByEitherStore(
        inUserBlocks: inUserBlocks,
        inBlockedUsers: inBlockedUsers,
      );
    } catch (e) {
      debugPrint('❌ Error checking if user is blocked: $e');
      return true;
    }
  }
}
