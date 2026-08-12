/// Canonical onboarding destination resolver — mirrors
/// streamerstipReact/lib/onboarding/resolveOnboardingDestination.ts
library;

class OnboardingDestination {
  const OnboardingDestination({
    required this.lifecycle,
    required this.tippyStageHint,
    required this.allowApp,
    required this.reason,
    required this.photoStatus,
    required this.isLegacyComplete,
  });

  /// COMPLETE | TIPPY | VERIFY | CLASSIC | NONE
  final String lifecycle;
  final String? tippyStageHint;
  final bool allowApp;
  final String reason;
  final String photoStatus;
  final bool isLegacyComplete;
}

const String kOnboardingLifecycleVersion = '3';
const String kDefaultLegacyCutoffIso = '2026-03-01T00:00:00.000Z';

const Set<String> _guidedStages = <String>{
  'account_secured',
  'avatar',
  'display_name',
  'username',
  'bio',
  'platform_handles',
  'profile_review',
};

const Set<String> _postIdentityStages = <String>{
  'notifications',
  'creator_space_ready',
  'first_mission',
};

String readPhotoStatus(Map<String, dynamic>? userData) {
  if (userData == null) {
    return 'unknown';
  }
  final Map<String, dynamic> onboarding =
      (userData['onboarding'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
  final String status =
      (onboarding['photoStatus'] as String?)?.trim().toLowerCase() ?? '';
  if (status == 'skipped' || status == 'uploaded' || status == 'not_started') {
    return status;
  }
  final String avatar = ((userData['avatarURL'] as String?) ??
          (userData['avatarUrl'] as String?) ??
          (userData['photoURL'] as String?) ??
          '')
      .trim();
  if (avatar.isNotEmpty) {
    return 'uploaded';
  }
  if (onboarding['skippedAvatar'] == true) {
    return 'skipped';
  }
  return 'not_started';
}

bool _hasStickyComplete(
  Map<String, dynamic> userData,
  Map<String, dynamic> onboarding,
) {
  if ((onboarding['lifecycle'] as String?)?.toUpperCase() == 'COMPLETE') {
    return true;
  }
  if (onboarding['tippyFunnelCompleted'] == true &&
      onboarding['essentialProfileComplete'] == true) {
    return true;
  }
  if (onboarding['completed'] == true &&
      onboarding['tippyOnboardingV1Attached'] != true) {
    return true;
  }
  if (userData['hasCompletedOnboarding'] == true ||
      userData['onboardingComplete'] == true ||
      userData['onboardingCompleted'] == true) {
    return true;
  }
  if (onboarding['hasCompletedOnboarding'] == true ||
      onboarding['hasCompletedProductTour'] == true) {
    return true;
  }
  if (onboarding['landingChoice'] != null &&
      onboarding['essentialProfileComplete'] == true) {
    return true;
  }
  return false;
}

DateTime? _readCreatedAt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  try {
    // Firestore Timestamp
    // ignore: avoid_dynamic_calls
    return value.toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

bool _isLegacyExistingAccount({
  required Map<String, dynamic> userData,
  required Map<String, dynamic> onboarding,
  required String legacyCutoffIso,
}) {
  if (_hasStickyComplete(userData, onboarding)) {
    return true;
  }
  final bool tippyAttached = onboarding['tippyOnboardingV1Attached'] == true;
  final bool slim7 = onboarding['slim7Completed'] == true;
  final bool midTippy =
      (tippyAttached || slim7) && onboarding['tippyFunnelCompleted'] != true;
  if (midTippy) {
    return false;
  }
  final String username = ((userData['username'] as String?) ??
          (userData['usernameNormalized'] as String?) ??
          (userData['handle'] as String?) ??
          '')
      .trim();
  final String displayName = (userData['displayName'] as String?)?.trim() ?? '';
  if (username.isNotEmpty && displayName.isNotEmpty && !tippyAttached) {
    return true;
  }
  final DateTime? created = _readCreatedAt(userData['createdAt']);
  final DateTime? cutoff = DateTime.tryParse(legacyCutoffIso);
  if (created != null && cutoff != null && created.isBefore(cutoff)) {
    return true;
  }
  return false;
}

String _deriveTippyStageHint({
  required Map<String, dynamic> onboarding,
  required String photoStatus,
  required String? localTippyStage,
  required bool emailVerified,
  required bool isPasswordProvider,
}) {
  if (isPasswordProvider && !emailVerified) {
    return 'verify_email';
  }
  final bool essential = onboarding['essentialProfileComplete'] == true ||
      onboarding['creatorCardCompleted'] == true;
  if (essential) {
    if (onboarding['notificationsChoice'] == null &&
        onboarding['firstMissionChoice'] == null) {
      return 'notifications';
    }
    if (onboarding['landingChoice'] == null &&
        onboarding['firstMissionChoice'] == null) {
      return 'creator_space_ready';
    }
    return 'first_mission';
  }
  final String local = (localTippyStage ?? '').trim();
  if (_postIdentityStages.contains(local)) {
    return local;
  }
  if (_guidedStages.contains(local) &&
      local != 'account_secured' &&
      local != 'avatar') {
    return local;
  }
  if (local == 'avatar' &&
      (photoStatus == 'skipped' || photoStatus == 'uploaded')) {
    return 'display_name';
  }
  if (local == 'avatar' || local == 'account_secured') {
    return local;
  }
  if (photoStatus == 'skipped' || photoStatus == 'uploaded') {
    return 'display_name';
  }
  return 'account_secured';
}

OnboardingDestination resolveOnboardingDestination({
  required Map<String, dynamic>? userData,
  required bool emailVerified,
  required bool isPasswordProvider,
  String? localTippyStage,
  String legacyCutoffIso = kDefaultLegacyCutoffIso,
}) {
  final String photoStatus = readPhotoStatus(userData);
  if (userData == null) {
    if (isPasswordProvider && !emailVerified) {
      return const OnboardingDestination(
        lifecycle: 'VERIFY',
        tippyStageHint: 'verify_email',
        allowApp: false,
        reason: 'no_user_doc_needs_verify',
        photoStatus: 'unknown',
        isLegacyComplete: false,
      );
    }
    return OnboardingDestination(
      lifecycle: 'NONE',
      tippyStageHint: null,
      allowApp: false,
      reason: 'no_user_doc',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  final Map<String, dynamic> onboarding =
      (userData['onboarding'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
  final bool tippyAttached = onboarding['tippyOnboardingV1Attached'] == true;
  final bool slim7 = onboarding['slim7Completed'] == true;
  final bool tippyFunnelCompleted = onboarding['tippyFunnelCompleted'] == true ||
      onboarding['landingChoice'] != null;
  final bool essential = onboarding['essentialProfileComplete'] == true ||
      onboarding['creatorCardCompleted'] == true;
  final bool midTippy =
      (tippyAttached || slim7) && !(tippyFunnelCompleted && essential);

  if (_hasStickyComplete(userData, onboarding)) {
    return OnboardingDestination(
      lifecycle: 'COMPLETE',
      tippyStageHint: null,
      allowApp: true,
      reason: 'sticky_complete',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  if (_isLegacyExistingAccount(
    userData: userData,
    onboarding: onboarding,
    legacyCutoffIso: legacyCutoffIso,
  )) {
    return OnboardingDestination(
      lifecycle: 'COMPLETE',
      tippyStageHint: null,
      allowApp: true,
      reason: 'legacy_existing_account',
      photoStatus: photoStatus,
      isLegacyComplete: true,
    );
  }
  if (isPasswordProvider && !emailVerified && midTippy) {
    return OnboardingDestination(
      lifecycle: 'VERIFY',
      tippyStageHint: 'verify_email',
      allowApp: false,
      reason: 'tippy_needs_email_verify',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  if (midTippy) {
    return OnboardingDestination(
      lifecycle: 'TIPPY',
      tippyStageHint: _deriveTippyStageHint(
        onboarding: onboarding,
        photoStatus: photoStatus,
        localTippyStage: localTippyStage,
        emailVerified: emailVerified,
        isPasswordProvider: isPasswordProvider,
      ),
      allowApp: false,
      reason: 'tippy_in_progress',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  final bool classicInProgress = onboarding['completed'] != true &&
      onboarding['status'] == 'in_progress' &&
      !tippyAttached &&
      !slim7;
  // Classic is retired for new users — route into Tippy instead.
  if (classicInProgress) {
    return OnboardingDestination(
      lifecycle: 'TIPPY',
      tippyStageHint: (localTippyStage != null && localTippyStage.isNotEmpty)
          ? localTippyStage
          : 'welcome',
      allowApp: false,
      reason: 'tippy_replaces_classic',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  final String username = ((userData['username'] as String?) ??
          (userData['usernameNormalized'] as String?) ??
          (userData['handle'] as String?) ??
          '')
      .trim();
  if (username.isNotEmpty) {
    return OnboardingDestination(
      lifecycle: 'COMPLETE',
      tippyStageHint: null,
      allowApp: true,
      reason: 'established_username',
      photoStatus: photoStatus,
      isLegacyComplete: true,
    );
  }
  return OnboardingDestination(
    lifecycle: 'TIPPY',
    tippyStageHint: (localTippyStage != null && localTippyStage.isNotEmpty)
        ? localTippyStage
        : 'welcome',
    allowApp: false,
    reason: 'new_account_starts_tippy',
    photoStatus: photoStatus,
    isLegacyComplete: false,
  );
}

Map<String, dynamic> buildLifecycleCompletePayload({bool isLegacy = false}) {
  return <String, dynamic>{
    'hasCompletedOnboarding': true,
    'onboardingComplete': true,
    'onboardingCompleted': true,
    'onboarding': <String, dynamic>{
      'lifecycle': 'COMPLETE',
      'status': 'completed',
      'completed': true,
      'tippyFunnelCompleted': true,
      'essentialProfileComplete': true,
      'hasCompletedOnboarding': true,
      'version': 1,
      'onboardingVersion': int.tryParse(kOnboardingLifecycleVersion) ?? 3,
      if (isLegacy) 'legacyMigrated': true,
      if (isLegacy) 'migratedLegacyUser': true,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    },
  };
}
