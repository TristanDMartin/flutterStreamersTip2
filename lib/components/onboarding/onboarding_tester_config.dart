import 'package:flutter/foundation.dart';

import '../../qa/qa_runtime.dart';

class OnboardingTesterConfig {
  const OnboardingTesterConfig._();

  static const int promoDataVersion = 3;

  /// Off in release by default. Enable locally with
  /// `--dart-define=STREAMERSTIP_ENABLE_TESTER_ONBOARDING_RESET=true`.
  static const bool enableTesterInstallReset = bool.fromEnvironment(
    'STREAMERSTIP_ENABLE_TESTER_ONBOARDING_RESET',
    defaultValue: false,
  );

  /// Off in release by default. Firestore `testerPromoEligible: true` still
  /// allows admin-seeded promo accounts when this is false.
  static const bool enablePromoIdentityMatching = bool.fromEnvironment(
    'STREAMERSTIP_ENABLE_TESTER_PROMO_IDENTITY_MATCH',
    defaultValue: false,
  );

  static const String testerUsersCsv = String.fromEnvironment(
    'STREAMERSTIP_TESTER_USERS',
    defaultValue:
        'tester,test,qa,demo,streamerstiptester,tester@streamerstip.com,test@streamerstip.com,contact@streamerstip.com',
  );

  static Set<String> get testerUsers {
    return testerUsersCsv
        .split(',')
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
  }

  static bool isTesterUser({
    required String userId,
    String? email,
    String? username,
    String? displayName,
    bool? promoEligibleFromFirestore,
  }) {
    if (QaRuntime.isMobileFeedE2e) {
      return false;
    }
    if (!enableTesterInstallReset) {
      return false;
    }
    return _matchesTesterIdentity(
      userId: userId,
      email: email,
      username: username,
      displayName: displayName,
      promoEligibleFromFirestore: promoEligibleFromFirestore,
    );
  }

  /// Promo screenshot seeding. In release, only explicit Firestore eligibility
  /// or `--dart-define=STREAMERSTIP_ENABLE_TESTER_PROMO_IDENTITY_MATCH=true`.
  static bool isPromoDataTester({
    required String userId,
    String? email,
    String? username,
    String? displayName,
    bool? promoEligibleFromFirestore,
  }) {
    if (QaRuntime.isMobileFeedE2e) {
      return false;
    }
    if (promoEligibleFromFirestore == true) {
      return true;
    }
    if (!enablePromoIdentityMatching) {
      return false;
    }
    return _matchesTesterIdentity(
      userId: userId,
      email: email,
      username: username,
      displayName: displayName,
      promoEligibleFromFirestore: null,
    );
  }

  @visibleForTesting
  static bool matchesTesterIdentity({
    required String userId,
    String? email,
    String? username,
    String? displayName,
    bool? promoEligibleFromFirestore,
  }) {
    return _matchesTesterIdentity(
      userId: userId,
      email: email,
      username: username,
      displayName: displayName,
      promoEligibleFromFirestore: promoEligibleFromFirestore,
    );
  }

  static bool _matchesTesterIdentity({
    required String userId,
    String? email,
    String? username,
    String? displayName,
    bool? promoEligibleFromFirestore,
  }) {
    if (promoEligibleFromFirestore == true) {
      return true;
    }
    final Set<String> testers = testerUsers;
    final String normalizedUserId = userId.trim().toLowerCase();
    final String normalizedEmail = (email ?? '').trim().toLowerCase();
    final String normalizedUsername = (username ?? '').trim().toLowerCase();
    final String normalizedDisplayName =
        (displayName ?? '').trim().toLowerCase();
    if (normalizedUsername == 'tester' ||
        normalizedUserId == 'tester' ||
        normalizedEmail == 'tester' ||
        normalizedDisplayName == 'tester') {
      return true;
    }
    if (testers.contains(normalizedUsername) ||
        testers.contains(normalizedEmail)) {
      return true;
    }
    if (normalizedUsername.contains('tester') ||
        normalizedUsername.contains('streamerstiptester')) {
      return true;
    }
    final int atIndex = normalizedEmail.indexOf('@');
    if (atIndex > 0) {
      final String emailLocalPart = normalizedEmail.substring(0, atIndex);
      if (testers.contains(emailLocalPart)) {
        return true;
      }
      if (normalizedEmail.endsWith('@streamerstip.com') &&
          (emailLocalPart.contains('test') ||
              emailLocalPart.contains('qa') ||
              emailLocalPart.contains('demo') ||
              emailLocalPart.contains('contact'))) {
        return true;
      }
    }
    return false;
  }
}
