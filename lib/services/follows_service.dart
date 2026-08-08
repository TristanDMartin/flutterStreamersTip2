import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart' as user_model;
import '../features/gamification/emit_engagement_gamification.dart';
import '../features/gamification/gamification_event_types.dart';
import '../models/user_privacy_settings.dart';
import 'privacy_settings_service.dart';
import 'progression_service.dart';

import '../models/user_count_fields.dart';
import 'public_profile_firestore.dart';

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

/// Batched network tab payload — one follow-id load, three user lists.
class NetworkTabUsers {
  const NetworkTabUsers({
    required this.connections,
    required this.followers,
    required this.following,
    required this.counts,
    this.hasMoreFollowGraph = false,
  });

  final List<user_model.User> connections;
  final List<user_model.User> followers;
  final List<user_model.User> following;
  final FollowCounts counts;
  final bool hasMoreFollowGraph;
}

class _FollowIdSets {
  const _FollowIdSets({
    required this.followerIds,
    required this.followingIds,
  });

  final Set<String> followerIds;
  final Set<String> followingIds;
}

class _FollowGraphPageResult {
  const _FollowGraphPageResult({
    required this.idSets,
    required this.hasMore,
  });

  final _FollowIdSets idSets;
  final bool hasMore;
}

class _FollowPaginationState {
  DocumentSnapshot<Map<String, dynamic>>? followersPrimaryCursor;
  DocumentSnapshot<Map<String, dynamic>>? followersLegacy1Cursor;
  DocumentSnapshot<Map<String, dynamic>>? followersLegacy2Cursor;
  DocumentSnapshot<Map<String, dynamic>>? followingPrimaryCursor;
  DocumentSnapshot<Map<String, dynamic>>? followingLegacyCursor;

  bool followersPrimaryExhausted = false;
  bool followersLegacy1Exhausted = false;
  bool followersLegacy2Exhausted = false;
  bool followingPrimaryExhausted = false;
  bool followingLegacyExhausted = false;

  void reset() {
    followersPrimaryCursor = null;
    followersLegacy1Cursor = null;
    followersLegacy2Cursor = null;
    followingPrimaryCursor = null;
    followingLegacyCursor = null;
    followersPrimaryExhausted = false;
    followersLegacy1Exhausted = false;
    followersLegacy2Exhausted = false;
    followingPrimaryExhausted = false;
    followingLegacyExhausted = false;
  }

  bool get hasMore =>
      !followersPrimaryExhausted ||
      !followersLegacy1Exhausted ||
      !followersLegacy2Exhausted ||
      !followingPrimaryExhausted ||
      !followingLegacyExhausted;
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

  _FollowIdSets? _cachedIdSets;
  String? _cachedIdSetsUserId;
  DateTime? _cachedIdSetsAt;
  NetworkTabUsers? _cachedNetworkTabUsers;
  String? _cachedNetworkTabUsersUserId;
  static bool migrationCheckedThisSession = false;
  static const Duration _followIdSetsCacheTtl = Duration(seconds: 45);
  static const int _followQueryPageSize = 100;
  static const int _networkDiskCacheMaxPerList = 80;
  static const String _networkDiskCacheKeyPrefix = 'network_tab_users_v1_';
  final Map<String, _FollowPaginationState> _paginationByUserId =
      <String, _FollowPaginationState>{};

  @visibleForTesting
  static void debugSetOverrides({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    _firestoreOverride = firestore;
    _authOverride = auth;
    _instance.clearNetworkTabUsersCache();
  }

  void invalidateFollowIdSetsCache() {
    _cachedIdSets = null;
    _cachedIdSetsUserId = null;
    _cachedIdSetsAt = null;
    _paginationByUserId.clear();
  }

  /// Drop in-memory network lists (e.g. on sign-out). Disk cache is cleared
  /// for the signed-in user when [userId] is provided.
  void clearNetworkTabUsersCache({String? userId}) {
    _cachedNetworkTabUsers = null;
    _cachedNetworkTabUsersUserId = null;
    invalidateFollowIdSetsCache();
    if (userId == null || userId.isEmpty) {
      return;
    }
    unawaited(() async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_networkDiskCacheKeyPrefix$userId');
      } catch (_) {}
    }());
  }

  /// Synchronous memory peek for instant NetworkView paint.
  NetworkTabUsers? peekCachedNetworkTabUsers({String? userId}) {
    final String? uid = userId ?? _auth.currentUser?.uid;
    if (uid == null ||
        uid.isEmpty ||
        _cachedNetworkTabUsers == null ||
        _cachedNetworkTabUsersUserId != uid) {
      return null;
    }
    return _cachedNetworkTabUsers;
  }

  /// Disk hydrate for cold start before Firestore returns.
  Future<NetworkTabUsers?> loadCachedNetworkTabUsersFromDisk({
    String? userId,
  }) async {
    final String? uid = userId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return null;
    }
    final NetworkTabUsers? memory = peekCachedNetworkTabUsers(userId: uid);
    if (memory != null) {
      return memory;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('$_networkDiskCacheKeyPrefix$uid');
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final NetworkTabUsers bundle = _networkTabUsersFromCacheMap(decoded);
      _cachedNetworkTabUsers = bundle;
      _cachedNetworkTabUsersUserId = uid;
      return bundle;
    } catch (e) {
      debugPrint('⚠️ FollowsService: disk network cache read failed: $e');
      return null;
    }
  }

  void _rememberNetworkTabUsers(String userId, NetworkTabUsers bundle) {
    _cachedNetworkTabUsers = bundle;
    _cachedNetworkTabUsersUserId = userId;
    unawaited(_persistNetworkTabUsers(userId, bundle));
  }

  Future<void> _persistNetworkTabUsers(
    String userId,
    NetworkTabUsers bundle,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_networkTabUsersToCacheMap(bundle));
      await prefs.setString('$_networkDiskCacheKeyPrefix$userId', encoded);
    } catch (e) {
      debugPrint('⚠️ FollowsService: disk network cache write failed: $e');
    }
  }

  Map<String, dynamic> _networkTabUsersToCacheMap(NetworkTabUsers bundle) {
    List<Map<String, dynamic>> slim(List<user_model.User> users) {
      return users
          .take(_networkDiskCacheMaxPerList)
          .map(_slimUserCacheMap)
          .toList(growable: false);
    }

    return <String, dynamic>{
      'connections': slim(bundle.connections),
      'followers': slim(bundle.followers),
      'following': slim(bundle.following),
      'counts': <String, dynamic>{
        'followersCount': bundle.counts.followersCount,
        'followingCount': bundle.counts.followingCount,
        'connectionsCount': bundle.counts.connectionsCount,
      },
      'hasMoreFollowGraph': bundle.hasMoreFollowGraph,
    };
  }

  NetworkTabUsers _networkTabUsersFromCacheMap(Map<String, dynamic> map) {
    List<user_model.User> parseUsers(Object? raw) {
      if (raw is! List) {
        return <user_model.User>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (Map item) => user_model.User.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    final Map<String, dynamic> countsMap =
        map['counts'] is Map<String, dynamic>
            ? map['counts'] as Map<String, dynamic>
            : <String, dynamic>{};
    return NetworkTabUsers(
      connections: parseUsers(map['connections']),
      followers: parseUsers(map['followers']),
      following: parseUsers(map['following']),
      counts: FollowCounts(
        followersCount: (countsMap['followersCount'] as num?)?.toInt() ?? 0,
        followingCount: (countsMap['followingCount'] as num?)?.toInt() ?? 0,
        connectionsCount:
            (countsMap['connectionsCount'] as num?)?.toInt() ?? 0,
      ),
      hasMoreFollowGraph: map['hasMoreFollowGraph'] == true,
    );
  }

  Map<String, dynamic> _slimUserCacheMap(user_model.User user) {
    return <String, dynamic>{
      'id': user.id,
      'username': user.username,
      'displayName': user.displayName,
      'bio': user.bio,
      'avatarURL': user.avatarURL,
      'postCount': user.postCount,
      'followerCount': user.followerCount,
      'followingCount': user.followingCount,
      'creatorActivity': user.creatorActivity.toMap(),
      'activityPrivacy': user.activityPrivacy.toMap(),
    };
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
      await PrivacySettingsService.instance.assertCanFollow(
        followerId: currentUser.uid,
        targetUserId: targetUserId,
      );
    } on PrivacySettingsBlockedException {
      rethrow;
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
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> followerSnap =
            await transaction.get(followerEdgeRef);
        if (followerSnap.exists) {
          return;
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
        // Counter SoT + Activity notification: Cloud Function onFollowCreate
        // (users + publicUsers counters, notifications/{uid}/items write).
      });
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
      invalidateFollowIdSetsCache();
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
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> followerSnap =
            await transaction.get(followerEdgeRef);
        final DocumentSnapshot<Map<String, dynamic>> followingSnap =
            await transaction.get(followingEdgeRef);
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
        // Counter SoT: Cloud Function onFollowDelete (users + publicUsers).
      });
      invalidateFollowIdSetsCache();
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
      );
      invalidateFollowIdSetsCache();
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
      );
      await _deleteFollowEdge(
        followerUserId: otherUserId,
        targetUserId: currentUser.uid,
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

    await _firestore.runTransaction<void>((transaction) async {
      final followerSnap = await transaction.get(followerEdgeRef);
      final followingSnap = await transaction.get(followingEdgeRef);
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
      // Counter SoT: Cloud Function onFollowDelete (users + publicUsers).
    });
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
    final NetworkTabUsers bundle = await loadNetworkTabUsers();
    switch (tab) {
      case 'connections':
        return bundle.connections;
      case 'followers':
        return bundle.followers;
      case 'following':
        return bundle.following;
      default:
        return <user_model.User>[];
    }
  }

  /// Loads connections, followers, and following with a single follow-id fetch.
  Future<NetworkTabUsers> loadNetworkTabUsers({
    bool forceRefresh = false,
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ FollowsService: No current user');
      return const NetworkTabUsers(
        connections: <user_model.User>[],
        followers: <user_model.User>[],
        following: <user_model.User>[],
        counts: FollowCounts(
          followersCount: 0,
          followingCount: 0,
          connectionsCount: 0,
        ),
      );
    }
    if (!forceRefresh) {
      final NetworkTabUsers? memory =
          peekCachedNetworkTabUsers(userId: currentUser.uid);
      if (memory != null &&
          _cachedIdSetsUserId == currentUser.uid &&
          _cachedIdSets != null &&
          _cachedIdSetsAt != null &&
          DateTime.now().difference(_cachedIdSetsAt!) < _followIdSetsCacheTtl) {
        return memory;
      }
    }
    try {
      final _FollowGraphPageResult graph = await _loadFollowIdSets(
        currentUser.uid,
        forceRefresh: forceRefresh,
      );
      final NetworkTabUsers bundle = await _buildNetworkTabUsersFromIdSets(
        currentUser.uid,
        graph.idSets,
        hasMoreFollowGraph: graph.hasMore,
      );
      _rememberNetworkTabUsers(currentUser.uid, bundle);
      return bundle;
    } catch (e) {
      debugPrint('❌ FollowsService: Error loading network tabs: $e');
      final NetworkTabUsers? stale =
          peekCachedNetworkTabUsers(userId: currentUser.uid);
      if (stale != null) {
        return stale;
      }
      return const NetworkTabUsers(
        connections: <user_model.User>[],
        followers: <user_model.User>[],
        following: <user_model.User>[],
        counts: FollowCounts(
          followersCount: 0,
          followingCount: 0,
          connectionsCount: 0,
        ),
      );
    }
  }

  /// Fetches the next page of follow edges when the graph is larger than
  /// [_followQueryPageSize] per query lane.
  Future<NetworkTabUsers> loadMoreNetworkTabUsers() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const NetworkTabUsers(
        connections: <user_model.User>[],
        followers: <user_model.User>[],
        following: <user_model.User>[],
        counts: FollowCounts(
          followersCount: 0,
          followingCount: 0,
          connectionsCount: 0,
        ),
      );
    }
    final _FollowPaginationState? pagination =
        _paginationByUserId[currentUser.uid];
    if (pagination == null || !pagination.hasMore) {
      return loadNetworkTabUsers();
    }
    try {
      final _FollowGraphPageResult graph = await _loadFollowIdSets(
        currentUser.uid,
        loadMore: true,
      );
      final NetworkTabUsers bundle = await _buildNetworkTabUsersFromIdSets(
        currentUser.uid,
        graph.idSets,
        hasMoreFollowGraph: graph.hasMore,
      );
      _rememberNetworkTabUsers(currentUser.uid, bundle);
      return bundle;
    } catch (e) {
      debugPrint('❌ FollowsService: Error loading more network tabs: $e');
      return loadNetworkTabUsers();
    }
  }

  Future<NetworkTabUsers> _buildNetworkTabUsersFromIdSets(
    String userId,
    _FollowIdSets idSets, {
    required bool hasMoreFollowGraph,
  }) async {
    final Set<String> resolvedFollowers =
        await _filterExistingUserIds(idSets.followerIds);
    final Set<String> resolvedFollowing =
        await _filterExistingUserIds(idSets.followingIds);
    final Set<String> connectionIds =
        resolvedFollowing.intersection(resolvedFollowers);
    final Set<String> followerTabIds =
        resolvedFollowers.difference(resolvedFollowing);
    final Set<String> followingTabIds =
        resolvedFollowing.difference(resolvedFollowers);
    final List<user_model.User> connections = await _usersForIds(connectionIds);
    final List<user_model.User> followers = await _usersForIds(followerTabIds);
    final List<user_model.User> following = await _usersForIds(followingTabIds);
    final FollowCounts computedCounts = FollowCounts(
      followersCount: resolvedFollowers.length,
      followingCount: resolvedFollowing.length,
      connectionsCount: connectionIds.length,
    );
    final FollowCounts counts = hasMoreFollowGraph
        ? (await _tryReadFollowCountsFromUserDoc(userId)) ?? computedCounts
        : computedCounts;
    return NetworkTabUsers(
      connections: connections,
      followers: followers,
      following: following,
      counts: counts,
      hasMoreFollowGraph: hasMoreFollowGraph,
    );
  }

  Future<FollowCounts?> _tryReadFollowCountsFromUserDoc(String userId) async {
    try {
      final Map<String, dynamic>? data =
          await PublicProfileFirestore.instance.getProfileMap(userId);
      if (data == null) {
        return null;
      }
      final int followersCount = UserCountFields.readFollowersCount(data);
      final int followingCount = UserCountFields.readFollowingCount(data);
      int connectionsCount = UserCountFields.readConnectionsCount(data);
      if (connectionsCount <= 0 && followersCount > 0 && followingCount > 0) {
        connectionsCount = math.min(followersCount, followingCount);
      }
      return FollowCounts(
        followersCount: followersCount,
        followingCount: followingCount,
        connectionsCount: connectionsCount,
      );
    } catch (e) {
      debugPrint(
          '⚠️ FollowsService: Unable to read doc counts for $userId: $e');
      return null;
    }
  }

  Future<List<user_model.User>> _usersForIds(Set<String> targetUserIds) async {
    if (targetUserIds.isEmpty) {
      return <user_model.User>[];
    }
    final Map<String, Map<String, dynamic>> maps =
        await PublicProfileFirestore.instance.getProfileMaps(targetUserIds);
    return maps.entries.map((MapEntry<String, Map<String, dynamic>> e) {
      return user_model.User.fromMap(e.value);
    }).toList();
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
      if (_auth.currentUser?.uid == userId) {
        final FollowCounts? docCounts =
            await _tryReadFollowCountsFromUserDoc(userId);
        if (docCounts != null &&
            (_paginationByUserId[userId]?.hasMore ?? false)) {
          return docCounts;
        }
        final NetworkTabUsers bundle = await loadNetworkTabUsers();
        return bundle.counts;
      }
      final _FollowGraphPageResult graph = await _loadFollowIdSets(userId);
      final Set<String> resolvedFollowers =
          await _filterExistingUserIds(graph.idSets.followerIds);
      final Set<String> resolvedFollowing =
          await _filterExistingUserIds(graph.idSets.followingIds);
      return FollowCounts(
        followersCount: resolvedFollowers.length,
        followingCount: resolvedFollowing.length,
        connectionsCount:
            resolvedFollowers.intersection(resolvedFollowing).length,
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
      final Map<String, dynamic> payload = <String, dynamic>{
        ...UserCountFields.writeCanonicalCounts(
          followersCount: counts.followersCount,
          followingCount: counts.followingCount,
          connectionsCount: counts.connectionsCount,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final DocumentReference<Map<String, dynamic>> userRef =
          _firestore.collection('users').doc(userId);
      final DocumentSnapshot<Map<String, dynamic>> snap = await userRef.get();
      if (snap.exists && snap.data() != null) {
        final Map<String, dynamic> data = snap.data()!;
        final int storedFollowers = UserCountFields.readFollowersCount(data);
        final int storedFollowing = UserCountFields.readFollowingCount(data);
        if (storedFollowers != counts.followersCount ||
            storedFollowing != counts.followingCount) {
          await userRef.update(payload);
        }
      }
      // Always mirror onto publicUsers (peer / streamer reads).
      await _firestore.collection('publicUsers').doc(userId).set(
            payload,
            SetOptions(merge: true),
          );
      debugPrint(
        '✅ FollowsService: Repaired counters for $userId '
        '(followers ${counts.followersCount}, following ${counts.followingCount})',
      );
    } catch (e) {
      debugPrint('❌ FollowsService: Error repairing counters for $userId: $e');
    }
  }

  Future<_FollowGraphPageResult> _loadFollowIdSets(
    String currentUserId, {
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    if (forceRefresh) {
      _paginationByUserId.remove(currentUserId);
      if (_cachedIdSetsUserId == currentUserId) {
        _cachedIdSets = null;
        _cachedIdSetsUserId = null;
        _cachedIdSetsAt = null;
      }
    }

    final _FollowPaginationState pagination = _paginationByUserId.putIfAbsent(
      currentUserId,
      _FollowPaginationState.new,
    );

    if (!forceRefresh &&
        !loadMore &&
        _cachedIdSetsUserId == currentUserId &&
        _cachedIdSets != null &&
        _cachedIdSetsAt != null &&
        DateTime.now().difference(_cachedIdSetsAt!) < _followIdSetsCacheTtl) {
      return _FollowGraphPageResult(
        idSets: _cachedIdSets!,
        hasMore: pagination.hasMore,
      );
    }

    if (loadMore && !pagination.hasMore) {
      return _FollowGraphPageResult(
        idSets: _cachedIdSets ??
            const _FollowIdSets(
              followerIds: <String>{},
              followingIds: <String>{},
            ),
        hasMore: false,
      );
    }

    final Set<String> followerIds = loadMore &&
            _cachedIdSetsUserId == currentUserId &&
            _cachedIdSets != null
        ? Set<String>.from(_cachedIdSets!.followerIds)
        : <String>{};
    final Set<String> followingIds = loadMore &&
            _cachedIdSetsUserId == currentUserId &&
            _cachedIdSets != null
        ? Set<String>.from(_cachedIdSets!.followingIds)
        : <String>{};

    if (!loadMore) {
      pagination.reset();
    }

    await Future.wait(<Future<void>>[
      _fetchFollowLanePage(
        pagination: pagination,
        targetIds: followerIds,
        exhausted: () => pagination.followersPrimaryExhausted,
        setExhausted: () => pagination.followersPrimaryExhausted = true,
        cursor: () => pagination.followersPrimaryCursor,
        setCursor: (DocumentSnapshot<Map<String, dynamic>>? value) =>
            pagination.followersPrimaryCursor = value,
        queryBuilder: () => _firestore
            .collection('follows')
            .where('targetUserId', isEqualTo: currentUserId),
        readId: _readFollowerId,
      ),
      _fetchFollowLanePage(
        pagination: pagination,
        targetIds: followerIds,
        exhausted: () => pagination.followersLegacy1Exhausted,
        setExhausted: () => pagination.followersLegacy1Exhausted = true,
        cursor: () => pagination.followersLegacy1Cursor,
        setCursor: (DocumentSnapshot<Map<String, dynamic>>? value) =>
            pagination.followersLegacy1Cursor = value,
        queryBuilder: () => _firestore
            .collection('follows')
            .where('followingId', isEqualTo: currentUserId),
        readId: _readFollowerId,
      ),
      _fetchFollowLanePage(
        pagination: pagination,
        targetIds: followerIds,
        exhausted: () => pagination.followersLegacy2Exhausted,
        setExhausted: () => pagination.followersLegacy2Exhausted = true,
        cursor: () => pagination.followersLegacy2Cursor,
        setCursor: (DocumentSnapshot<Map<String, dynamic>>? value) =>
            pagination.followersLegacy2Cursor = value,
        queryBuilder: () => _firestore
            .collection('follows')
            .where('followedId', isEqualTo: currentUserId),
        readId: _readFollowerId,
      ),
      _fetchFollowLanePage(
        pagination: pagination,
        targetIds: followingIds,
        exhausted: () => pagination.followingPrimaryExhausted,
        setExhausted: () => pagination.followingPrimaryExhausted = true,
        cursor: () => pagination.followingPrimaryCursor,
        setCursor: (DocumentSnapshot<Map<String, dynamic>>? value) =>
            pagination.followingPrimaryCursor = value,
        queryBuilder: () => _firestore
            .collection('follows')
            .where('followerUserId', isEqualTo: currentUserId),
        readId: _readFollowingId,
      ),
      _fetchFollowLanePage(
        pagination: pagination,
        targetIds: followingIds,
        exhausted: () => pagination.followingLegacyExhausted,
        setExhausted: () => pagination.followingLegacyExhausted = true,
        cursor: () => pagination.followingLegacyCursor,
        setCursor: (DocumentSnapshot<Map<String, dynamic>>? value) =>
            pagination.followingLegacyCursor = value,
        queryBuilder: () => _firestore
            .collection('follows')
            .where('followerId', isEqualTo: currentUserId),
        readId: _readFollowingId,
      ),
    ]);

    final _FollowIdSets result = _FollowIdSets(
      followerIds: followerIds,
      followingIds: followingIds,
    );
    _cachedIdSets = result;
    _cachedIdSetsUserId = currentUserId;
    _cachedIdSetsAt = DateTime.now();
    return _FollowGraphPageResult(
      idSets: result,
      hasMore: pagination.hasMore,
    );
  }

  Future<void> _fetchFollowLanePage({
    required _FollowPaginationState pagination,
    required Set<String> targetIds,
    required bool Function() exhausted,
    required VoidCallback setExhausted,
    required DocumentSnapshot<Map<String, dynamic>>? Function() cursor,
    required void Function(DocumentSnapshot<Map<String, dynamic>>? value)
        setCursor,
    required Query<Map<String, dynamic>> Function() queryBuilder,
    required String? Function(Map<String, dynamic> data) readId,
  }) async {
    if (exhausted()) {
      return;
    }
    Query<Map<String, dynamic>> query =
        queryBuilder().limit(_followQueryPageSize);
    final DocumentSnapshot<Map<String, dynamic>>? startAfter = cursor();
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if (!_isActiveFollowDoc(data)) {
        continue;
      }
      final String? id = readId(data);
      if (id != null && id.isNotEmpty) {
        targetIds.add(id);
      }
    }
    if (snapshot.docs.length < _followQueryPageSize) {
      setExhausted();
      setCursor(null);
      return;
    }
    setCursor(snapshot.docs.last);
  }

  String? _readFollowerId(Map<String, dynamic> data) {
    final dynamic val = data['followerUserId'] ??
        data['followerId'] ??
        data['follower'] ??
        data['follower_id'];
    return val is String ? val : null;
  }

  String? _readFollowingId(Map<String, dynamic> data) {
    final dynamic val = data['targetUserId'] ??
        data['followingId'] ??
        data['followedId'] ??
        data['target_user_id'];
    return val is String ? val : null;
  }

  bool _isActiveFollowDoc(Map<String, dynamic> data) {
    if (!data.containsKey('isActive')) {
      return true;
    }
    final dynamic val = data['isActive'];
    if (val is bool) {
      return val;
    }
    return true;
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
        .asyncMap((_) {
      invalidateFollowIdSetsCache();
      return getUsersForTab(tab);
    });
    final s2 = _firestore
        .collection('follows')
        .where('targetUserId', isEqualTo: userId)
        .snapshots()
        .asyncMap((_) {
      invalidateFollowIdSetsCache();
      return getUsersForTab(tab);
    });
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

  Future<Set<String>> _filterExistingUserIds(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return <String>{};
    }
    return PublicProfileFirestore.instance.filterExistingIds(userIds);
  }
}
