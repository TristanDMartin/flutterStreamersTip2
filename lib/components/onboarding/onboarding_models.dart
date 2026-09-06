import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'activation_state.dart';
import 'onboarding_v1_constants.dart';
import 'resolve_onboarding_destination.dart';

User? _readAuthUser() {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

enum CreatorStatus {
  newCreator('new_creator'),
  risingCreator('rising_creator'),
  consistentCreator('consistent_creator'),
  growthMode('growth_mode'),
  proCreator('pro_creator');

  const CreatorStatus(this.value);

  final String value;

  static CreatorStatus fromXp(int xp) {
    if (xp >= 5000) return CreatorStatus.proCreator;
    if (xp >= 2500) return CreatorStatus.growthMode;
    if (xp >= 1000) return CreatorStatus.consistentCreator;
    if (xp >= 475) return CreatorStatus.risingCreator;
    return CreatorStatus.newCreator;
  }
}

class OnboardingState {
  const OnboardingState({
    required this.version,
    required this.status,
    required this.completed,
    required this.currentStep,
    required this.hasSeenIntro,
    required this.creatorGoals,
    required this.platforms,
    required this.premiumOfferDismissed,
    this.completedAt,
    this.lastSeenAt,
    this.emailBannerDismissed = false,
    this.softRatingDismissed = false,
    this.hasRated = false,
    this.hasSeenMissionBannerOnHome = false,
    this.missionBannerDismissed = false,
    this.slim7Completed = false,
    this.tippyOnboardingV1Attached = false,
    this.tippyFunnelCompleted = false,
    this.essentialProfileComplete = false,
    this.activationState = '',
  });

  factory OnboardingState.initial() {
    return const OnboardingState(
      version: OnboardingV1Constants.version,
      status: OnboardingStatus.notStarted,
      completed: false,
      currentStep: 0,
      hasSeenIntro: false,
      creatorGoals: <String>[],
      platforms: <String>[],
      premiumOfferDismissed: false,
    );
  }

  factory OnboardingState.fromUserMap(Map<String, dynamic>? data) {
    if (data == null) {
      return OnboardingState.initial();
    }
    final Map<String, dynamic> onboarding =
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final int? version = _readInt(onboarding['version']);
    final bool hasV1Payload = version == OnboardingV1Constants.version;
    final bool legacyCompleted = !hasV1Payload &&
        (data['hasCompletedOnboarding'] == true ||
            data['onboardingCompleted'] == true ||
            onboarding['hasCompletedOnboarding'] == true ||
            onboarding['completed'] == true);
    final bool completed = hasV1Payload
        ? onboarding['completed'] == true
        : legacyCompleted || onboarding['completed'] == true;
    final int resolvedVersion =
        version ?? OnboardingV1Constants.version;
    final String status = completed
        ? OnboardingStatus.completed
        : (onboarding['status'] as String?) ?? OnboardingStatus.notStarted;
    final int currentStep = completed
        ? OnboardingV1Constants.completedStepMarker
        : (_readInt(onboarding['currentStep']) ??
            _readInt(onboarding['currentOnboardingStep']) ??
            0);
    final bool hasSeenIntro = completed ||
        onboarding['hasSeenIntro'] == true ||
        onboarding['hasCompletedProductTour'] == true;
    final String username =
        (data['username'] as String?)?.trim() ??
            (data['usernameLowercase'] as String?)?.trim() ??
            '';
    final String displayName =
        (data['displayName'] as String?)?.trim() ?? '';
    final bool hasPublicIdentity =
        username.isNotEmpty && displayName.isNotEmpty;
    final bool tippyAttached = onboarding['tippyOnboardingV1Attached'] == true;
    final bool slim7Completed = onboarding['slim7Completed'] == true;
    final bool tippyFunnelCompleted =
        onboarding['tippyFunnelCompleted'] == true ||
            onboarding['landingChoice'] != null;
    final bool lifecycleComplete =
        (onboarding['lifecycle'] as String?)?.toUpperCase() == 'COMPLETE';
    // New Tippy accounts keep going through Tippy until landing — do not treat
    // a provisional Google username as "essential profile complete".
    final bool essentialProfileComplete = lifecycleComplete ||
        onboarding['essentialProfileComplete'] == true ||
            onboarding['creatorCardCompleted'] == true ||
            (hasPublicIdentity &&
                !tippyAttached &&
                !slim7Completed &&
                (completed || legacyCompleted));
    // Tippy funnel is only "done" for the main app after essential identity +
    // landing choice. Classic onboarding still uses [completed].
    final bool tippyPathActive = tippyAttached || slim7Completed;
    final bool tippyPathDone =
        tippyFunnelCompleted && essentialProfileComplete;
    bool resolvedCompleted =
        lifecycleComplete || completed || tippyPathDone || legacyCompleted;
    // While Tippy owns setup, never hand off to classic onboarding or feed —
    // unless lifecycle was sticky-completed (legacy / returning).
    if (!lifecycleComplete &&
        tippyPathActive &&
        (!tippyFunnelCompleted || !essentialProfileComplete)) {
      resolvedCompleted = false;
    }
    final User? authUser = _readAuthUser();
    final OnboardingDestination destination = resolveOnboardingDestination(
      userData: data,
      emailVerified: authUser?.emailVerified == true,
      isPasswordProvider: authUser?.providerData.any(
            (UserInfo info) => info.providerId == 'password',
          ) ??
          false,
    );
    final ActivationDecision activation = resolveActivationState(
      isAuthenticated: authUser != null,
      destination: destination,
      hasFirstGrowthPlan: onboarding['firstGrowthPlanId'] is String,
      firstMissionChoice: onboarding['firstMissionChoice'] as String?,
    );
    return OnboardingState(
      version: resolvedVersion,
      status: resolvedCompleted ? OnboardingStatus.completed : status,
      completed: resolvedCompleted,
      currentStep: currentStep,
      hasSeenIntro: hasSeenIntro || slim7Completed,
      creatorGoals: _readStringList(
        onboarding['creatorGoals'] ??
            onboarding['creatorGoal'] ??
            data['creatorGoals'] ??
            data['goals'],
      ),
      platforms: _readStringList(
        onboarding['platforms'] ?? data['platforms'],
      ),
      premiumOfferDismissed: onboarding['premiumOfferDismissed'] == true,
      completedAt: onboarding['completedAt'] is Timestamp
          ? onboarding['completedAt'] as Timestamp
          : null,
      lastSeenAt: onboarding['lastSeenAt'] is Timestamp
          ? onboarding['lastSeenAt'] as Timestamp
          : null,
      emailBannerDismissed: onboarding['emailBannerDismissed'] == true,
      softRatingDismissed: onboarding['softRatingDismissed'] == true,
      hasRated: onboarding['hasRated'] == true,
      hasSeenMissionBannerOnHome:
          onboarding['hasSeenMissionBannerOnHome'] == true,
      missionBannerDismissed: onboarding['missionBannerDismissed'] == true,
      slim7Completed: slim7Completed,
      tippyOnboardingV1Attached: tippyAttached,
      tippyFunnelCompleted: tippyFunnelCompleted,
      essentialProfileComplete: essentialProfileComplete,
      activationState: activation.state,
    );
  }

  final int version;
  final String status;
  final bool completed;
  final int currentStep;
  final bool hasSeenIntro;
  final List<String> creatorGoals;
  final List<String> platforms;
  final bool premiumOfferDismissed;
  final Timestamp? completedAt;
  final Timestamp? lastSeenAt;
  final bool emailBannerDismissed;
  final bool softRatingDismissed;
  final bool hasRated;
  final bool hasSeenMissionBannerOnHome;
  final bool missionBannerDismissed;
  final bool slim7Completed;
  final bool tippyOnboardingV1Attached;
  final bool tippyFunnelCompleted;
  final bool essentialProfileComplete;
  /// Canonical activation machine. Empty until populated from the resolver.
  final String activationState;

  bool get needsTippyGuidedProfile =>
      !essentialProfileComplete &&
      (tippyOnboardingV1Attached || slim7Completed);

  /// Tippy path started (slim-7 and/or attach).
  bool get isTippyPathActive =>
      tippyOnboardingV1Attached || slim7Completed;

  /// Tippy owns post-auth setup until landing + essential profile — never
  /// stack classic "creator focus" / creator-card onboarding.
  bool get isTippyFunnelIncomplete =>
      isTippyPathActive &&
      (!tippyFunnelCompleted || !essentialProfileComplete);

  bool get isInProgress =>
      !completed && status == OnboardingStatus.inProgress;

  double get progressFraction {
    if (completed) {
      return 1;
    }
    return (currentStep.clamp(0, OnboardingV1Constants.totalSteps)) /
        OnboardingV1Constants.totalSteps;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OnboardingState &&
            version == other.version &&
            status == other.status &&
            completed == other.completed &&
            currentStep == other.currentStep &&
            hasSeenIntro == other.hasSeenIntro &&
            listEquals(creatorGoals, other.creatorGoals) &&
            listEquals(platforms, other.platforms) &&
            premiumOfferDismissed == other.premiumOfferDismissed &&
            emailBannerDismissed == other.emailBannerDismissed &&
            softRatingDismissed == other.softRatingDismissed &&
            hasRated == other.hasRated &&
            hasSeenMissionBannerOnHome == other.hasSeenMissionBannerOnHome &&
            missionBannerDismissed == other.missionBannerDismissed &&
            slim7Completed == other.slim7Completed &&
            tippyOnboardingV1Attached == other.tippyOnboardingV1Attached &&
            tippyFunnelCompleted == other.tippyFunnelCompleted &&
            essentialProfileComplete == other.essentialProfileComplete;
  }

  @override
  int get hashCode => Object.hash(
        version,
        status,
        completed,
        currentStep,
        hasSeenIntro,
        Object.hashAll(creatorGoals),
        Object.hashAll(platforms),
        premiumOfferDismissed,
        emailBannerDismissed,
        softRatingDismissed,
        hasRated,
        hasSeenMissionBannerOnHome,
        missionBannerDismissed,
        slim7Completed,
        tippyOnboardingV1Attached,
        tippyFunnelCompleted,
        essentialProfileComplete,
      );
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return <String>[value.trim()];
  }
  if (value is Iterable) {
    return value
        .map((Object? item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
