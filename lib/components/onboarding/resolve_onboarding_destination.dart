/// Canonical onboarding destination resolver — mirrors
/// streamerstipReact/lib/onboarding/resolveOnboardingDestination.ts
library;

import '../../features/onboarding_tippy/tippy_onboarding_contract.dart';

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
  'username',
  'bio',
  'platform_handles',
  'profile_review',
};

const Set<String> _postIdentityStages = <String>{
  'twitch_connect',
  'notifications',
  'creator_space_ready',
  'first_mission',
};

const Set<String> _preVerifyTippyStages = <String>{
  'welcome',
  'questions',
  'dna_reveal',
  'signup',
  'verify_email',
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

bool _isIdentityRecycled(Map<String, dynamic> userData) {
  return userData['identityRecycled'] == true;
}

bool _isFirstMissionResolved(Map<String, dynamic> onboarding) {
  return onboarding['firstMissionChoice'] == 'accept' ||
      onboarding['firstMissionChoice'] == 'skip';
}

bool _isFunnelChoiceComplete(Map<String, dynamic> onboarding) {
  return onboarding['landingChoice'] != null ||
      _isFirstMissionResolved(onboarding);
}

/// Recycled Auth identities may only COMPLETE via Tippy on this UID.
bool _hasTippyFunnelCompleteOnThisAccount(Map<String, dynamic> onboarding) {
  final bool tippyDone = onboarding['tippyFunnelCompleted'] == true;
  final bool essential = onboarding['essentialProfileComplete'] == true ||
      onboarding['creatorCardCompleted'] == true;
  if (tippyDone && essential) {
    return true;
  }
  return (onboarding['lifecycle'] as String?)?.toUpperCase() == 'COMPLETE' &&
      tippyDone;
}

bool _isV1Incomplete(Map<String, dynamic> onboarding) {
  final Object? version = onboarding['version'];
  final bool isV1 = version == 1 || version == '1';
  return isV1 && onboarding['completed'] != true;
}

bool _hasStickyComplete(
  Map<String, dynamic> userData,
  Map<String, dynamic> onboarding,
) {
  if (_isIdentityRecycled(userData)) {
    return _hasTippyFunnelCompleteOnThisAccount(onboarding);
  }
  if ((onboarding['lifecycle'] as String?)?.toUpperCase() == 'COMPLETE') {
    return true;
  }
  if (onboarding['tippyFunnelCompleted'] == true &&
      onboarding['essentialProfileComplete'] == true) {
    return true;
  }
  // V1 mid-funnel with stale top-level flags is not sticky COMPLETE.
  if (_isV1Incomplete(onboarding)) {
    return false;
  }
  if (onboarding['completed'] == true &&
      onboarding['tippyOnboardingV1Attached'] != true) {
    return true;
  }
  final bool tippyAttached = onboarding['tippyOnboardingV1Attached'] == true;
  final bool slim7 = onboarding['slim7Completed'] == true;
  if (tippyAttached || slim7) {
    return false;
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
  // Deleted → recreated accounts are never legacy COMPLETE.
  if (_isIdentityRecycled(userData)) {
    return false;
  }
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
  // Classic / V1 mid-flight is incomplete — resume Tippy, not Home.
  if (onboarding['completed'] != true &&
      onboarding['status'] == 'in_progress') {
    return false;
  }
  final DateTime? created = _readCreatedAt(userData['createdAt']);
  final DateTime? cutoff = DateTime.tryParse(legacyCutoffIso);
  if (created != null && cutoff != null && created.isBefore(cutoff)) {
    return true;
  }
  // Pre-Tippy established profiles without Tippy attach + completion signal.
  final String username = ((userData['username'] as String?) ??
          (userData['usernameNormalized'] as String?) ??
          (userData['handle'] as String?) ??
          '')
      .trim();
  final String displayName = (userData['displayName'] as String?)?.trim() ?? '';
  if (username.isNotEmpty &&
      displayName.isNotEmpty &&
      !tippyAttached &&
      (userData['hasCompletedOnboarding'] == true ||
          userData['onboardingCompleted'] == true ||
          onboarding['hasCompletedOnboarding'] == true)) {
    return true;
  }
  return false;
}

String _normalizeLifecycleStageHint(String? raw) {
  final String local = (raw ?? '').trim();
  if (local == 'display_name') {
    return 'username';
  }
  return local;
}

/// Server tippyStage wins. localTippyStage is ignored when tippyStage is set.
String? _authoritativeTippyStage(Map<String, dynamic>? userData) {
  if (userData == null) {
    return null;
  }
  final Map<String, dynamic> onboarding =
      (userData['onboarding'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
  final String? raw = (onboarding['tippyStage'] as String?)?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return _normalizeLifecycleStageHint(raw);
}

String _hintAfterEmailVerified(String? serverTippyStage) {
  final String stage = _normalizeLifecycleStageHint(serverTippyStage);
  if (stage.isEmpty || _preVerifyTippyStages.contains(stage)) {
    return 'account_secured';
  }
  return stage;
}

String _newAccountTippyHint({
  required bool emailVerified,
  required bool isPasswordProvider,
  required String? serverTippyStage,
}) {
  if (emailVerified) {
    return _hintAfterEmailVerified(serverTippyStage);
  }
  if (isPasswordProvider) {
    return 'verify_email';
  }
  final String stage = _normalizeLifecycleStageHint(serverTippyStage);
  if (stage.isNotEmpty) {
    return stage;
  }
  return 'welcome';
}

String _deriveTippyStageHint({
  required Map<String, dynamic> onboarding,
  required String photoStatus,
  required String? serverTippyStage,
  required bool emailVerified,
  required bool isPasswordProvider,
}) {
  if (isPasswordProvider && !emailVerified) {
    return 'verify_email';
  }
  final bool essential = onboarding['essentialProfileComplete'] == true ||
      onboarding['creatorCardCompleted'] == true;
  if (essential) {
    final String twitchStatus =
        ((onboarding['twitchConnectionStatus'] as String?) ?? '')
            .trim()
            .toUpperCase();
    final Object? selected = onboarding['selectedPlatforms'];
    final List<String> selectedList = selected is List
        ? selected
            .map((Object? e) => e.toString().trim().toLowerCase())
            .where((String id) => id.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    if (TippyOnboardingStages.hasSelectedTwitchInDna(
          const <String, dynamic>{},
          selectedPlatforms: selectedList,
        ) &&
        twitchStatus != 'SKIPPED' &&
        twitchStatus != 'CONNECTED') {
      return 'twitch_connect';
    }
    if (onboarding['landingChoice'] == null &&
        onboarding['firstMissionChoice'] == null) {
      return 'creator_space_ready';
    }
    return 'first_mission';
  }
  final String stage = _normalizeLifecycleStageHint(serverTippyStage);
  if (_postIdentityStages.contains(stage)) {
    return stage;
  }
  if (_guidedStages.contains(stage) &&
      stage != 'account_secured' &&
      stage != 'avatar') {
    return stage;
  }
  if (stage == 'avatar' &&
      (photoStatus == 'skipped' || photoStatus == 'uploaded')) {
    return 'username';
  }
  if (stage == 'avatar' || stage == 'account_secured') {
    return stage;
  }
  if (photoStatus == 'skipped' || photoStatus == 'uploaded') {
    return 'username';
  }
  return 'account_secured';
}

OnboardingDestination resolveOnboardingDestination({
  required Map<String, dynamic>? userData,
  required bool emailVerified,
  required bool isPasswordProvider,
  @Deprecated('Ignored when onboarding.tippyStage is set. Status must not pass this.')
  String? localTippyStage,
  String legacyCutoffIso = kDefaultLegacyCutoffIso,
}) {
  final String photoStatus = readPhotoStatus(userData);
  final String? serverTippyStage = _authoritativeTippyStage(userData);
  if (userData == null) {
    if (!emailVerified) {
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
      lifecycle: 'TIPPY',
      tippyStageHint: _hintAfterEmailVerified(serverTippyStage),
      allowApp: false,
      reason: 'no_user_doc_verified',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  final Map<String, dynamic> onboarding =
      (userData['onboarding'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
  final String lifecycle =
      ((onboarding['lifecycle'] as String?) ?? '').trim().toUpperCase();
  if (lifecycle == 'COMPLETE') {
    return OnboardingDestination(
      lifecycle: 'COMPLETE',
      tippyStageHint: null,
      allowApp: true,
      reason: 'sticky_complete',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  final bool tippyAttached = onboarding['tippyOnboardingV1Attached'] == true;
  final bool slim7 = onboarding['slim7Completed'] == true;
  final bool tippyFunnelCompleted = onboarding['tippyFunnelCompleted'] == true;
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
  // After explicit account deletion + recreate, ignore stale local guest
  // state until this UID passes email verification. Verified password
  // sessions must continue at identity — never Meet Tippy again.
  final bool ignoreLocalResume = onboarding['ignoreLocalResume'] == true ||
      onboarding['forceWelcome'] == true;
  if (ignoreLocalResume &&
      _isIdentityRecycled(userData) &&
      !(emailVerified && isPasswordProvider)) {
    return OnboardingDestination(
      lifecycle: 'TIPPY',
      tippyStageHint: 'welcome',
      allowApp: false,
      reason: 'identity_recycled_restart',
      photoStatus: photoStatus,
      isLegacyComplete: false,
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
        serverTippyStage: serverTippyStage,
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
      tippyStageHint: _newAccountTippyHint(
        emailVerified: emailVerified,
        isPasswordProvider: isPasswordProvider,
        serverTippyStage: serverTippyStage,
      ),
      allowApp: false,
      reason: 'tippy_replaces_classic',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  // Same email/OAuth/username after delete must restart Tippy from Welcome
  // (only when this UID has not already started Tippy — midTippy handled above).
  // Password accounts that already verified continue identity, never rewind.
  if (_isIdentityRecycled(userData)) {
    return OnboardingDestination(
      lifecycle: 'TIPPY',
      tippyStageHint: emailVerified && isPasswordProvider
          ? _hintAfterEmailVerified(serverTippyStage)
          : 'welcome',
      allowApp: false,
      reason: 'identity_recycled_restart',
      photoStatus: photoStatus,
      isLegacyComplete: false,
    );
  }
  final String username = ((userData['username'] as String?) ??
          (userData['usernameNormalized'] as String?) ??
          (userData['handle'] as String?) ??
          '')
      .trim();
  // Username alone is not enough for brand-new / post-cutoff Tippy accounts.
  // Prefer sticky COMPLETE, legacy cutoff, or Tippy funnel completion.
  if (username.isNotEmpty &&
      (userData['hasCompletedOnboarding'] == true ||
          userData['onboardingCompleted'] == true ||
          onboarding['hasCompletedOnboarding'] == true ||
          onboarding['completed'] == true)) {
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
    tippyStageHint: _newAccountTippyHint(
      emailVerified: emailVerified,
      isPasswordProvider: isPasswordProvider,
      serverTippyStage: serverTippyStage,
    ),
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
      'version': int.tryParse(kOnboardingLifecycleVersion) ?? 3,
      'onboardingVersion': int.tryParse(kOnboardingLifecycleVersion) ?? 3,
      if (isLegacy) 'legacyMigrated': true,
      if (isLegacy) 'migratedLegacyUser': true,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    },
  };
}
