import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
    required this.hasSeenIntro,
    required this.hasCompletedProductTour,
    required this.hasCompletedOnboarding,
    required this.hasCompletedLevelOne,
    required this.currentOnboardingStep,
    required this.completedMissions,
    required this.skippedSteps,
    required this.xp,
    required this.level,
    required this.creatorStatus,
    this.creatorGoal,
    this.lastSeenAt,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(
      hasSeenIntro: false,
      hasCompletedProductTour: false,
      hasCompletedOnboarding: false,
      hasCompletedLevelOne: false,
      currentOnboardingStep: 0,
      creatorGoal: null,
      completedMissions: <String>[],
      skippedSteps: <String>[],
      xp: 0,
      level: 1,
      creatorStatus: 'new_creator',
    );
  }

  factory OnboardingState.fromUserMap(Map<String, dynamic>? data) {
    if (data == null) return OnboardingState.initial();
    final Map<String, dynamic> onboarding =
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final bool hasCompletedOnboarding =
        data['hasCompletedOnboarding'] == true ||
            onboarding['hasCompletedOnboarding'] == true;
    final int xp = _readInt(data['xp']) ??
        _readInt((data['gamification'] as Map?)?['xp']) ??
        _readInt((data['gamification'] as Map?)?['totalXp']) ??
        0;
    return OnboardingState(
      hasSeenIntro:
          hasCompletedOnboarding || onboarding['hasSeenIntro'] == true,
      hasCompletedProductTour: onboarding['hasCompletedProductTour'] == true ||
          hasCompletedOnboarding,
      hasCompletedOnboarding: hasCompletedOnboarding,
      hasCompletedLevelOne: onboarding['hasCompletedLevelOne'] == true,
      currentOnboardingStep: _readInt(onboarding['currentOnboardingStep']) ?? 0,
      creatorGoal: onboarding['creatorGoal'] as String?,
      completedMissions: _readStringList(onboarding['completedMissions']),
      skippedSteps: _readStringList(onboarding['skippedSteps']),
      lastSeenAt: onboarding['lastSeenAt'] is Timestamp
          ? onboarding['lastSeenAt'] as Timestamp
          : null,
      xp: xp,
      level: _readInt(data['level']) ?? levelForXp(xp),
      creatorStatus:
          (data['creatorStatus'] as String?) ?? CreatorStatus.fromXp(xp).value,
    );
  }

  final bool hasSeenIntro;
  final bool hasCompletedProductTour;
  final bool hasCompletedOnboarding;
  final bool hasCompletedLevelOne;
  final int currentOnboardingStep;
  final String? creatorGoal;
  final List<String> completedMissions;
  final List<String> skippedSteps;
  final Timestamp? lastSeenAt;
  final int xp;
  final int level;
  final String creatorStatus;

  int get completedMissionCount => completedMissions
      .where((String id) => levelOneMissions.any((m) => m.id == id))
      .length;

  double get levelOneProgress =>
      completedMissionCount / levelOneMissions.length;

  OnboardingMission? get nextMission {
    for (final OnboardingMission mission in levelOneMissions) {
      if (!completedMissions.contains(mission.id)) return mission;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OnboardingState &&
            hasSeenIntro == other.hasSeenIntro &&
            hasCompletedProductTour == other.hasCompletedProductTour &&
            hasCompletedOnboarding == other.hasCompletedOnboarding &&
            hasCompletedLevelOne == other.hasCompletedLevelOne &&
            currentOnboardingStep == other.currentOnboardingStep &&
            creatorGoal == other.creatorGoal &&
            listEquals(completedMissions, other.completedMissions) &&
            listEquals(skippedSteps, other.skippedSteps) &&
            xp == other.xp &&
            level == other.level &&
            creatorStatus == other.creatorStatus;
  }

  @override
  int get hashCode => Object.hash(
        hasSeenIntro,
        hasCompletedProductTour,
        hasCompletedOnboarding,
        hasCompletedLevelOne,
        currentOnboardingStep,
        creatorGoal,
        Object.hashAll(completedMissions),
        Object.hashAll(skippedSteps),
        xp,
        level,
        creatorStatus,
      );
}

class OnboardingMission {
  const OnboardingMission({
    required this.id,
    required this.title,
    required this.rewardXp,
    required this.routeHint,
  });

  final String id;
  final String title;
  final int rewardXp;
  final String routeHint;

  String get reward => '+$rewardXp XP';
}

/// Saved from Edit Profile; not shown in Level 1 checklist (profile is covered
/// in the profile / edit flow).
const OnboardingMission completeProfileSideMission = OnboardingMission(
  id: 'complete_profile',
  title: 'Complete your Creator Profile',
  rewardXp: 50,
  routeHint: 'Finish your profile in Edit Profile.',
);

const List<OnboardingMission> levelOneMissions = <OnboardingMission>[
  completeProfileSideMission,
  OnboardingMission(
    id: 'upload_first_post',
    title: 'Upload your first post',
    rewardXp: 50,
    routeHint: 'Post, draft, or schedule your first clip.',
  ),
  OnboardingMission(
    id: 'connect_platform',
    title: 'Connect Twitch, YouTube, Kick, or TikTok',
    rewardXp: 50,
    routeHint: 'Link a platform for smarter cross-posting.',
  ),
  OnboardingMission(
    id: 'create_content_plan',
    title: 'Create your first content plan',
    rewardXp: 50,
    routeHint: 'Plan a week of posts in the content planner.',
  ),
  OnboardingMission(
    id: 'share_creator_card',
    title: 'Share your Creator Card',
    rewardXp: 50,
    routeHint: 'Share your creator identity with the world.',
  ),
];

int levelForXp(int xp) {
  if (xp >= 5000) return 5;
  if (xp >= 2500) return 4;
  if (xp >= 1000) return 3;
  if (xp >= 475) return 2;
  return 1;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is Iterable) {
    return value.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}
