import 'profile_username_rules.dart';

abstract final class ProfileUsernameUtils {
  static String generateUsernameFromDisplayName(String displayName) {
    if (displayName.isEmpty) {
      return '';
    }
    String username = ProfileUsernameRules.normalize(
      displayName.replaceAll(RegExp(r'\s+'), ''),
    );
    if (username.isEmpty) {
      username = 'user';
    }
    return username;
  }

  static String normalizeUsername(String raw) => ProfileUsernameRules.normalize(raw);
}
