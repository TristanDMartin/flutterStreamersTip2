const Duration kEmailVerificationIntentTtl = Duration(hours: 24);

const List<String> _productionOrigins = <String>[
  'https://streamerstip.com',
  'https://www.streamerstip.com',
  'https://beta.streamerstip.com',
];

const String kProductionEmailVerificationOrigin = 'https://streamerstip.com';

final RegExp _localOrigin = RegExp(
  r'^https?://(localhost|127\.0\.0\.1)(:\d+)?$',
  caseSensitive: false,
);

enum VerificationIdentityStatus {
  ready,
  notVerified,
  signedOut,
  mismatch,
}

class VerificationIdentityResult {
  const VerificationIdentityResult({
    required this.status,
    this.reason,
  });

  final VerificationIdentityStatus status;
  final String? reason;
}

class EmailVerificationIntent {
  const EmailVerificationIntent({
    required this.uid,
    required this.normalizedEmail,
    required this.origin,
    required this.createdAt,
    required this.expiresAt,
    this.onboardingSessionId,
    this.consumedAt,
  });

  final String uid;
  final String normalizedEmail;
  final String? onboardingSessionId;
  final String origin;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? consumedAt;
}

String normalizeVerificationEmail(String email) => email.trim().toLowerCase();

bool isLocalVerificationOrigin(String origin) {
  final String normalized = origin.trim().replaceAll(RegExp(r'/$'), '');
  return _localOrigin.hasMatch(normalized);
}

bool isAllowedVerificationOrigin(String origin) {
  final String normalized = origin.trim().replaceAll(RegExp(r'/$'), '');
  if (normalized.isEmpty) {
    return false;
  }
  if (_productionOrigins.contains(normalized)) {
    return true;
  }
  return _localOrigin.hasMatch(normalized);
}

String resolveVerificationContinueOrigin(String? rawOrigin) {
  final String origin = (rawOrigin ?? '').trim().replaceAll(RegExp(r'/$'), '');
  if (!isAllowedVerificationOrigin(origin)) {
    throw StateError('UNTRUSTED_VERIFICATION_ORIGIN');
  }
  return origin;
}

String sanitizeVerificationResumePath(String? raw) {
  final String path = (raw ?? '').trim();
  if (!path.startsWith('/') || path.startsWith('//')) {
    return '';
  }
  if (path.contains('://') || path.contains('\\')) {
    return '';
  }
  if (!RegExp(r'^/[A-Za-z0-9/_-]*$').hasMatch(path)) {
    return '';
  }
  if (path == '/') {
    return '';
  }
  return path;
}

String buildEmailVerificationContinueUrl({
  required String origin,
  required String intentUid,
  String? resumePath,
}) {
  final String allowed = resolveVerificationContinueOrigin(origin);
  final String uid = intentUid.trim();
  if (uid.isEmpty) {
    throw StateError('VERIFICATION_INTENT_UID_REQUIRED');
  }
  final String resume = sanitizeVerificationResumePath(resumePath).isNotEmpty
      ? sanitizeVerificationResumePath(resumePath)
      : '/onboarding';
  final Uri uri = Uri.parse('$allowed/verify-email').replace(
    queryParameters: <String, String>{
      'intent': uid,
      'return': resume,
    },
  );
  return uri.toString();
}

({String uid, String email}) resolveVerificationIntentOwner({
  String? queryIntentUid,
  String? storedUid,
  String? storedEmail,
  String? actionEmail,
}) {
  return (
    uid: (queryIntentUid ?? storedUid ?? '').trim(),
    email: normalizeVerificationEmail(storedEmail ?? actionEmail ?? ''),
  );
}

bool shouldAdoptCurrentUserForRecycledIntent({
  required String intendedUid,
  required String intendedEmail,
  required String? currentUid,
  required String? currentEmail,
  required bool currentEmailVerified,
}) {
  final String activeUid = (currentUid ?? '').trim();
  final String expectedUid = intendedUid.trim();
  if (activeUid.isEmpty || expectedUid.isEmpty || activeUid == expectedUid) {
    return false;
  }
  final String activeEmail = currentEmail == null
      ? ''
      : normalizeVerificationEmail(currentEmail);
  final String expectedEmail = normalizeVerificationEmail(intendedEmail);
  if (activeEmail.isEmpty) {
    return false;
  }
  if (expectedEmail.isNotEmpty && expectedEmail == activeEmail) {
    return true;
  }
  return expectedEmail.isEmpty && !currentEmailVerified;
}

({String uid, String email}) selectVerificationIntentOwner({
  String? queryIntentUid,
  String? storedUid,
  String? storedEmail,
  String? actionEmail,
  String? currentUid,
  String? currentEmail,
  bool currentEmailVerified = false,
  String? serverIntentUid,
  String? serverIntentEmail,
}) {
  final ({String uid, String email}) parsed = resolveVerificationIntentOwner(
    queryIntentUid: queryIntentUid,
    storedUid: storedUid,
    storedEmail: storedEmail,
    actionEmail: actionEmail,
  );
  final String activeUid = (currentUid ?? '').trim();
  final String savedUid = (storedUid ?? '').trim();
  final String serverUid = (serverIntentUid ?? '').trim();
  final String activeEmail = currentEmail == null
      ? ''
      : normalizeVerificationEmail(currentEmail);
  final String serverEmail = serverIntentEmail == null
      ? ''
      : normalizeVerificationEmail(serverIntentEmail);
  if (activeUid.isNotEmpty && serverUid.isNotEmpty && activeUid == serverUid) {
    return (
      uid: activeUid,
      email: serverEmail.isNotEmpty
          ? serverEmail
          : (activeEmail.isNotEmpty ? activeEmail : parsed.email),
    );
  }
  if (activeUid.isNotEmpty && savedUid.isNotEmpty && activeUid == savedUid) {
    final String stored = normalizeVerificationEmail(storedEmail ?? '');
    return (
      uid: activeUid,
      email: stored.isNotEmpty
          ? stored
          : (activeEmail.isNotEmpty ? activeEmail : parsed.email),
    );
  }
  if (shouldAdoptCurrentUserForRecycledIntent(
    intendedUid: serverUid.isNotEmpty ? serverUid : parsed.uid,
    intendedEmail: serverEmail.isNotEmpty ? serverEmail : parsed.email,
    currentUid: activeUid,
    currentEmail: activeEmail,
    currentEmailVerified: currentEmailVerified,
  )) {
    return (
      uid: activeUid,
      email: activeEmail.isNotEmpty
          ? activeEmail
          : (serverEmail.isNotEmpty ? serverEmail : parsed.email),
    );
  }
  return parsed;
}

EmailVerificationIntent createEmailVerificationIntent({
  required String uid,
  required String email,
  required String origin,
  String? onboardingSessionId,
  DateTime? now,
}) {
  final DateTime createdAt = now ?? DateTime.now().toUtc();
  final String trimmedUid = uid.trim();
  final String normalizedEmail = normalizeVerificationEmail(email);
  if (trimmedUid.isEmpty || normalizedEmail.isEmpty) {
    throw StateError('VERIFICATION_INTENT_REQUIRED');
  }
  return EmailVerificationIntent(
    uid: trimmedUid,
    normalizedEmail: normalizedEmail,
    onboardingSessionId: onboardingSessionId?.trim(),
    origin: resolveVerificationContinueOrigin(origin),
    createdAt: createdAt,
    expiresAt: createdAt.add(kEmailVerificationIntentTtl),
  );
}

bool isEmailVerificationIntentExpired(
  EmailVerificationIntent intent, {
  DateTime? now,
}) {
  final DateTime current = now ?? DateTime.now().toUtc();
  return intent.consumedAt != null || current.isAfter(intent.expiresAt);
}

VerificationIdentityResult evaluateVerificationIdentity({
  required String intendedUid,
  required String intendedEmail,
  required String? currentUid,
  required String? currentEmail,
  required bool emailVerified,
}) {
  final String expectedUid = intendedUid.trim();
  final String expectedEmail = normalizeVerificationEmail(intendedEmail);
  final String? activeUid = currentUid?.trim();
  final String? activeEmail = currentEmail == null
      ? null
      : normalizeVerificationEmail(currentEmail);
  if (activeUid == null || activeUid.isEmpty) {
    return const VerificationIdentityResult(
      status: VerificationIdentityStatus.signedOut,
    );
  }
  if (expectedUid.isEmpty || activeUid != expectedUid) {
    return const VerificationIdentityResult(
      status: VerificationIdentityStatus.mismatch,
      reason: 'uid',
    );
  }
  if (expectedEmail.isEmpty ||
      activeEmail == null ||
      activeEmail != expectedEmail) {
    return const VerificationIdentityResult(
      status: VerificationIdentityStatus.mismatch,
      reason: 'email',
    );
  }
  if (!emailVerified) {
    return const VerificationIdentityResult(
      status: VerificationIdentityStatus.notVerified,
    );
  }
  return const VerificationIdentityResult(
    status: VerificationIdentityStatus.ready,
  );
}

bool isIntendedVerificationUser({
  required String intendedUid,
  required String intendedEmail,
  required String? currentUid,
  required String? currentEmail,
}) {
  return evaluateVerificationIdentity(
    intendedUid: intendedUid,
    intendedEmail: intendedEmail,
    currentUid: currentUid,
    currentEmail: currentEmail,
    emailVerified: true,
  ).status ==
      VerificationIdentityStatus.ready;
}

/// Stored intent, then the live unverified signup user after a remount.
({String uid, String email}) resolveLiveVerificationOwner({
  String? storedUid,
  String? storedEmail,
  String? currentUid,
  String? currentEmail,
  bool currentEmailVerified = false,
}) {
  final ({String uid, String email}) selected = selectVerificationIntentOwner(
    storedUid: storedUid,
    storedEmail: storedEmail,
    currentUid: currentUid,
    currentEmail: currentEmail,
    currentEmailVerified: currentEmailVerified,
  );
  if (selected.uid.isNotEmpty && selected.email.isNotEmpty) {
    return selected;
  }
  final String uid = (currentUid ?? '').trim();
  final String email = currentEmail == null
      ? ''
      : normalizeVerificationEmail(currentEmail);
  if (uid.isEmpty || email.isEmpty || currentEmailVerified) {
    return selected;
  }
  return (uid: uid, email: email);
}
