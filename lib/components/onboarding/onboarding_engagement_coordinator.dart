import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/app_store_review_service.dart';
import '../../utils/auth_post_login_navigation.dart';
import 'onboarding_models.dart';
import 'onboarding_premium_modal.dart';
import 'onboarding_service.dart';
import 'widgets/hard_rating_overlay.dart';

class OnboardingEngagementCoordinator {
  OnboardingEngagementCoordinator._();

  static final OnboardingEngagementCoordinator instance =
      OnboardingEngagementCoordinator._();

  final OnboardingService _onboardingService = OnboardingService();
  DateTime? _appLaunchTime;
  bool _premiumOfferShownThisSession = false;
  bool _hardRatingShownThisSession = false;

  void markAppLaunched() {
    _appLaunchTime ??= DateTime.now();
  }

  Future<void> handleFirstMissionCompleted({
    required BuildContext context,
    required String userId,
    required int completedMissionCount,
  }) async {
    if (completedMissionCount < 1) {
      return;
    }
    await _maybeShowPremiumUpsell(context, userId);
    if (!context.mounted) {
      return;
    }
    await _maybeShowHardRating(context, userId);
  }

  Future<void> checkHardRatingOnHomeEntry({
    required BuildContext context,
    required String userId,
  }) async {
    final OnboardingState state =
        await _onboardingService.fetchOnboarding(userId);
    if (state.hasRated || !state.softRatingDismissed) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _maybeShowHardRating(context, userId);
  }

  Future<void> _maybeShowPremiumUpsell(
    BuildContext context,
    String userId,
  ) async {
    if (_premiumOfferShownThisSession) {
      return;
    }
    final OnboardingState state =
        await _onboardingService.fetchOnboarding(userId);
    if (state.premiumOfferDismissed) {
      return;
    }
    _premiumOfferShownThisSession = true;
    if (!context.mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) {
      return;
    }
    await showOnboardingPremiumSheet(
      context,
      userId: userId,
      onDismissed: () => _onboardingService.dismissPremiumOffer(userId),
    );
  }

  Future<void> _maybeShowHardRating(
    BuildContext context,
    String userId,
  ) async {
    if (_hardRatingShownThisSession) {
      return;
    }
    final OnboardingState state =
        await _onboardingService.fetchOnboarding(userId);
    if (state.hasRated || !state.softRatingDismissed) {
      return;
    }
    final DateTime launchTime = _appLaunchTime ?? DateTime.now();
    if (DateTime.now().difference(launchTime) < const Duration(seconds: 60)) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null && firebaseUserNeedsEmailVerification(user)) {
      return;
    }
    _hardRatingShownThisSession = true;
    if (!context.mounted) {
      return;
    }
    HardRatingOverlay.show(
      context: context,
      userId: userId,
      service: _onboardingService,
      onRequestReview: requestAppStoreReview,
    );
  }
}
