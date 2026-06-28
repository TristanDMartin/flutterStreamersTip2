abstract final class ProfileUsernameRules {
  static const int minLength = 3;
  static const int maxLength = 20;

  static const String helperLine =
      'Your username is how creators find you.';
  static const String formatLine =
      'Only letters, numbers, underscores, and periods.';

  static final RegExp validPattern = RegExp(r'^[a-z0-9_.]+$');

  static String normalize(String raw) {
    String username = raw.toLowerCase().trim();
    username = username.replaceAll(RegExp(r'\s+'), '');
    username = username.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    username = username.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (username.length > maxLength) {
      username = username.substring(0, maxLength);
    }
    return username;
  }

  static String? localValidationMessage(String normalized) {
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length < minLength) {
      return 'Username must be at least 3 characters';
    }
    if (!validPattern.hasMatch(normalized)) {
      return 'Invalid characters';
    }
    return null;
  }

  static bool isFormatValid(String normalized) {
    return normalized.length >= minLength &&
        normalized.length <= maxLength &&
        validPattern.hasMatch(normalized);
  }
}
