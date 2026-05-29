import 'dart:async';
import 'package:streamers_tip/utils/secure_log.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'onboarding_service.dart';

class OnboardingMissionActions {
  const OnboardingMissionActions._();

  static final StreamController<OnboardingMissionResult> _controller =
      StreamController<OnboardingMissionResult>.broadcast();

  static Stream<OnboardingMissionResult> get completedMissions =>
      _controller.stream;

  static Future<OnboardingMissionResult?> complete(
    String missionOrUserId, [
    String? maybeMissionId,
  ]) async {
    final String missionId = maybeMissionId ?? missionOrUserId;
    final String? userId = maybeMissionId == null
        ? firebase_auth.FirebaseAuth.instance.currentUser?.uid
        : missionOrUserId;
    if (userId == null) return null;
    try {
      final result =
          await OnboardingService().completeMission(userId, missionId);
      if (!result.wasAlreadyComplete) {
        _controller.add(result);
      }
      return result;
    } catch (error) {
      secureLog('Onboarding mission completion failed: $missionId $error');
      return null;
    }
  }
}
