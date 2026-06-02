/// Runtime flags for device QA / integration tests (dart-define only).
abstract final class QaRuntime {
  static const bool isMobileFeedE2e = bool.fromEnvironment(
    'RUN_MOBILE_FEED_E2E',
  );
}
