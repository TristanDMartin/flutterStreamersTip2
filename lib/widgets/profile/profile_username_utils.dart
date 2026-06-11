abstract final class ProfileUsernameUtils {
  static String generateUsernameFromDisplayName(String displayName) {
    if (displayName.isEmpty) {
      return '';
    }
    String username = displayName.toLowerCase();
    username = username.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    username = username.replaceAll(RegExp(r'_+'), '_');
    username = username.replaceAll(RegExp(r'^_+|_+$'), '');
    if (username.isEmpty) {
      username = 'user';
    }
    if (username.length > 20) {
      username = username.substring(0, 20);
    }
    return username;
  }
}
