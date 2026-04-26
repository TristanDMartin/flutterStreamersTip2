/// Full URL for **POST** mobile purchase verification (JSON body).
///
/// Backend must verify with Apple/Google, then update Firestore entitlements.
/// Override at build time:
/// `--dart-define=MOBILE_BILLING_VERIFY_URL=https://us-central1-<PROJECT_ID>.cloudfunctions.net/verifyMobilePurchase`
///
/// Expected JSON body: [MobilePurchaseVerificationPayload.toJson].
const String kMobileBillingVerifyUrl = String.fromEnvironment(
  'MOBILE_BILLING_VERIFY_URL',
  defaultValue: '',
);

/// `true` when the app was built with a non-empty
/// [kMobileBillingVerifyUrl] (server can receive receipt POSTs after IAP).
bool isMobileBillingVerifyUrlConfigured() =>
    kMobileBillingVerifyUrl.trim().isNotEmpty;
