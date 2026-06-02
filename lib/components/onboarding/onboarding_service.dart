import 'package:cloud_firestore/cloud_firestore.dart';

import 'onboarding_models.dart';

class OnboardingMissionResult {
  const OnboardingMissionResult({
    required this.mission,
    required this.newXp,
    required this.newLevel,
    required this.completedLevelOne,
    required this.wasAlreadyComplete,
  });

  final OnboardingMission mission;
  final int newXp;
  final int newLevel;
  final bool completedLevelOne;
  final bool wasAlreadyComplete;
}

OnboardingMission _missionForId(String missionId) {
  for (final OnboardingMission item in levelOneMissions) {
    if (item.id == missionId) {
      return item;
    }
  }
  if (missionId == completeProfileSideMission.id) {
    return completeProfileSideMission;
  }
  throw ArgumentError('Unknown onboarding mission $missionId');
}

class OnboardingService {
  OnboardingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  Future<void> _safeUserSet(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _userRef(userId).set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  Stream<OnboardingState> watchOnboarding(String userId) {
    return _userRef(userId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              OnboardingState.fromUserMap(snapshot.data()),
        )
        .distinct();
  }

  Future<OnboardingState> fetchOnboarding(String userId) async {
    final snapshot = await _userRef(userId).get();
    return OnboardingState.fromUserMap(snapshot.data());
  }

  Future<void> resetForDeveloperTesterInstall(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'hasSeenIntro': false,
          'hasCompletedProductTour': false,
          'hasCompletedOnboarding': false,
          'hasCompletedLevelOne': false,
          'currentOnboardingStep': 0,
          'creatorGoal': null,
          'completedMissions': <String>[],
          'skippedSteps': <String>[],
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        'hasCompletedOnboarding': false,
        'xp': 0,
        'level': 1,
        'creatorStatus': CreatorStatus.newCreator.value,
      },
    );
  }

  Future<void> completeIntro(String userId, String creatorGoal) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'hasSeenIntro': true,
          'currentOnboardingStep': 0,
          'creatorGoal': creatorGoal,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        'xp': FieldValue.increment(0),
        'level': 1,
        'creatorStatus': CreatorStatus.newCreator.value,
      },
    );
  }

  Future<void> completeProductTour(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'hasCompletedProductTour': true,
          'currentOnboardingStep': 999,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> skipProductTour(String userId, int currentStep) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'hasCompletedProductTour': true,
          'currentOnboardingStep': currentStep,
          'skippedSteps': FieldValue.arrayUnion(<String>['product_tour']),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> completeOnboarding(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'hasCompletedOnboarding': true,
        'onboarding': <String, dynamic>{
          'hasCompletedOnboarding': true,
          'completedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> dismissLevelOneChecklist(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'skippedSteps':
              FieldValue.arrayUnion(<String>['level_one_checklist']),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> markContextualTipSeen(String userId, String tipId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'skippedSteps': FieldValue.arrayUnion(<String>['tip_$tipId']),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> resetContextualTips(String userId) {
    const List<String> tipIds = <String>[
      'tip_home',
      'tip_network',
      'tip_create',
      'tip_inbox',
      'tip_profile',
      'tip_comments',
      'tip_tippy_ai',
      'tip_content_planner',
    ];
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'skippedSteps': FieldValue.arrayRemove(tipIds),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  /// Marks Level 1 missions complete from existing account data only (no XP).
  /// Used so Progression "First things to do" matches real activity.
  Future<void> syncLevelOneMissionsFromAccountEvidence(String userId) async {
    final List<String> inferredIds = <String>[];
    final DocumentSnapshot<Map<String, dynamic>> userSnap =
        await _userRef(userId).get();
    final Map<String, dynamic>? root = userSnap.data();
    if (root == null) {
      return;
    }
    if (_inferCompleteProfile(root)) {
      inferredIds.add(completeProfileSideMission.id);
    }
    if (await _userHasAnyVideo(userId)) {
      inferredIds.add('upload_first_post');
    }
    if (_userHasConnectedPlatform(root)) {
      inferredIds.add('connect_platform');
    }
    if (await _userHasContentPlan(userId)) {
      inferredIds.add('create_content_plan');
    }
    if (_userHasSharedCreatorCard(root)) {
      inferredIds.add('share_creator_card');
    }
    final Set<String> inferred = inferredIds.toSet();
    if (inferred.isEmpty) {
      return;
    }
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await tx.get(_userRef(userId));
      final Map<String, dynamic>? data = snap.data();
      if (data == null) {
        return;
      }
      final OnboardingState current = OnboardingState.fromUserMap(data);
      final Set<String> before = current.completedMissions.toSet();
      if (inferred.difference(before).isEmpty) {
        return;
      }
      final Map<String, dynamic> nextOnboarding = Map<String, dynamic>.from(
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      );
      final Set<String> mergedSet = <String>{...before, ...inferred};
      final List<String> merged = mergedSet.toList()..sort();
      final bool allLevelOne = visibleLevelOneMissions.every(
        (OnboardingMission m) => merged.contains(m.id),
      );
      nextOnboarding['completedMissions'] = merged;
      nextOnboarding['hasCompletedLevelOne'] = allLevelOne;
      nextOnboarding['lastSeenAt'] = FieldValue.serverTimestamp();
      if (allLevelOne && current.hasCompletedProductTour) {
        nextOnboarding['hasCompletedOnboarding'] = true;
      }
      final Map<String, dynamic> write = <String, dynamic>{
        'onboarding': nextOnboarding,
      };
      if (allLevelOne && current.hasCompletedProductTour) {
        write['hasCompletedOnboarding'] = true;
      }
      tx.set(_userRef(userId), write, SetOptions(merge: true));
    });
  }

  bool _inferCompleteProfile(Map<String, dynamic> data) {
    final String dn = (data['displayName'] as String?)?.trim() ?? '';
    final String un = (data['username'] as String?)?.trim() ?? '';
    if (dn.length < 2 || un.length < 2) {
      return false;
    }
    final String bio = (data['bio'] as String?)?.trim() ?? '';
    final bool hasAvatar = _hasNonEmptyString(
      data['avatarURL'] ?? data['photoURL'] ?? data['avatarUrl'],
    );
    return bio.isNotEmpty && hasAvatar;
  }

  bool _hasNonEmptyString(Object? value) {
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return false;
  }

  bool _userHasConnectedPlatform(Map<String, dynamic> data) {
    final Object? raw = data['platforms'];
    if (raw is! List || raw.isEmpty) {
      return false;
    }
    const Set<String> keys = <String>{
      'youtube',
      'twitch',
      'tiktok',
      'kick',
      'instagram',
    };
    for (final Object? item in raw) {
      if (item is Map) {
        final String t = (item['type'] as String? ?? '').trim().toLowerCase();
        if (keys.contains(t)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _userHasSharedCreatorCard(Map<String, dynamic> data) {
    if (data['hasSharedCreatorCard'] == true ||
        data['creatorCardShared'] == true ||
        data['sharedCreatorCard'] == true) {
      return true;
    }
    final Object? shareStats = data['shareStats'];
    if (shareStats is Map) {
      final Object? count =
          shareStats['creatorCardShares'] ?? shareStats['creator_card'];
      if (count is num && count > 0) {
        return true;
      }
    }
    final Object? creatorCard = data['creatorCard'];
    if (creatorCard is Map) {
      final Object? count = creatorCard['shareCount'] ?? creatorCard['shares'];
      if (count is num && count > 0) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _userHasAnyVideo(String userId) async {
    for (final String field in <String>[
      'userId',
      'user_id',
      'creatorId',
      'creator_id',
      'authorId',
      'uid',
    ]) {
      final QuerySnapshot<Map<String, dynamic>> q = await _firestore
          .collection('videos')
          .where(field, isEqualTo: userId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        return true;
      }
    }
    final QuerySnapshot<Map<String, dynamic>> userVideos = await _firestore
        .collection('user_videos')
        .doc(userId)
        .collection('posts')
        .limit(1)
        .get();
    if (userVideos.docs.isNotEmpty) {
      return true;
    }
    return false;
  }

  Future<bool> _userHasContentPlan(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> q = await _firestore
        .collection('users')
        .doc(userId)
        .collection('contentPlans')
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<OnboardingMissionResult> completeMission(
    String userId,
    String missionId,
  ) async {
    final OnboardingMission mission = _missionForId(missionId);

    return _firestore
        .runTransaction<OnboardingMissionResult>((transaction) async {
      final DocumentReference<Map<String, dynamic>> ref = _userRef(userId);
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await transaction.get(ref);
      final OnboardingState current =
          OnboardingState.fromUserMap(snapshot.data());
      if (current.completedMissions.contains(missionId)) {
        return OnboardingMissionResult(
          mission: mission,
          newXp: current.xp,
          newLevel: current.level,
          completedLevelOne: current.hasCompletedLevelOne,
          wasAlreadyComplete: true,
        );
      }

      final List<String> completed = <String>[
        ...current.completedMissions,
        missionId,
      ];
      // TODO Phase B: stop writing users.xp; use createGamificationEvent only.
      final int newXp = current.xp + mission.rewardXp;
      final int newLevel = levelForXp(newXp);
      final bool completedLevelOne = visibleLevelOneMissions.every(
        (OnboardingMission item) => completed.contains(item.id),
      );

      transaction.set(
        ref,
        <String, dynamic>{
          'xp': newXp,
          'level': newLevel,
          'creatorStatus': CreatorStatus.fromXp(newXp).value,
          'onboarding': <String, dynamic>{
            'completedMissions': completed,
            'hasCompletedLevelOne': completedLevelOne,
            'lastSeenAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );

      return OnboardingMissionResult(
        mission: mission,
        newXp: newXp,
        newLevel: newLevel,
        completedLevelOne: completedLevelOne,
        wasAlreadyComplete: false,
      );
    });
  }
}
