import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/gamification/create_gamification_event.dart';
import '../../features/gamification/gamification_event_types.dart';
import '../../utils/user_profile_firestore.dart';
import '../../services/app_session_cache.dart';
import 'onboarding_models.dart';
import 'onboarding_v1_constants.dart';

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
    final OnboardingState? cached =
        AppSessionCache.instance.peekOnboarding(userId);
    if (cached != null) {
      unawaited(_fetchOnboardingRemote(userId));
      return cached;
    }
    return _fetchOnboardingRemote(userId);
  }

  Future<OnboardingState> _fetchOnboardingRemote(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _userRef(userId).get();
    final OnboardingState state = OnboardingState.fromUserMap(snapshot.data());
    AppSessionCache.instance.putOnboarding(userId, state);
    return state;
  }

  /// Existing users bypass onboarding on first V1 migration.
  Future<OnboardingState> ensureMigrated(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _userRef(userId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      await _safeUserSet(userId, _newUserOnboardingPayload(step: 0));
      return OnboardingState.initial();
    }
    final OnboardingState current = OnboardingState.fromUserMap(data);
    if (current.completed) {
      return current;
    }
    final Map<String, dynamic> onboarding =
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final int? version = onboarding['version'] as int?;
    if (version == OnboardingV1Constants.version) {
      await _reconcileIncompleteV1Flags(userId, data, onboarding);
      return fetchOnboarding(userId);
    }
    if (_isExistingUser(data)) {
      await _safeUserSet(userId, _completedMigrationPayload());
      return OnboardingState.fromUserMap(<String, dynamic>{
        ...data,
        'hasCompletedOnboarding': true,
        'onboarding': _completedMigrationPayload()['onboarding'],
      });
    }
    await _safeUserSet(
        userId, _newUserOnboardingPayload(step: current.currentStep));
    return fetchOnboarding(userId);
  }

  bool _isExistingUser(Map<String, dynamic> data) {
    if (data['hasCompletedOnboarding'] == true ||
        data['onboardingCompleted'] == true) {
      return true;
    }
    final Map<String, dynamic> onboarding =
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    if (onboarding['completed'] == true ||
        onboarding['hasCompletedOnboarding'] == true) {
      return true;
    }
    if (onboarding['hasCompletedProductTour'] == true) {
      return true;
    }
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    if (createdAt != null) {
      final DateTime created = createdAt.toDate();
      final DateTime launchCutoff = DateTime(2026, 3, 1);
      if (created.isBefore(launchCutoff)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _reconcileIncompleteV1Flags(
    String userId,
    Map<String, dynamic> data,
    Map<String, dynamic> onboarding,
  ) async {
    final bool staleComplete = data['hasCompletedOnboarding'] == true ||
        data['onboardingCompleted'] == true ||
        onboarding['hasCompletedOnboarding'] == true;
    if (!staleComplete) {
      return;
    }
    await _safeUserSet(
      userId,
      <String, dynamic>{
        'hasCompletedOnboarding': false,
        'onboardingCompleted': false,
        'onboarding': <String, dynamic>{
          'hasCompletedOnboarding': false,
          'completed': false,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  /// Firestore fields for accounts that have not finished onboarding.
  static Map<String, dynamic> newAccountDocumentFields({int step = 0}) {
    return <String, dynamic>{
      'hasCompletedOnboarding': false,
      'onboardingCompleted': false,
      'onboarding': <String, dynamic>{
        'version': OnboardingV1Constants.version,
        'status': step > 0
            ? OnboardingStatus.inProgress
            : OnboardingStatus.notStarted,
        'completed': false,
        'currentStep': step,
        'hasSeenIntro': false,
        'completedAt': null,
        'creatorGoals': <String>[],
        'platforms': <String>[],
        'premiumOfferDismissed': false,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
    };
  }

  Map<String, dynamic> _newUserOnboardingPayload({required int step}) {
    return newAccountDocumentFields(step: step);
  }

  Map<String, dynamic> _completedMigrationPayload() {
    return <String, dynamic>{
      'hasCompletedOnboarding': true,
      'onboardingCompleted': true,
      'onboarding': <String, dynamic>{
        'version': OnboardingV1Constants.version,
        'status': OnboardingStatus.completed,
        'completed': true,
        'currentStep': OnboardingV1Constants.completedStepMarker,
        'hasSeenIntro': true,
        'completedAt': FieldValue.serverTimestamp(),
        'premiumOfferDismissed': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
    };
  }

  Future<void> advanceToStep(String userId, int step) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.inProgress,
          'currentStep': step,
          'hasSeenIntro': step > 0,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> saveCreatorGoals(String userId, List<String> goals) {
    return savePersonalize(
      userId: userId,
      goals: goals,
      platforms: const <String>[],
      skipSave: true,
    );
  }

  Future<void> savePersonalize({
    required String userId,
    required List<String> goals,
    required List<String> platforms,
    bool skipSave = false,
  }) async {
    final List<Map<String, dynamic>> platformStubs =
        UserProfileFirestore.platformStubsFromSelection(platforms);
    final Map<String, dynamic> payload = <String, dynamic>{
      if (goals.isNotEmpty) 'creatorGoals': goals,
      // Do NOT write selection stubs onto users.platforms / linkedPlatforms —
      // that wiped real Edit Profile URLs. Keep picks under onboarding only.
      'onboarding': <String, dynamic>{
        'version': OnboardingV1Constants.version,
        'status': OnboardingStatus.inProgress,
        'currentStep': 2,
        if (goals.isNotEmpty) 'creatorGoals': goals,
        if (platforms.isNotEmpty) 'platforms': platforms,
        if (platformStubs.isNotEmpty) 'platformStubs': platformStubs,
        'hasSeenIntro': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
    };
    await _safeUserSet(userId, payload);
    if (skipSave || goals.isEmpty && platforms.isEmpty) {
      return;
    }
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.onboardingPersonalized,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{
        'rewardXp': OnboardingV1Constants.personalizeRewardXp,
        'source': 'onboarding_v1',
      },
    );
  }

  Future<void> savePlatforms(String userId, List<String> platforms) {
    return savePersonalize(
      userId: userId,
      goals: const <String>[],
      platforms: platforms,
      skipSave: true,
    );
  }

  Future<void> saveCreatorCard({
    required String userId,
    required String displayName,
    required String username,
    required String bio,
    required String categoryId,
    String? avatarUrl,
    List<Map<String, dynamic>>? platforms,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _userRef(userId).get();
    final Map<String, dynamic>? existing = snapshot.data();
    final Map<String, dynamic> existingOnboarding =
        (existing?['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final bool alreadyCompleted =
        existingOnboarding['creatorCardCompleted'] == true;
    final Map<String, dynamic> profile = <String, dynamic>{
      'displayName': displayName.trim(),
      'username': username.trim().toLowerCase(),
      'usernameLowercase': username.trim().toLowerCase(),
      'bio': bio.trim(),
      'categoryId': categoryId,
      'category': categoryId,
    };
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      profile['avatarURL'] = avatarUrl.trim();
      profile['photoURL'] = avatarUrl.trim();
    }
    if (platforms != null) {
      profile[UserProfileFirestore.platformsField] =
          UserProfileFirestore.normalizePlatformsForFirestore(platforms);
    }
    await _safeUserSet(
      userId,
      <String, dynamic>{
        ...profile,
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.inProgress,
          'currentStep': 3,
          'hasSeenIntro': true,
          'creatorCardCompleted': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
    if (alreadyCompleted) {
      return;
    }
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.creatorCardCompleted,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{
        'rewardXp': OnboardingV1Constants.creatorCardRewardXp,
        'source': 'onboarding_v1',
      },
    );
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.profileCompleted,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{'source': 'onboarding_v1'},
    );
  }

  /// Tippy guided profile commit — client-writable fields only.
  /// Username + displayName are Admin SDK / site API only (Firestore rules).
  Future<void> saveGuidedTippyProfile({
    required String userId,
    required String displayName,
    required String username,
    required String bio,
    required String categoryId,
    required List<String> categoryIds,
    String? avatarUrl,
    List<Map<String, dynamic>>? platforms,
  }) async {
    // Identity fields intentionally omitted — reserved for claim/change +
    // /api/profile/display-name. Writing them client-side is permission-denied.
    final Map<String, dynamic> profile = <String, dynamic>{
      'bio': bio.trim(),
      'categoryId': categoryId,
      'category': categoryId,
      'categories': categoryIds,
    };
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      profile['avatarURL'] = avatarUrl.trim();
      profile['photoURL'] = avatarUrl.trim();
    }
    if (platforms != null) {
      final List<Map<String, dynamic>> normalized =
          UserProfileFirestore.normalizePlatformsForFirestore(platforms);
      profile[UserProfileFirestore.platformsField] = normalized;
      profile[UserProfileFirestore.linkedPlatformsField] = normalized;
    }
    final List<String> platformTypes = platforms == null
        ? <String>[]
        : platforms
            .map(
              (Map<String, dynamic> p) => UserProfileFirestore.readPlatformType(p),
            )
            .where((String t) => t.isNotEmpty)
            .toList();
    await _userRef(userId).set(
      <String, dynamic>{
        ...profile,
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': 'profile_complete',
          'currentStep': 3,
          'hasSeenIntro': true,
          'creatorCardCompleted': true,
          'essentialProfileComplete': true,
          'slim7Completed': true,
          'tippyOnboardingV1Attached': true,
          if (platformTypes.isNotEmpty) 'platforms': platformTypes,
          'guidedProfileCompletedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          // Stash chosen identity for post-verify Admin claim/sync.
          'tippyPendingDisplayName': displayName.trim(),
          'tippyPendingUsername': username.trim().toLowerCase(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    try {
      await _firestore.collection('publicUsers').doc(userId).set(
        <String, dynamic>{
          'uid': userId,
          if (bio.trim().isNotEmpty) 'bio': bio.trim(),
          if (avatarUrl != null && avatarUrl.trim().isNotEmpty) ...<String, dynamic>{
            'avatarURL': avatarUrl.trim(),
            'photoURL': avatarUrl.trim(),
          },
          if (platforms != null)
            UserProfileFirestore.platformsField:
                UserProfileFirestore.normalizePlatformsForFirestore(platforms),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('OnboardingService: publicUsers mirror skipped: $error');
    }
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.creatorCardCompleted,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{
        'rewardXp': OnboardingV1Constants.creatorCardRewardXp,
        'source': 'tippy_onboarding_v1',
      },
    );
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.profileCompleted,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{'source': 'tippy_onboarding_v1'},
    );
  }

  Future<void> completeOnboarding(
    String userId, {
    bool skippedByTester = false,
  }) async {
    await _safeUserSet(
      userId,
      <String, dynamic>{
        'hasCompletedOnboarding': true,
        'onboardingCompleted': true,
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.completed,
          'completed': true,
          'currentStep': OnboardingV1Constants.completedStepMarker,
          'hasSeenIntro': true,
          'completedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          if (skippedByTester) 'skippedByTester': true,
          if (skippedByTester) 'skippedSteps': <String>['all'],
        },
      },
    );
    AppSessionCache.instance.putOnboarding(
      userId,
      const OnboardingState(
        version: OnboardingV1Constants.version,
        completed: true,
        status: OnboardingStatus.completed,
        currentStep: OnboardingV1Constants.completedStepMarker,
        hasSeenIntro: true,
        creatorGoals: <String>[],
        platforms: <String>[],
        premiumOfferDismissed: false,
      ),
    );
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.userOnboardingCompleted,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{
        'rewardXp': OnboardingV1Constants.levelOneUnlockRewardXp,
        'source': 'onboarding_v1',
        if (skippedByTester) 'skippedByTester': true,
      },
    );
  }

  /// Marks this account as Tippy-owned so OnboardingGate never shows classic
  /// "What's your creator focus?" — even if the attach API fails.
  Future<void> markTippyFunnelInProgress(String userId) async {
    final OnboardingState? cached =
        AppSessionCache.instance.peekOnboarding(userId);
    final OnboardingState next = OnboardingState(
      version: OnboardingV1Constants.version,
      status: OnboardingStatus.inProgress,
      completed: false,
      currentStep: cached?.currentStep ?? 0,
      hasSeenIntro: true,
      creatorGoals: cached?.creatorGoals ?? const <String>[],
      platforms: cached?.platforms ?? const <String>[],
      premiumOfferDismissed: cached?.premiumOfferDismissed ?? false,
      completedAt: cached?.completedAt,
      lastSeenAt: cached?.lastSeenAt,
      emailBannerDismissed: cached?.emailBannerDismissed ?? false,
      softRatingDismissed: cached?.softRatingDismissed ?? false,
      hasRated: cached?.hasRated ?? false,
      hasSeenMissionBannerOnHome:
          cached?.hasSeenMissionBannerOnHome ?? false,
      missionBannerDismissed: cached?.missionBannerDismissed ?? false,
      slim7Completed: true,
      tippyOnboardingV1Attached: true,
      tippyFunnelCompleted: cached?.tippyFunnelCompleted ?? false,
      essentialProfileComplete: cached?.essentialProfileComplete ?? false,
    );
    AppSessionCache.instance.putOnboarding(userId, next);
    await _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.inProgress,
          'completed': false,
          'hasSeenIntro': true,
          'slim7Completed': true,
          'tippyOnboardingV1Attached': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  /// Tippy slim-7 + guided profile replace classic steps 1–3.
  /// Awards the same XP once, then marks classic onboarding complete so the
  /// "creator focus" / creator-card screens never appear after Tippy.
  Future<void> completeClassicOnboardingReplacedByTippy(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _userRef(userId).get();
    final Map<String, dynamic> data =
        snapshot.data() ?? <String, dynamic>{};
    final Map<String, dynamic> onboarding =
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    if (onboarding['completed'] == true ||
        data['hasCompletedOnboarding'] == true) {
      AppSessionCache.instance.putOnboarding(
        userId,
        OnboardingState.fromUserMap(data),
      );
      return;
    }
    final bool awardedPersonalize =
        onboarding['tippyPersonalizeXpAwarded'] == true;
    final bool awardedCreatorCard =
        onboarding['creatorCardCompleted'] == true ||
            onboarding['tippyCreatorCardXpAwarded'] == true;
    await _safeUserSet(
      userId,
      <String, dynamic>{
        'hasCompletedOnboarding': true,
        'onboardingCompleted': true,
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.completed,
          'completed': true,
          'currentStep': OnboardingV1Constants.completedStepMarker,
          'hasSeenIntro': true,
          'creatorCardCompleted': true,
          'essentialProfileComplete': true,
          'tippyFunnelCompleted': true,
          'tippyPersonalizeXpAwarded': true,
          'tippyCreatorCardXpAwarded': true,
          'classicReplacedByTippy': true,
          'completedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
    AppSessionCache.instance.putOnboarding(
      userId,
      const OnboardingState(
        version: OnboardingV1Constants.version,
        completed: true,
        status: OnboardingStatus.completed,
        currentStep: OnboardingV1Constants.completedStepMarker,
        hasSeenIntro: true,
        creatorGoals: <String>[],
        platforms: <String>[],
        premiumOfferDismissed: false,
        slim7Completed: true,
        tippyOnboardingV1Attached: true,
        tippyFunnelCompleted: true,
        essentialProfileComplete: true,
      ),
    );
    if (!awardedPersonalize) {
      _scheduleOnboardingGamificationEvent(
        type: GamificationEventTypes.onboardingPersonalized,
        entityType: 'user',
        entityId: userId,
        metadata: <String, dynamic>{
          'rewardXp': OnboardingV1Constants.personalizeRewardXp,
          'source': 'tippy_onboarding_v1',
        },
      );
    }
    if (!awardedCreatorCard) {
      _scheduleOnboardingGamificationEvent(
        type: GamificationEventTypes.creatorCardCompleted,
        entityType: 'user',
        entityId: userId,
        metadata: <String, dynamic>{
          'rewardXp': OnboardingV1Constants.creatorCardRewardXp,
          'source': 'tippy_onboarding_v1',
        },
      );
      _scheduleOnboardingGamificationEvent(
        type: GamificationEventTypes.profileCompleted,
        entityType: 'user',
        entityId: userId,
        metadata: <String, dynamic>{'source': 'tippy_onboarding_v1'},
      );
    }
    _scheduleOnboardingGamificationEvent(
      type: GamificationEventTypes.userOnboardingCompleted,
      entityType: 'user',
      entityId: userId,
      metadata: <String, dynamic>{
        'rewardXp': OnboardingV1Constants.levelOneUnlockRewardXp,
        'source': 'tippy_onboarding_v1',
      },
    );
  }

  /// Final Tippy landing choice — marks funnel complete for OnboardingGate.
  /// Always updates [AppSessionCache] so the overlay can dismiss even when
  /// Firestore client writes are soft-skipped (permission-denied).
  Future<void> completeTippyLanding({
    required String userId,
    required String landingChoice,
  }) async {
    await completeClassicOnboardingReplacedByTippy(userId);
    await _safeUserSet(
      userId,
      <String, dynamic>{
        'hasCompletedOnboarding': true,
        'onboardingCompleted': true,
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.completed,
          'completed': true,
          'currentStep': OnboardingV1Constants.completedStepMarker,
          'hasSeenIntro': true,
          'creatorCardCompleted': true,
          'essentialProfileComplete': true,
          'tippyFunnelCompleted': true,
          'landingChoice': landingChoice,
          'classicReplacedByTippy': true,
          'completedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    final OnboardingState? cached =
        AppSessionCache.instance.peekOnboarding(userId);
    AppSessionCache.instance.putOnboarding(
      userId,
      OnboardingState(
        version: OnboardingV1Constants.version,
        completed: true,
        status: OnboardingStatus.completed,
        currentStep: OnboardingV1Constants.completedStepMarker,
        hasSeenIntro: true,
        creatorGoals: cached?.creatorGoals ?? const <String>[],
        platforms: cached?.platforms ?? const <String>[],
        premiumOfferDismissed: cached?.premiumOfferDismissed ?? false,
        slim7Completed: true,
        tippyOnboardingV1Attached: true,
        tippyFunnelCompleted: true,
        essentialProfileComplete: true,
      ),
    );
  }

  Future<void> skipOnboardingAsTester(String userId) {
    return completeOnboarding(userId, skippedByTester: true);
  }

  void _scheduleOnboardingGamificationEvent({
    required String type,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) {
    unawaited(() async {
      try {
        await createGamificationEvent(
          type: type,
          entityType: entityType,
          entityId: entityId,
          metadata: metadata,
        );
      } catch (_) {}
    }());
  }

  Future<void> dismissPremiumOffer(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'premiumOfferDismissed': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> dismissEmailBanner(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'emailBannerDismissed': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> markSoftRatingDismissed(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'softRatingDismissed': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> markHasRated(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'hasRated': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> saveOnboardingFeedback(String userId, String feedback) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboardingFeedback': feedback.trim(),
        'onboarding': <String, dynamic>{
          'softRatingDismissed': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> markMissionBannerSeenOnHome(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'hasSeenMissionBannerOnHome': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> dismissMissionBanner(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'missionBannerDismissed': true,
          'hasSeenMissionBannerOnHome': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }

  Future<void> resetForDeveloperTesterInstall(String userId) {
    return _safeUserSet(
      userId,
      <String, dynamic>{
        'hasCompletedOnboarding': false,
        'onboarding': <String, dynamic>{
          'version': OnboardingV1Constants.version,
          'status': OnboardingStatus.notStarted,
          'completed': false,
          'hasCompletedOnboarding': false,
          'hasCompletedProductTour': false,
          'hasCompletedLevelOne': false,
          'currentStep': 0,
          'currentOnboardingStep': 0,
          'hasSeenIntro': false,
          'completedAt': null,
          'creatorGoals': <String>[],
          'platforms': <String>[],
          'premiumOfferDismissed': false,
          'skippedSteps': <String>[],
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
    );
  }
}
