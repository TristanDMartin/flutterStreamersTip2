class AccountEnforcementResult {
  const AccountEnforcementResult({
    required this.destination,
    required this.canEnterApp,
    required this.legacyActive,
    this.reason,
  });

  /// app | deactivated | banned | unavailable | deleted
  final String destination;
  final bool canEnterApp;
  final bool legacyActive;
  final String? reason;
}

const String kBannedAccountTitle = 'Account suspended';
const String kBannedAccountBody =
    'Your StreamersTip account has been suspended because it did not meet our Community Guidelines or Terms of Service.';
const String kDeactivatedAccountTitle = 'Account deactivated';
const String kAccountUnavailableTitle = 'Account unavailable';
const String kAccountUnavailableBody =
    'This account is no longer available. Sign out to continue.';
const String kHelpAppealPath = '/feedback-help';
const String kHelpAppealUrl =
    'https://www.streamerstip.com/feedback-help';
const String kHelpAppealEmail = 'contact@streamerstip.com';
const String kRelationshipBlockIsNotAccountStatus =
    'relationship_block_is_not_account_status';

const Set<String> kCanonicalAccountStatuses = <String>{
  'active',
  'deactivated',
  'banned',
  'deleting',
  'deleted',
};

const Map<String, String> kSignupRestrictionCopy = <String, String>{
  'network_temporarily_restricted':
      'Account creation is temporarily restricted from this network. Please try again later.',
  'device_temporarily_restricted':
      'Account creation is temporarily restricted from this device. Please try again later.',
  'disposable_email':
      'Temporary email addresses are not allowed. Use a permanent email.',
  'signup_rate_limited':
      'Too many accounts were created recently. Please try again later.',
  'risk_review':
      'Account creation is temporarily restricted. Please try again later.',
};

const Set<String> _deviceSignals = <String>{
  'device_velocity_suspicious',
  'device_velocity_high',
  'device_restriction',
};
const Set<String> _networkSignals = <String>{
  'ip_velocity_suspicious',
  'ip_velocity_high',
  'ip_velocity_extreme',
  'ip_restriction',
};
const Set<String> _rateSignals = <String>{
  'ip_velocity_extreme',
  'device_velocity_high',
};

String normalizeAccountStatus(Object? raw) {
  if (raw is! String) {
    return '';
  }
  return raw.trim().toLowerCase();
}

bool isRelationshipBlockLabel(Object? raw) {
  return normalizeAccountStatus(raw) == 'blocked';
}

AccountEnforcementResult resolveAccountEnforcement(
  Object? accountStatus,
) {
  final String status = normalizeAccountStatus(accountStatus);
  if (status == 'blocked') {
    return const AccountEnforcementResult(
      destination: 'app',
      canEnterApp: true,
      legacyActive: false,
      reason: kRelationshipBlockIsNotAccountStatus,
    );
  }
  if (status.isEmpty) {
    return const AccountEnforcementResult(
      destination: 'app',
      canEnterApp: true,
      legacyActive: true,
      reason: 'legacy_active',
    );
  }
  if (status == 'active') {
    return const AccountEnforcementResult(
      destination: 'app',
      canEnterApp: true,
      legacyActive: false,
    );
  }
  if (status == 'deactivated') {
    return const AccountEnforcementResult(
      destination: 'deactivated',
      canEnterApp: false,
      legacyActive: false,
      reason: 'account_deactivated',
    );
  }
  if (status == 'banned' ||
      status == 'suspended' ||
      status == 'disabled') {
    return const AccountEnforcementResult(
      destination: 'banned',
      canEnterApp: false,
      legacyActive: false,
      reason: 'account_suspended',
    );
  }
  if (status == 'deleting') {
    return const AccountEnforcementResult(
      destination: 'unavailable',
      canEnterApp: false,
      legacyActive: false,
      reason: 'account_deleting',
    );
  }
  if (status == 'deleted') {
    return const AccountEnforcementResult(
      destination: 'deleted',
      canEnterApp: false,
      legacyActive: false,
      reason: 'account_deleted',
    );
  }
  return const AccountEnforcementResult(
    destination: 'unavailable',
    canEnterApp: false,
    legacyActive: false,
    reason: 'unknown_account_status',
  );
}

String mapSignupRestrictionReason({
  String? code,
  List<String>? reasons,
  String? restrictionKind,
  String? decision,
}) {
  final String normalizedCode = (code ?? '').trim().toUpperCase();
  final List<String> normalizedReasons = (reasons ?? <String>[])
      .map((String value) => value.trim().toLowerCase())
      .toList();
  final String kind = (restrictionKind ?? '').trim().toLowerCase();
  final String normalizedDecision = (decision ?? '').trim().toUpperCase();
  if (normalizedCode == 'DISPOSABLE_EMAIL' ||
      normalizedReasons.contains('disposable_email')) {
    return 'disposable_email';
  }
  final bool hasDevice = kind == 'device' ||
      kind == 'both' ||
      normalizedReasons.any(_deviceSignals.contains);
  final bool hasNetwork = kind == 'ip' ||
      kind == 'both' ||
      normalizedReasons.any(_networkSignals.contains);
  final bool hasRate = normalizedReasons.any(_rateSignals.contains);
  if (hasDevice && !hasNetwork) {
    return 'device_temporarily_restricted';
  }
  if (hasRate && hasNetwork && hasDevice) {
    return 'signup_rate_limited';
  }
  if (hasRate && !hasDevice) {
    return 'signup_rate_limited';
  }
  if (hasNetwork) {
    return 'network_temporarily_restricted';
  }
  if (hasDevice) {
    return 'device_temporarily_restricted';
  }
  if (normalizedCode == 'SIGNUP_CHALLENGE_REQUIRED' ||
      normalizedDecision == 'CHALLENGE') {
    return 'risk_review';
  }
  if (normalizedCode == 'SIGNUP_BLOCKED' ||
      normalizedDecision == 'BLOCK') {
    return 'network_temporarily_restricted';
  }
  return 'risk_review';
}

String signupRestrictionMessage(String reason) {
  return kSignupRestrictionCopy[reason] ??
      kSignupRestrictionCopy['risk_review']!;
}

({String reason, String message}) messageFromSignupRestriction({
  String? code,
  String? reason,
  List<String>? reasons,
  String? restrictionKind,
  String? decision,
}) {
  final String resolved = (reason ?? '').trim().isNotEmpty
      ? reason!.trim()
      : mapSignupRestrictionReason(
          code: code,
          reasons: reasons,
          restrictionKind: restrictionKind,
          decision: decision,
        );
  return (
    reason: resolved,
    message: signupRestrictionMessage(resolved),
  );
}
