import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/core/backend/backend_isolation.dart';
import 'package:streamers_tip/core/backend/cloudflare_worker_base.dart';
import 'package:streamers_tip/core/backend/write_endpoint_urls.dart';
import 'package:streamers_tip/features/content_planning/content_planning_api_client.dart';
import 'package:streamers_tip/features/creator_score/creator_score_service.dart';
import 'package:streamers_tip/features/gamification/gamification_backend_config.dart';
import 'package:streamers_tip/services/mux_upload_service.dart';

void main() {
  const String stagingBilling =
      'https://us-central1-streamerstip-stg.cloudfunctions.net/verifyMobilePurchase';
  const String stagingRetention =
      'https://us-central1-streamerstip-stg.cloudfunctions.net/apiRetentionTrack';
  const String productionBilling =
      'https://us-central1-streamerstip-6cfdb.cloudfunctions.net/verifyMobilePurchase';
  const String productionRetention =
      'https://us-central1-streamerstip-6cfdb.cloudfunctions.net/apiRetentionTrack';
  const List<String> productionWrites = <String>[
    kProductionCloudflareWorkerBase,
  ];
  const List<String> stagingWrites = <String>[
    'https://staging-worker.invalid',
  ];

  test('production defaults stay paired', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kProductionFirebaseProjectId,
        siteApiBase: 'https://streamerstip.com',
        billingVerifyUrl: productionBilling,
        retentionTrackUrl: productionRetention,
        hasStagingFirebaseOptions: false,
        cloudflareWriteUrls: productionWrites,
      ),
      returnsNormally,
    );
  });

  test('complete staging targets are accepted', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kStagingFirebaseProjectId,
        siteApiBase: kStagingSiteApiBase,
        billingVerifyUrl: stagingBilling,
        retentionTrackUrl: stagingRetention,
        hasStagingFirebaseOptions: true,
        cloudflareWriteUrls: stagingWrites,
      ),
      returnsNormally,
    );
  });

  test('staging targets stay paired when options exist', () {
    expect(isStagingSiteApi('https://staging.streamerstip.com'), isTrue);
    expect(isProductionSiteApi('https://www.streamerstip.com/api'), isTrue);
    expect(isProductionSiteApi('https://staging.streamerstip.com'), isFalse);
  });

  test('staging Firebase refuses the production site', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kStagingFirebaseProjectId,
        siteApiBase: 'https://streamerstip.com',
        billingVerifyUrl: stagingBilling,
        retentionTrackUrl: stagingRetention,
        hasStagingFirebaseOptions: true,
        cloudflareWriteUrls: productionWrites,
      ),
      throwsA(isA<BackendIsolationException>()),
    );
  });

  test('production Firebase refuses the staging site', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kProductionFirebaseProjectId,
        siteApiBase: 'https://staging.streamerstip.com',
        billingVerifyUrl: productionBilling,
        retentionTrackUrl: productionRetention,
        hasStagingFirebaseOptions: false,
        cloudflareWriteUrls: productionWrites,
      ),
      throwsA(isA<BackendIsolationException>()),
    );
  });

  test('unknown Firebase project is refused', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: 'other-project',
        siteApiBase: 'https://streamerstip.com',
        billingVerifyUrl: productionBilling,
        retentionTrackUrl: productionRetention,
        hasStagingFirebaseOptions: false,
        cloudflareWriteUrls: productionWrites,
      ),
      throwsA(isA<BackendIsolationException>()),
    );
  });

  test('staging refuses production billing and retention', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kStagingFirebaseProjectId,
        siteApiBase: kStagingSiteApiBase,
        billingVerifyUrl: productionBilling,
        retentionTrackUrl: stagingRetention,
        hasStagingFirebaseOptions: true,
        cloudflareWriteUrls: productionWrites,
      ),
      throwsA(isA<BackendIsolationException>()),
    );
  });

  test('staging refuses incomplete options', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kStagingFirebaseProjectId,
        siteApiBase: kStagingSiteApiBase,
        billingVerifyUrl: stagingBilling,
        retentionTrackUrl: stagingRetention,
        hasStagingFirebaseOptions: false,
        cloudflareWriteUrls: productionWrites,
      ),
      throwsA(isA<BackendIsolationException>()),
    );
  });

  test('disabled feed E2E does not require staging', () {
    expect(
      feedE2eIsolationFailure(
        enabled: false,
        firebaseProjectId: kProductionFirebaseProjectId,
        siteApiBase: 'https://streamerstip.com',
        billingVerifyUrl: productionBilling,
        retentionTrackUrl: productionRetention,
        hasStagingFirebaseOptions: false,
        cloudflareWriteUrls: productionWrites,
      ),
      isNull,
    );
  });

  test('enabled feed E2E refuses production', () {
    final String? actual = feedE2eIsolationFailure(
      enabled: true,
      firebaseProjectId: kProductionFirebaseProjectId,
      siteApiBase: 'https://streamerstip.com',
      billingVerifyUrl: productionBilling,
      retentionTrackUrl: productionRetention,
      hasStagingFirebaseOptions: false,
      cloudflareWriteUrls: productionWrites,
    );
    expect(actual, contains('streamerstip-stg'));
  });

  test('enabled feed E2E refuses a production site API', () {
    final String? actual = feedE2eIsolationFailure(
      enabled: true,
      firebaseProjectId: kStagingFirebaseProjectId,
      siteApiBase: 'https://www.streamerstip.com',
      billingVerifyUrl: stagingBilling,
      retentionTrackUrl: stagingRetention,
      hasStagingFirebaseOptions: true,
      cloudflareWriteUrls: productionWrites,
    );
    expect(actual, contains('staging.streamerstip.com'));
  });

  test('enabled feed E2E refuses incomplete staging options', () {
    final String? actual = feedE2eIsolationFailure(
      enabled: true,
      firebaseProjectId: kStagingFirebaseProjectId,
      siteApiBase: kStagingSiteApiBase,
      billingVerifyUrl: stagingBilling,
      retentionTrackUrl: stagingRetention,
      hasStagingFirebaseOptions: false,
      cloudflareWriteUrls: productionWrites,
    );
    expect(actual, contains('incomplete'));
  });

  test('staging refuses the production Cloudflare worker', () {
    expect(
      () => assertBackendTargets(
        firebaseProjectId: kStagingFirebaseProjectId,
        siteApiBase: kStagingSiteApiBase,
        billingVerifyUrl: stagingBilling,
        retentionTrackUrl: stagingRetention,
        hasStagingFirebaseOptions: true,
        cloudflareWriteUrls: productionWrites,
      ),
      throwsA(isA<BackendIsolationException>()),
    );
  });

  test('enabled feed E2E refuses the production Cloudflare worker', () {
    final String? actual = feedE2eIsolationFailure(
      enabled: true,
      firebaseProjectId: kStagingFirebaseProjectId,
      siteApiBase: kStagingSiteApiBase,
      billingVerifyUrl: stagingBilling,
      retentionTrackUrl: stagingRetention,
      hasStagingFirebaseOptions: true,
      cloudflareWriteUrls: productionWrites,
    );
    expect(actual, contains('production Cloudflare worker'));
  });

  test('release defaults still name the production worker', () {
    expect(kCloudflareWorkerBaseUrl, kProductionCloudflareWorkerBase);
    expect(muxWorkerBaseUrl, kProductionCloudflareWorkerBase);
    expect(kGamificationEventsBaseUrl, kProductionCloudflareWorkerBase);
    expect(kContentPlanningWorkerBase, kProductionCloudflareWorkerBase);
    expect(kCreatorScoreApiBase, kProductionCloudflareWorkerBase);
    expect(
      kCompileTimeCloudflareWriteUrls,
      everyElement(kProductionCloudflareWorkerBase),
    );
  });
}
