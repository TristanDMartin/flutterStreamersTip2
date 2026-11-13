/// Compile-time backend target checks.
///
/// Production remains the default. A staging build must name
/// `streamerstip-stg` and must not fall back to production hosts.
library;

const String kProductionFirebaseProjectId = 'streamerstip-6cfdb';
const String kStagingFirebaseProjectId = 'streamerstip-stg';
const String kStagingSiteApiBase = 'https://staging.streamerstip.com';

const String kCompileTimeFirebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: kProductionFirebaseProjectId,
);

const String _stagingFirebaseApiKey = String.fromEnvironment(
  'STAGING_FIREBASE_API_KEY',
);
const String _stagingFirebaseAppId = String.fromEnvironment(
  'STAGING_FIREBASE_APP_ID',
);
const String _stagingFirebaseMessagingSenderId = String.fromEnvironment(
  'STAGING_FIREBASE_MESSAGING_SENDER_ID',
);
const String _stagingFirebaseIosBundleId = String.fromEnvironment(
  'STAGING_FIREBASE_IOS_BUNDLE_ID',
);
const String _stagingFirebaseStorageBucket = String.fromEnvironment(
  'STAGING_FIREBASE_STORAGE_BUCKET',
  defaultValue: 'streamerstip-stg.firebasestorage.app',
);

const String kDefaultIosBundleId = 'com.streamerstip.streamersTipApp';

class BackendIsolationException implements Exception {
  const BackendIsolationException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get hasCompleteStagingFirebaseOptions =>
    _stagingFirebaseApiKey.isNotEmpty &&
    _stagingFirebaseAppId.isNotEmpty &&
    _stagingFirebaseMessagingSenderId.isNotEmpty;

class StagingFirebaseFields {
  const StagingFirebaseFields({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.storageBucket,
    required this.iosBundleId,
    required this.authDomain,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String storageBucket;
  final String iosBundleId;
  final String authDomain;
}

StagingFirebaseFields requireStagingFirebaseFields() {
  if (!hasCompleteStagingFirebaseOptions) {
    throw const BackendIsolationException(
      'FIREBASE_PROJECT_ID=streamerstip-stg requires '
      'STAGING_FIREBASE_API_KEY, STAGING_FIREBASE_APP_ID, and '
      'STAGING_FIREBASE_MESSAGING_SENDER_ID. '
      'Refusing to fall back to production.',
    );
  }
  final String bundleId = _stagingFirebaseIosBundleId.isEmpty
      ? kDefaultIosBundleId
      : _stagingFirebaseIosBundleId;
  return StagingFirebaseFields(
    apiKey: _stagingFirebaseApiKey,
    appId: _stagingFirebaseAppId,
    messagingSenderId: _stagingFirebaseMessagingSenderId,
    storageBucket: _stagingFirebaseStorageBucket,
    iosBundleId: bundleId,
    authDomain: '$kStagingFirebaseProjectId.firebaseapp.com',
  );
}

bool isProductionSiteApi(String siteApiBase) {
  final String host = _siteHost(siteApiBase);
  return host == 'streamerstip.com' || host == 'www.streamerstip.com';
}

bool isStagingSiteApi(String siteApiBase) =>
    _siteHost(siteApiBase) == 'staging.streamerstip.com';

bool containsProductionProject(String url) =>
    url.contains(kProductionFirebaseProjectId);

String _siteHost(String siteApiBase) {
  final Uri? uri = Uri.tryParse(siteApiBase.trim());
  if (uri == null) return '';
  return uri.host.toLowerCase();
}

void assertBackendTargets({
  required String firebaseProjectId,
  required String siteApiBase,
  required String billingVerifyUrl,
  required String retentionTrackUrl,
  required bool hasStagingFirebaseOptions,
}) {
  final bool isProduction = firebaseProjectId == kProductionFirebaseProjectId;
  final bool isStaging = firebaseProjectId == kStagingFirebaseProjectId;
  if (!isProduction && !isStaging) {
    throw BackendIsolationException(
      'Unknown FIREBASE_PROJECT_ID=$firebaseProjectId. '
      'Refusing to initialize Firebase.',
    );
  }
  if (isStaging && isProductionSiteApi(siteApiBase)) {
    throw const BackendIsolationException(
      'Staging Firebase cannot call the production site API.',
    );
  }
  if (isProduction && isStagingSiteApi(siteApiBase)) {
    throw const BackendIsolationException(
      'Production Firebase cannot call the staging site API.',
    );
  }
  if (isStaging &&
      (containsProductionProject(billingVerifyUrl) ||
          containsProductionProject(retentionTrackUrl) ||
          isProductionSiteApi(billingVerifyUrl) ||
          isProductionSiteApi(retentionTrackUrl))) {
    throw const BackendIsolationException(
      'Staging Firebase cannot call production billing or retention.',
    );
  }
  if (isStaging && !hasStagingFirebaseOptions) {
    throw const BackendIsolationException(
      'Staging Firebase options are incomplete. '
      'Refusing to fall back to production.',
    );
  }
}

String? feedE2eIsolationFailure({
  required bool enabled,
  required String firebaseProjectId,
  required String siteApiBase,
  required String billingVerifyUrl,
  required String retentionTrackUrl,
  required bool hasStagingFirebaseOptions,
}) {
  if (!enabled) return null;
  if (firebaseProjectId != kStagingFirebaseProjectId) {
    return 'Refusing feed E2E against Firebase project '
        '$firebaseProjectId. Use $kStagingFirebaseProjectId.';
  }
  if (!isStagingSiteApi(siteApiBase)) {
    return 'Refusing feed E2E against site API $siteApiBase. '
        'Use $kStagingSiteApiBase.';
  }
  if (containsProductionProject(billingVerifyUrl) ||
      containsProductionProject(retentionTrackUrl)) {
    return 'Refusing feed E2E because billing or retention still '
        'targets $kProductionFirebaseProjectId.';
  }
  if (!hasStagingFirebaseOptions) {
    return 'Refusing feed E2E because staging Firebase options '
        'are incomplete.';
  }
  return null;
}
