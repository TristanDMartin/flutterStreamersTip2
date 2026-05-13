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
    if (!enableTesterInstallReset) return false;
    final Set<String> testers = testerUsers;
    return testers.contains(userId.trim().toLowerCase()) ||
        testers.contains((email ?? '').trim().toLowerCase()) ||
        testers.contains((username ?? '').trim().toLowerCase());
  }
}
