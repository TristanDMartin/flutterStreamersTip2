import 'dart:async';

import 'tippy_onboarding_contract.dart';
import '../../services/product_event_tracking_service.dart';

/// Thin analytics facade — wire to product events / Firebase as available.
class TippyOnboardingAnalyticsTracker {
  const TippyOnboardingAnalyticsTracker();

  void track(String event,
      [Map<String, Object?> params = const <String, Object?>{}]) {
    // ignore: avoid_print
    assert(() {
      // Keep debug visibility without shipping noisy logs in release.
      return true;
    }());
    // Product event sink is shared with website TippyOnboardingAnalytics names.
    _emit(event, params);
  }

  void started({required String sessionId}) {
    track(TippyOnboardingAnalytics.started, <String, Object?>{
      'sessionId': sessionId,
    });
    unawaited(
      ProductEventTrackingService.instance.onboardingStarted(
        sessionId: sessionId,
      ),
    );
  }

  void stepCompleted({
    required String sessionId,
    required String stage,
    int? questionIndex,
  }) {
    track(TippyOnboardingAnalytics.stepCompleted, <String, Object?>{
      'sessionId': sessionId,
      'stage': stage,
      if (questionIndex != null) 'questionIndex': questionIndex,
    });
  }

  void questionsCompleted({required String sessionId}) {
    track(TippyOnboardingAnalytics.questionsCompleted, <String, Object?>{
      'sessionId': sessionId,
    });
  }

  void signupAttached({required String sessionId}) {
    track(TippyOnboardingAnalytics.signupAttached, <String, Object?>{
      'sessionId': sessionId,
    });
  }

  void signupStarted({required String sessionId}) {
    track(TippyOnboardingAnalytics.signupStarted, <String, Object?>{
      'sessionId': sessionId,
    });
  }

  void landingChoice({
    required String sessionId,
    required String choice,
  }) {
    track(TippyOnboardingAnalytics.landingChoice, <String, Object?>{
      'sessionId': sessionId,
      'choice': choice,
    });
  }

  void completed({
    required String sessionId,
    DateTime? startedAt,
    DateTime? firstResultAt,
  }) {
    track(TippyOnboardingAnalytics.completed, <String, Object?>{
      'sessionId': sessionId,
    });
    final int? ttfrMs = startedAt != null && firstResultAt != null
        ? firstResultAt.difference(startedAt).inMilliseconds
        : null;
    unawaited(
      ProductEventTrackingService.instance.onboardingCompleted(
        sessionId: sessionId,
        ttfrMs: ttfrMs != null && ttfrMs >= 0 ? ttfrMs : null,
      ),
    );
  }

  void _emit(String event, Map<String, Object?> params) {
    // Intentionally no-op sink for now — names match website contract.
    // Retention/product event services can subscribe later without schema drift.
  }
}
