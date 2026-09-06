const String kAchievementSessionExpiredMessage =
    'Your session has expired. Please sign in again.';
const String kAchievementGenericRetryMessage =
    'Something went wrong. Please try again.';

sealed class AchievementAcknowledgeResult {
  const AchievementAcknowledgeResult();
}

final class AchievementAcknowledgeSuccess
    extends AchievementAcknowledgeResult {
  const AchievementAcknowledgeSuccess();
}

final class AchievementAcknowledgeFailure
    extends AchievementAcknowledgeResult {
  const AchievementAcknowledgeFailure({required this.isSessionExpired});

  final bool isSessionExpired;

  String get userMessage => isSessionExpired
      ? kAchievementSessionExpiredMessage
      : kAchievementGenericRetryMessage;
}
