import 'activation_state.dart';

class AccountNavigation {
  const AccountNavigation({
    required this.route,
    required this.tippyStageHint,
  });

  /// app | verify-email | onboarding | signin
  final String route;
  final String? tippyStageHint;
}

const Set<String> _preIdentityHints = <String>{
  'welcome',
  'questions',
  'dna_reveal',
  'signup',
  'verify_email',
};

String? floorHintForActivation({
  String? activationState,
  String? activationReason,
  String? hint,
}) {
  final String state = activationState ?? '';
  if (state == 'EMAIL_VERIFICATION_REQUIRED') {
    return 'verify_email';
  }
  if (state == 'ACCOUNT_REQUIRED') {
    return hint ?? 'signup';
  }
  if (state == 'GUEST_PERSONALIZATION') {
    if (activationReason == 'identity_recycled_restart') {
      return hint ?? 'welcome';
    }
    if (hint == null || _preIdentityHints.contains(hint)) {
      return 'account_secured';
    }
    return hint;
  }
  if (state == 'TIPPY_INITIAL_ANALYSIS' || state == 'FIRST_GROWTH_PLAN') {
    if (hint == null || _preIdentityHints.contains(hint)) {
      return 'creator_space_ready';
    }
    return hint;
  }
  if (state == 'FIRST_MISSION') {
    if (hint == null || _preIdentityHints.contains(hint)) {
      return 'first_mission';
    }
    return hint;
  }
  if (state == 'CREATOR_IDENTITY') {
    if (hint == null || _preIdentityHints.contains(hint)) {
      return 'account_secured';
    }
    return hint;
  }
  return hint;
}

/// Single client navigator. Do not infer from emailVerified or local flags.
AccountNavigation navigationFromAccountStatus({
  String? activationState,
  String? activationReason,
  String? tippyStageHint,
  bool allowApp = false,
}) {
  final String? rawHint =
      (tippyStageHint ?? '').trim().isEmpty ? null : tippyStageHint!.trim();
  final String? hint = floorHintForActivation(
    activationState: activationState,
    activationReason: activationReason,
    hint: rawHint,
  );
  if (isActivated(activationState) || allowApp) {
    return const AccountNavigation(route: 'app', tippyStageHint: null);
  }
  if (activationState == 'EMAIL_VERIFICATION_REQUIRED') {
    return AccountNavigation(
      route: 'verify-email',
      tippyStageHint: hint ?? 'verify_email',
    );
  }
  if (activationState == 'ACCOUNT_REQUIRED') {
    return AccountNavigation(
      route: 'signin',
      tippyStageHint: hint ?? 'signup',
    );
  }
  if (shouldContinueActivation(activationState)) {
    return AccountNavigation(route: 'onboarding', tippyStageHint: hint);
  }
  return const AccountNavigation(route: 'app', tippyStageHint: null);
}

/// Logged-in users never see Tippy until status says onboarding/verify.
bool shouldShowTippyOnboardingOverlay(String? route) {
  return route == 'onboarding' || route == 'verify-email';
}

/// Password signup stays on verify-email until Firebase reports verified.
/// Matches web: unverified password never boots the dashboard.
String? effectiveOnboardingStatusRoute({
  String? statusRoute,
  bool passwordNeedsVerify = false,
  bool hasSignupClosedFloor = false,
  bool verifyFloorReleased = false,
}) {
  if (passwordNeedsVerify && !verifyFloorReleased) {
    return 'verify-email';
  }
  if (hasSignupClosedFloor &&
      !verifyFloorReleased &&
      statusRoute != 'app') {
    return 'verify-email';
  }
  return statusRoute;
}

/// Firebase authenticated ≠ boot MainTabView / feed / profile services.
bool shouldBootAuthenticatedAppShell({
  required bool activationCommitted,
  required bool isTesterSession,
  required bool testerSessionDismissed,
  String? statusRoute,
  required bool localOnboardingComplete,
}) {
  if (activationCommitted) {
    return true;
  }
  if (isTesterSession) {
    return testerSessionDismissed;
  }
  if (statusRoute == 'app') {
    return true;
  }
  return false;
}

/// Until ACTIVATED, keep the onboarding shell only.
bool shouldShowAuthenticatedOnboardingShell({
  required bool activationCommitted,
  required bool isTesterSession,
  required bool testerSessionDismissed,
  String? statusRoute,
  required bool localOnboardingComplete,
}) {
  if (activationCommitted) {
    return false;
  }
  if (isTesterSession) {
    return !testerSessionDismissed;
  }
  if (shouldShowTippyOnboardingOverlay(statusRoute)) {
    return true;
  }
  if (statusRoute == 'app') {
    return false;
  }
  return !localOnboardingComplete;
}
