import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/creator_activity.dart';
import 'follows_service.dart';

/// Reads/writes `users/{uid}.creatorActivity` and `activityPrivacy`.
class CreatorActivityService {
  CreatorActivityService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FollowsService? followsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _followsService = followsService ?? FollowsService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FollowsService _followsService;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  String? get currentUid => _auth.currentUser?.uid;

  CreatorActivity parseActivity(Map<String, dynamic>? userData) {
    if (userData == null) return CreatorActivity.none();
    return CreatorActivity.fromMap(userData['creatorActivity']);
  }

  CreatorActivityPrivacy parsePrivacy(Map<String, dynamic>? userData) {
    if (userData == null) return const CreatorActivityPrivacy();
    final Object? nested = userData['activityPrivacy'];
    if (nested is Map) {
      return CreatorActivityPrivacy.fromMap(nested);
    }
    return const CreatorActivityPrivacy();
  }

  CreatorActivity effectiveActivity(
    Map<String, dynamic>? userData, {
    DateTime? now,
  }) {
    final DateTime clock = now ?? DateTime.now();
    final CreatorActivity activity = parseActivity(userData);
    if (!activity.isActiveAt(clock)) {
      return CreatorActivity.none();
    }
    return activity;
  }

  bool isCollaborationType(CreatorActivityType type) {
    return type == CreatorActivityType.lookingForCollabs ||
        type == CreatorActivityType.openToNetwork ||
        type == CreatorActivityType.editingContent ||
        type == CreatorActivityType.workingOnClips ||
        type == CreatorActivityType.streamingSoon;
  }

  bool isLiveType(CreatorActivityType type) => type == CreatorActivityType.live;

  bool isPostType(CreatorActivityType type) {
    return type == CreatorActivityType.postedToday ||
        type == CreatorActivityType.uploadedClip ||
        type == CreatorActivityType.trendingPost ||
        type == CreatorActivityType.newCreatorCard;
  }

  Future<bool> canViewerSee({
    required String ownerUid,
    required Map<String, dynamic>? ownerData,
    String? viewerUid,
    bool isConnection = false,
  }) async {
    final CreatorActivityPrivacy privacy = parsePrivacy(ownerData);
    if (privacy.hideFromEveryone) return false;
    if (!privacy.showCreatorActivity) return false;

    final CreatorActivity activity = effectiveActivity(ownerData);
    if (activity.isNone) return false;

    final String? viewer = viewerUid ?? currentUid;
    if (viewer == ownerUid) return true;

    if (privacy.connectionsOnly && !isConnection) {
      if (viewer == null) return false;
      final bool connected = await _isMutualConnection(viewer, ownerUid);
      if (!connected) return false;
    }

    if (isLiveType(activity.type) && !privacy.showLiveStatus) return false;
    if (isPostType(activity.type) && !privacy.showPostActivity) return false;
    if (isCollaborationType(activity.type) &&
        !privacy.showCollaborationStatus) {
      return false;
    }
    return true;
  }

  Future<bool> _isMutualConnection(String viewerUid, String ownerUid) async {
    if (viewerUid == ownerUid) return true;
    try {
      return await _followsService.isMutualFollow(ownerUid);
    } catch (e) {
      debugPrint('CreatorActivityService connection check: $e');
      return false;
    }
  }

  Future<void> setManualActivity({
    required CreatorActivityPreset preset,
    required Duration duration,
  }) async {
    final String? uid = currentUid;
    if (uid == null) return;
    final DateTime now = DateTime.now();
    final CreatorActivity activity = CreatorActivity(
      type: preset.type,
      label: preset.label,
      emoji: preset.emoji,
      source: CreatorActivitySource.manual,
      updatedAt: now,
      expiresAt: duration == Duration.zero ? null : now.add(duration),
      isVisible: true,
    );
    await _userRef(uid).set(
      <String, dynamic>{'creatorActivity': activity.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<void> hideActivity() async {
    final String? uid = currentUid;
    if (uid == null) return;
    await _userRef(uid).set(
      <String, dynamic>{
        'creatorActivity':
            CreatorActivity.none().copyWith(isVisible: false).toMap(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setSystemActivity(CreatorActivity activity) async {
    final String? uid = currentUid;
    if (uid == null) return;
    final CreatorActivity current =
        parseActivity((await _userRef(uid).get()).data());
    if (current.source == CreatorActivitySource.manual &&
        current.isActiveAt(DateTime.now())) {
      return;
    }
    await _userRef(uid).set(
      <String, dynamic>{'creatorActivity': activity.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<void> updateActivityPrivacy(CreatorActivityPrivacy privacy) async {
    final String? uid = currentUid;
    if (uid == null) return;
    await _userRef(uid).set(
      <String, dynamic>{'activityPrivacy': privacy.toMap()},
      SetOptions(merge: true),
    );
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('privacySettings')
        .doc('main')
        .set(
      <String, dynamic>{
        'showCreatorActivity': privacy.showCreatorActivity,
        'showLiveStatus': privacy.showLiveStatus,
        'showPostActivity': privacy.showPostActivity,
        'showCollaborationStatus': privacy.showCollaborationStatus,
        'activityConnectionsOnly': privacy.connectionsOnly,
        'hideActivityFromEveryone': privacy.hideFromEveryone,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<CreatorActivityPrivacy> loadActivityPrivacy() async {
    final String? uid = currentUid;
    if (uid == null) return const CreatorActivityPrivacy();
    final DocumentSnapshot<Map<String, dynamic>> userSnap =
        await _userRef(uid).get();
    CreatorActivityPrivacy privacy = parsePrivacy(userSnap.data());
    final DocumentSnapshot<Map<String, dynamic>> settingsSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('privacySettings')
        .doc('main')
        .get();
    if (settingsSnap.exists) {
      final Map<String, dynamic> data =
          settingsSnap.data() ?? <String, dynamic>{};
      privacy = CreatorActivityPrivacy(
        showCreatorActivity: data['showCreatorActivity'] != false,
        showLiveStatus: data['showLiveStatus'] != false,
        showPostActivity: data['showPostActivity'] != false,
        showCollaborationStatus: data['showCollaborationStatus'] != false,
        connectionsOnly: data['activityConnectionsOnly'] == true,
        hideFromEveryone: data['hideActivityFromEveryone'] == true,
      );
    }
    return privacy;
  }

  static Duration manualDurationFromChoice(String choice) {
    switch (choice) {
      case '1h':
        return const Duration(hours: 1);
      case '8h':
        return const Duration(hours: 8);
      case 'today':
        final DateTime now = DateTime.now();
        return DateTime(now.year, now.month, now.day, 23, 59, 59)
            .difference(now);
      case 'off':
        return Duration.zero;
      default:
        return const Duration(hours: 24);
    }
  }
}
