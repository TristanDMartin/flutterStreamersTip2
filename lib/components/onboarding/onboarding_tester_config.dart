import '../../qa/qa_runtime.dart';

class OnboardingTesterConfig {
  const OnboardingTesterConfig._();

  static const bool enableTesterInstallReset = bool.fromEnvironment(
    'STREAMERSTIP_ENABLE_TESTER_ONBOARDING_RESET',
    defaultValue: true,
  );

  static const String testerUsersCsv = String.fromEnvironment(
    'STREAMERSTIP_TESTER_USERS',
    defaultValue:
        'tester,test,qa,streamerstiptester,tester@streamerstip.com,test@streamerstip.com',
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
  }) {
    if (QaRuntime.isMobileFeedE2e) return false;
    if (!enableTesterInstallReset) return false;
    final Set<String> testers = testerUsers;
    final String normalizedUserId = userId.trim().toLowerCase();
    final String normalizedEmail = (email ?? '').trim().toLowerCase();
    final String normalizedUsername = (username ?? '').trim().toLowerCase();
    return normalizedUsername == 'tester' ||
        normalizedUserId == 'tester' ||
        normalizedEmail == 'tester' ||
        testers.contains(normalizedUsername);
  }
}
