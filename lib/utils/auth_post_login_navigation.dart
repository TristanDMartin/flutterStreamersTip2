import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../features/onboarding_tippy/tippy_onboarding_attach_pending.dart';
import '../features/onboarding_tippy/tippy_onboarding_host_presence.dart';
import '../routing/app_routes.dart';
import '../services/pending_auth_redirect_service.dart';

bool _consumeOrGoHomeInFlight = false;

/// Routes after Firebase sign-in.
///
/// Never remounts Tippy. Guest Tippy continues in-place after auth; otherwise
/// [OnboardingGate] resumes the exact Tippy step (or Home if complete).
Future<void> navigateAfterAuthenticated(BuildContext context) async {
  final firebase_auth.User? user =
      firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null || !context.mounted) {
    return;
  }
  await attachPendingTippyOnboardingIfNeeded();
  if (!context.mounted) {
    return;
  }
  // Tippy route already owns the funnel — stay put.
  if (TippyOnboardingHostPresence.isActive) {
    return;
  }
  try {
    await user.reload().timeout(const Duration(seconds: 3));
  } catch (error) {
    debugPrint('AUTH_TRANSITION post_login_reload_deferred: $error');
  }
  final firebase_auth.User fresh =
      firebase_auth.FirebaseAuth.instance.currentUser ?? user;
  if (!context.mounted) {
    return;
  }
  if (firebaseUserNeedsEmailVerification(fresh)) {
    final String? routeName = ModalRoute.of(context)?.settings.name;
    if (routeName == AppRoutes.root || routeName == AppRoutes.home) {
      return;
    }
    await PendingAuthRedirectService.instance.consumeOrGoHome(context);
    return;
  }
  if (_consumeOrGoHomeInFlight) {
    return;
  }
  _consumeOrGoHomeInFlight = true;
  try {
    if (!context.mounted) {
      return;
    }
    await PendingAuthRedirectService.instance.consumeOrGoHome(context);
  } finally {
    _consumeOrGoHomeInFlight = false;
  }
}

bool firebaseUserNeedsEmailVerification(firebase_auth.User? user) {
  if (user == null) {
    return false;
  }
  return authProvidersNeedEmailVerification(
    emailVerified: user.emailVerified,
    providerIds: user.providerData.map(
      (firebase_auth.UserInfo info) => info.providerId,
    ),
  );
}

bool authProvidersNeedEmailVerification({
  required bool emailVerified,
  required Iterable<String> providerIds,
}) {
  return !emailVerified && providerIds.contains('password');
}
