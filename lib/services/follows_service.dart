import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart' as user_model;
import 'event_trigger_service.dart';
import '../features/gamification/emit_engagement_gamification.dart';
import '../features/gamification/gamification_event_types.dart';
import 'progression_service.dart';

import '../models/user_count_fields.dart';

class FollowCounts {
  const FollowCounts({
    required this.followersCount,
    required this.followingCount,
    required this.connectionsCount,
  });

  final int followersCount;
  final int followingCount;
  final int connectionsCount;
}

class _FollowIdSets {
  const _FollowIdSets({
    required this.followerIds,
    required this.followingIds,
  });

  final Set<String> followerIds;
  final Set<String> followingIds;
}

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
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }
    if (currentUser.uid == targetUserId) {
      debugPrint('❌ FollowsService: Cannot follow yourself');
      return false;
    }
    try {
      final String currentUserId = currentUser.uid;
      final DocumentReference<Map<String, dynamic>> followerEdgeRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      final DocumentSnapshot<Map<String, dynamic>> existingEdge =
          await followerEdgeRef.get();
      if (existingEdge.exists) {
        return true;
      }
      await _ensureCounterFields(currentUserId);
      await _ensureCounterFields(targetUserId);
      final Map<String, DocumentReference<Map<String, dynamic>>> legacyRefs =
          await _queryLegacyFollowReferences(currentUserId, targetUserId);
      final DocumentReference<Map<String, dynamic>> currentUserRef =
          _firestore.collection('users').doc(currentUserId);
      final DocumentReference<Map<String, dynamic>> targetUserRef =
          _firestore.collection('users').doc(targetUserId);
      final DocumentReference<Map<String, dynamic>> followingEdgeRef =
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('following')
              .doc(targetUserId);
      final DocumentReference<Map<String, dynamic>> canonicalFollowRef =
          _firestore
              .collection('follows')
              .doc('${currentUserId}_$targetUserId');
      bool shouldTriggerFollowEvent = false;
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> followerSnap =
            await transaction.get(followerEdgeRef);
        if (followerSnap.exists) {
          return;
        }
        final DocumentSnapshot<Map<String, dynamic>> currentSnap =
            await transaction.get(currentUserRef);
        final DocumentSnapshot<Map<String, dynamic>> targetSnap =
            await transaction.get(targetUserRef);
        bool anyLegacy = false;
        for (final DocumentReference<Map<String, dynamic>> ref
            in legacyRefs.values) {
          final DocumentSnapshot<Map<String, dynamic>> leg =
              await transaction.get(ref);
          if (leg.exists) {
            anyLegacy = true;
            break;
          }
        }
        transaction.set(followerEdgeRef, <String, dynamic>{
          'userId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(followingEdgeRef, <String, dynamic>{
          'userId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          canonicalFollowRef,
          <String, dynamic>{
            'followerUserId': currentUserId,
            'targetUserId': targetUserId,
            'followerId': currentUserId,
            'followingId': targetUserId,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        if (!anyLegacy) {
          shouldTriggerFollowEvent = true;
          final int nextFollowers =
              _readCounter(targetSnap, 'followerCount') + 1;
          final int aligned = math.max(0, nextFollowers);
          transaction.update(targetUserRef, <String, dynamic>{
            'followerCount': aligned,
            'followersCount': aligned,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final int nextFollowing =
              _readCounter(currentSnap, 'followingCount') + 1;
          transaction.update(currentUserRef, <String, dynamic>{
            'followingCount': math.max(0, nextFollowing),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (shouldTriggerFollowEvent && _eventTriggerService != null) {
        await _eventTriggerService!.triggerFollowEvent(
          followerId: currentUserId,
          followingId: targetUserId,
        );
      }
      scheduleEngagementGamificationEvent(
        type: GamificationEventTypes.engagementFollowCreated,
        entityType: 'user',
        entityId: targetUserId,
        source: 'connections',
      );
      unawaited(ProgressionService.instance.markTaskCompleted(
        currentUserId,
        ProgressionTaskIds.firstConnectionMade,
        source: 'connections',
      ));
      return true;
    } catch (e) {
      debugPrint('❌ FollowsService: Error following user: $e');
      return false;
    }
  }

  Future<bool> unfollowUser(String targetUserId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }
    try {
      final String currentUserId = currentUser.uid;
      await _ensureCounterFields(currentUserId);
      await _ensureCounterFields(targetUserId);
      final DocumentReference<Map<String, dynamic>> followerEdgeRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      final DocumentReference<Map<String, dynamic>> followingEdgeRef =
          _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('following')
              .doc(targetUserId);
      final Map<String, DocumentReference<Map<String, dynamic>>> legacyRefs =
          await _queryLegacyFollowReferences(currentUserId, targetUserId);
      final DocumentSnapshot<Map<String, dynamic>> followerPre =
          await followerEdgeRef.get();
      final DocumentSnapshot<Map<String, dynamic>> followingPre =
          await followingEdgeRef.get();
      if (!followerPre.exists && !followingPre.exists && legacyRefs.isEmpty) {
        return true;
      }
      final DocumentReference<Map<String, dynamic>> currentUserRef =
          _firestore.collection('users').doc(currentUserId);
      final DocumentReference<Map<String, dynamic>> targetUserRef =
          _firestore.collection('users').doc(targetUserId);
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> followerSnap =
            await transaction.get(followerEdgeRef);
        final DocumentSnapshot<Map<String, dynamic>> followingSnap =
            await transaction.get(followingEdgeRef);
        final DocumentSnapshot<Map<String, dynamic>> currentSnap =
            await transaction.get(currentUserRef);
        final DocumentSnapshot<Map<String, dynamic>> targetSnap =
            await transaction.get(targetUserRef);
        final List<DocumentReference<Map<String, dynamic>>> legacyRefList =
            legacyRefs.values.toList();
        final List<DocumentSnapshot<Map<String, dynamic>>> legacySnaps =
            <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final DocumentReference<Map<String, dynamic>> ref
            in legacyRefList) {
          legacySnaps.add(await transaction.get(ref));
        }
        final bool anyLegacy = legacySnaps
            .any((DocumentSnapshot<Map<String, dynamic>> s) => s.exists);
        final bool hadRelationship =
            followerSnap.exists || followingSnap.exists || anyLegacy;
        if (!hadRelationship) {
          return;
        }
        if (followerSnap.exists) {
          transaction.delete(followerEdgeRef);
        }
        if (followingSnap.exists) {
          transaction.delete(followingEdgeRef);
        }
        for (var i = 0; i < legacyRefList.length; i++) {
          if (legacySnaps[i].exists) {
            transaction.delete(legacyRefList[i]);
          }
        }
        final int curFollow = _readCounter(targetSnap, 'followerCount');
        final int nextFollow = math.max(0, curFollow - 1);
        transaction.update(targetUserRef, <String, dynamic>{
          'followerCount': nextFollow,
          'followersCount': nextFollow,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final int curFollowing = _readCounter(currentSnap, 'followingCount');
        transaction.update(currentUserRef, <String, dynamic>{
          'followingCount': math.max(0, curFollowing - 1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (e) {
      debugPrint('❌ FollowsService: Error unfollowing user: $e');
      return false;
    }
  }

  Future<bool> removeFollower(String followerUserId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }
    if (currentUser.uid == followerUserId) {
      return false;
    }
    try {
      await _deleteFollowEdge(
        followerUserId: followerUserId,
        targetUserId: currentUser.uid,
        decrementCounters: true,
      );
      return true;
    } catch (e) {
      debugPrint('❌ FollowsService: Error removing follower: $e');
      return false;
    }
  }

  Future<bool> removeRelationshipBothWays(String otherUserId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return false;
    }
    if (currentUser.uid == otherUserId) {
      return false;
    }
    try {
      await _deleteFollowEdge(
        followerUserId: currentUser.uid,
        targetUserId: otherUserId,
        decrementCounters: true,
      );
      await _deleteFollowEdge(
        followerUserId: otherUserId,
        targetUserId: currentUser.uid,
        decrementCounters: true,
      );
      return true;
    } catch (e) {
      debugPrint('❌ FollowsService: Error removing relationship: $e');
      return false;
    }
  }

  Future<void> _deleteFollowEdge({
    required String followerUserId,
    required String targetUserId,
    required bool decrementCounters,
  }) async {
    await _ensureCounterFields(followerUserId);
    await _ensureCounterFields(targetUserId);
    final followerEdgeRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(followerUserId);
    final followingEdgeRef = _firestore
        .collection('users')
        .doc(followerUserId)
        .collection('following')
        .doc(targetUserId);
    final legacyRefs =
        await _queryLegacyFollowReferences(followerUserId, targetUserId);
    final followerUserRef = _firestore.collection('users').doc(followerUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    await _firestore.runTransaction<void>((transaction) async {
      final followerSnap = await transaction.get(followerEdgeRef);
      final followingSnap = await transaction.get(followingEdgeRef);
      final followerUserSnap = await transaction.get(followerUserRef);
      final targetUserSnap = await transaction.get(targetUserRef);
      final legacyRefList = legacyRefs.values.toList();
      final legacySnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in legacyRefList) {
        legacySnaps.add(await transaction.get(ref));
      }
      final hadRelationship = followerSnap.exists ||
          followingSnap.exists ||
          legacySnaps.any((snapshot) => snapshot.exists);
      if (!hadRelationship) return;

      if (followerSnap.exists) transaction.delete(followerEdgeRef);
      if (followingSnap.exists) transaction.delete(followingEdgeRef);
      for (var i = 0; i < legacyRefList.length; i++) {
        if (legacySnaps[i].exists) {
          transaction.delete(legacyRefList[i]);
        }
      }

      if (decrementCounters) {
        final nextFollowers =
            math.max(0, _readCounter(targetUserSnap, 'followerCount') - 1);
        transaction.update(targetUserRef, <String, dynamic>{
          'followerCount': nextFollowers,
          'followersCount': nextFollowers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final nextFollowing =
            math.max(0, _readCounter(followerUserSnap, 'followingCount') - 1);
        transaction.update(followerUserRef, <String, dynamic>{
          'followingCount': nextFollowing,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  int _readCounter(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String field,
  ) {
    final value = snapshot.data()?[field];
    return value is num ? value.toInt().clamp(0, 1 << 31).toInt() : 0;
  }

  Future<Map<String, DocumentReference<Map<String, dynamic>>>>
      _queryLegacyFollowReferences(
    String followerUserId,
    String targetUserId,
  ) async {
    final CollectionReference<Map<String, dynamic>> follows =
        _firestore.collection('follows');
    final QuerySnapshot<Map<String, dynamic>> primary = await follows
        .where('followerUserId', isEqualTo: followerUserId)
        .where('targetUserId', isEqualTo: targetUserId)
        .get();
    final QuerySnapshot<Map<String, dynamic>> legacy = await follows
        .where('followerId', isEqualTo: followerUserId)
        .where('followingId', isEqualTo: targetUserId)
        .get();
    final QuerySnapshot<Map<String, dynamic>> legacyAlt = await follows
        .where('followerId', isEqualTo: followerUserId)
        .where('followedId', isEqualTo: targetUserId)
        .get();
    final Map<String, DocumentReference<Map<String, dynamic>>> out =
        <String, DocumentReference<Map<String, dynamic>>>{};
    void addSnap(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        out[doc.reference.path] = doc.reference;
      }
    }

    addSnap(primary);
    addSnap(legacy);
    addSnap(legacyAlt);
    final DocumentReference<Map<String, dynamic>> canonical =
        follows.doc('${followerUserId}_$targetUserId');
    final DocumentSnapshot<Map<String, dynamic>> canSnap =
        await canonical.get();
    if (canSnap.exists) {
      out[canonical.path] = canonical;
    }
    return out;
  }

  Future<void> _ensureCounterFields(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      final data = userDoc.data()!;
      final updates = <String, dynamic>{};
      if (!data.containsKey('followingCount')) updates['followingCount'] = 0;
      if (!data.containsKey('connectionsCount')) {
        updates['connectionsCount'] = 0;
      }
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
      final idSets = await _loadFollowIdSets(currentUser.uid);
      Set<String> targetUserIds;
      switch (tab) {
        case 'connections':
          targetUserIds = idSets.followingIds.intersection(idSets.followerIds);
          break;
        case 'followers':
          targetUserIds = idSets.followerIds.difference(idSets.followingIds);
          break;
        case 'following':
          targetUserIds = idSets.followingIds.difference(idSets.followerIds);
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

  Future<FollowCounts> getFollowCountsForCurrentUser() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const FollowCounts(
        followersCount: 0,
        followingCount: 0,
        connectionsCount: 0,
      );
    }
    return getFollowCountsForUser(currentUser.uid);
  }

  Future<FollowCounts> getFollowCountsForUser(String userId) async {
    try {
      final _FollowIdSets idSets = await _loadFollowIdSets(userId);
      return FollowCounts(
        followersCount: idSets.followerIds.length,
        followingCount: idSets.followingIds.length,
        connectionsCount:
            idSets.followerIds.intersection(idSets.followingIds).length,
      );
    } catch (e) {
      debugPrint('❌ FollowsService: Error counting follows for $userId: $e');
      return const FollowCounts(
        followersCount: 0,
        followingCount: 0,
        connectionsCount: 0,
      );
    }
  }

  Future<void> repairFollowCountersForUser(String userId) async {
    try {
      final FollowCounts counts = await getFollowCountsForUser(userId);
      final DocumentReference<Map<String, dynamic>> userRef =
          _firestore.collection('users').doc(userId);
      final DocumentSnapshot<Map<String, dynamic>> snap = await userRef.get();
      if (!snap.exists || snap.data() == null) {
        return;
      }
      final Map<String, dynamic> data = snap.data()!;
      final int storedFollowers = UserCountFields.readFollowersCount(data);
      final int storedFollowing = UserCountFields.readFollowingCount(data);
      if (storedFollowers == counts.followersCount &&
          storedFollowing == counts.followingCount) {
        return;
      }
      await userRef.update(<String, dynamic>{
        ...UserCountFields.writeCanonicalCounts(
          followersCount: counts.followersCount,
          followingCount: counts.followingCount,
          connectionsCount: counts.connectionsCount,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        '✅ FollowsService: Repaired counters for $userId '
        '(followers ${counts.followersCount}, following ${counts.followingCount})',
      );
    } catch (e) {
      debugPrint('❌ FollowsService: Error repairing counters for $userId: $e');
    }
  }

  Future<_FollowIdSets> _loadFollowIdSets(String currentUserId) async {
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
    String? readFollowerId(Map<String, dynamic> data) {
      final val = data['followerUserId'] ??
          data['followerId'] ??
          data['follower'] ??
          data['follower_id'];
      return val is String ? val : null;
    }

    String? readFollowingId(Map<String, dynamic> data) {
      final val = data['targetUserId'] ??
          data['followingId'] ??
          data['followedId'] ??
          data['target_user_id'];
      return val is String ? val : null;
    }

    bool isActiveFollowDoc(Map<String, dynamic> data) {
      if (!data.containsKey('isActive')) return true;
      final val = data['isActive'];
      if (val is bool) return val;
      return true;
    }

    final followerIds = <String>{};
    for (final doc in followersPrimary.docs) {
      final data = doc.data();
      if (!isActiveFollowDoc(data)) continue;
      final id = readFollowerId(data);
      if (id != null && id.isNotEmpty) followerIds.add(id);
    }
    for (final doc in [...followersLegacy1.docs, ...followersLegacy2.docs]) {
      final data = doc.data();
      if (!isActiveFollowDoc(data)) continue;
      final id = readFollowerId(data);
      if (id != null && id.isNotEmpty) followerIds.add(id);
    }
    final followingIds = <String>{};
    for (final doc in followingPrimary.docs) {
      final data = doc.data();
      if (!isActiveFollowDoc(data)) continue;
      final id = readFollowingId(data);
      if (id != null && id.isNotEmpty) followingIds.add(id);
    }
    for (final doc in followingLegacy.docs) {
      final data = doc.data();
      if (!isActiveFollowDoc(data)) continue;
      final id = readFollowingId(data);
      if (id != null && id.isNotEmpty) followingIds.add(id);
    }
    return _FollowIdSets(
      followerIds: followerIds,
      followingIds: followingIds,
    );
  }

  Future<bool> isFollowing(String targetUserId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    try {
      final DocumentSnapshot<Map<String, dynamic>> edge = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid)
          .get();
      if (edge.exists) return true;
      final QuerySnapshot<Map<String, dynamic>> primary = await _firestore
          .collection('follows')
          .where('followerUserId', isEqualTo: currentUser.uid)
          .where('targetUserId', isEqualTo: targetUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (primary.docs.isNotEmpty) return true;
      final QuerySnapshot<Map<String, dynamic>> legacy = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: targetUserId)
          .limit(1)
          .get();
      if (legacy.docs.isNotEmpty) return true;
      final QuerySnapshot<Map<String, dynamic>> legacyAlt = await _firestore
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
