import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart' as user_model;
import 'event_trigger_service.dart';

class FollowsService {
  static final FollowsService _instance = FollowsService._internal();
  factory FollowsService() => _instance;
  FollowsService._internal();

  static FirebaseFirestore? _firestoreOverride;
  static FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  EventTriggerService? _eventTriggerService;

  void setEventTriggerService(EventTriggerService eventTriggerService) {
    _eventTriggerService = eventTriggerService;
  }

  @visibleForTesting
  static void debugSetOverrides({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    _firestoreOverride = firestore;
    _authOverride = auth;
  }

  Future<bool> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }
    if (currentUser.uid == targetUserId) {
      debugPrint('❌ FollowsService: Cannot follow yourself');
      return false;
    }
    try {
      final currentUserId = currentUser.uid;
      await _ensureCounterFields(currentUserId);
      await _ensureCounterFields(targetUserId);
      await _firestore.collection('follows').add({
        'followerUserId': currentUserId,
        'targetUserId': targetUserId,
        'followerId': currentUserId, // legacy
        'followingId': targetUserId, // legacy
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (_eventTriggerService != null) {
        await _eventTriggerService!.triggerFollowEvent(
          followerId: currentUserId,
          followingId: targetUserId,
        );
      }
      return true;
    } catch (e) {
      debugPrint('❌ FollowsService: Error following user: $e');
      return false;
    }
  }

  Future<bool> unfollowUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }
    try {
      final currentUserId = currentUser.uid;
      await _ensureCounterFields(currentUserId);
      await _ensureCounterFields(targetUserId);
      final batch = _firestore.batch();
      final follows = _firestore.collection('follows');
      final primary = await follows
          .where('followerUserId', isEqualTo: currentUserId)
          .where('targetUserId', isEqualTo: targetUserId)
          .get();
      for (final doc in primary.docs) {
        batch.delete(doc.reference);
      }
      final legacy = await follows
          .where('followerId', isEqualTo: currentUserId)
          .where('followingId', isEqualTo: targetUserId)
          .get();
      for (final doc in legacy.docs) {
        batch.delete(doc.reference);
      }
      final legacyAlt = await follows
          .where('followerId', isEqualTo: currentUserId)
          .where('followedId', isEqualTo: targetUserId)
          .get();
      for (final doc in legacyAlt.docs) {
        batch.delete(doc.reference);
      }
      if (primary.docs.isEmpty &&
          legacy.docs.isEmpty &&
          legacyAlt.docs.isEmpty) {
        return true;
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('❌ FollowsService: Error unfollowing user: $e');
      return false;
    }
  }

  Future<void> _ensureCounterFields(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      final data = userDoc.data()!;
      final updates = <String, dynamic>{};
      if (!data.containsKey('followingCount')) updates['followingCount'] = 0;
      if (!data.containsKey('followersCount')) updates['followersCount'] = 0;
      if (!data.containsKey('connectionsCount'))
        updates['connectionsCount'] = 0;
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      debugPrint('⚠️ Could not ensure counter fields for user $userId: $e');
    }
  }

  Future<List<user_model.User>> getUsersForTab(String tab) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return [];
    }
    try {
      final currentUserId = currentUser.uid;
      final followersPrimary = await _firestore
          .collection('follows')
          .where('targetUserId', isEqualTo: currentUserId)
          .get();
      final followersLegacy1 = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: currentUserId)
          .get();
      final followersLegacy2 = await _firestore
          .collection('follows')
          .where('followedId', isEqualTo: currentUserId)
          .get();
      final followingPrimary = await _firestore
          .collection('follows')
          .where('followerUserId', isEqualTo: currentUserId)
          .get();
      final followingLegacy = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId)
          .get();
      String? _readFollowerId(Map<String, dynamic> data) {
        final val = data['followerUserId'] ??
            data['followerId'] ??
            data['follower'] ??
            data['follower_id'];
        return val is String ? val : null;
      }

      String? _readFollowingId(Map<String, dynamic> data) {
        final val = data['targetUserId'] ??
            data['followingId'] ??
            data['followedId'] ??
            data['target_user_id'];
        return val is String ? val : null;
      }

      bool _isActive(Map<String, dynamic> data) {
        if (!data.containsKey('isActive')) return true;
        final val = data['isActive'];
        if (val is bool) return val;
        return true;
      }

      final followerIds = <String>{};
      for (final doc in followersPrimary.docs) {
        final data = doc.data();
        if (!_isActive(data)) continue;
        final id = _readFollowerId(data);
        if (id != null && id.isNotEmpty) followerIds.add(id);
      }
      for (final doc in [...followersLegacy1.docs, ...followersLegacy2.docs]) {
        final data = doc.data();
        if (!_isActive(data)) continue;
        final id = _readFollowerId(data);
        if (id != null && id.isNotEmpty) followerIds.add(id);
      }
      final followingIds = <String>{};
      for (final doc in followingPrimary.docs) {
        final data = doc.data();
        if (!_isActive(data)) continue;
        final id = _readFollowingId(data);
        if (id != null && id.isNotEmpty) followingIds.add(id);
      }
      for (final doc in followingLegacy.docs) {
        final data = doc.data();
        if (!_isActive(data)) continue;
        final id = _readFollowingId(data);
        if (id != null && id.isNotEmpty) followingIds.add(id);
      }
      Set<String> targetUserIds;
      switch (tab) {
        case 'connections':
          targetUserIds = followingIds.intersection(followerIds);
          break;
        case 'followers':
          targetUserIds = followerIds.difference(followingIds);
          break;
        case 'following':
          targetUserIds = followingIds.difference(followerIds);
          break;
        default:
          return [];
      }
      if (targetUserIds.isEmpty) {
        return [];
      }
      final users = <user_model.User>[];
      final chunks = _chunkList(targetUserIds.toList(), 30);
      for (final chunk in chunks) {
        final usersQuery = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        users.addAll(usersQuery.docs.map(_userFromDoc));
      }
      return users;
    } catch (e) {
      debugPrint('❌ FollowsService: Error getting users for tab $tab: $e');
      return [];
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    try {
      final primary = await _firestore
          .collection('follows')
          .where('followerUserId', isEqualTo: currentUser.uid)
          .where('targetUserId', isEqualTo: targetUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (primary.docs.isNotEmpty) return true;
      final legacy = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: targetUserId)
          .limit(1)
          .get();
      if (legacy.docs.isNotEmpty) return true;
      final legacyAlt = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followedId', isEqualTo: targetUserId)
          .limit(1)
          .get();
      return legacyAlt.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ FollowsService: Error checking follow status: $e');
      return false;
    }
  }

  Future<bool> isFollowedBy(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    try {
      final primary = await _firestore
          .collection('follows')
          .where('followerUserId', isEqualTo: targetUserId)
          .where('targetUserId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (primary.docs.isNotEmpty) return true;
      final legacy = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: targetUserId)
          .where('followingId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      if (legacy.docs.isNotEmpty) return true;
      final legacyAlt = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: targetUserId)
          .where('followedId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      return legacyAlt.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ FollowsService: Error checking follow status: $e');
      return false;
    }
  }

  Future<bool> isMutualFollow(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    try {
      final a = await isFollowing(targetUserId);
      if (!a) return false;
      final b = await isFollowedBy(targetUserId);
      return b;
    } catch (e) {
      debugPrint('❌ FollowsService: Error checking mutual follow: $e');
      return false;
    }
  }

  Stream<List<user_model.User>> getUsersStreamForTab(String tab) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    final userId = currentUser.uid;
    final s1 = _firestore
        .collection('follows')
        .where('followerUserId', isEqualTo: userId)
        .snapshots()
        .asyncMap((_) => getUsersForTab(tab));
    final s2 = _firestore
        .collection('follows')
        .where('targetUserId', isEqualTo: userId)
        .snapshots()
        .asyncMap((_) => getUsersForTab(tab));
    return _mergeStreams(s1, s2);
  }

  static Stream<T> _mergeStreams<T>(Stream<T> s1, Stream<T> s2) {
    final controller = StreamController<T>.broadcast();
    var completed = 0;
    late StreamSubscription<T> sub1;
    late StreamSubscription<T> sub2;
    void onDone() {
      completed++;
      if (completed == 2) {
        controller.close();
      }
    }
    sub1 = s1.listen(
      controller.add,
      onError: controller.addError,
      onDone: onDone,
    );
    sub2 = s2.listen(
      controller.add,
      onError: controller.addError,
      onDone: onDone,
    );
    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };
    return controller.stream;
  }

  user_model.User _userFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final merged = {...data, 'id': data['id'] ?? doc.id};
    return user_model.User.fromMap(merged);
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }
}
