class ProfileLinkService {
  static const String webBaseUrl = 'https://streamerstip.app';
  static const String appScheme = 'streamerstip://';

  static String webProfileUrlById(String userId) {
    return '$webBaseUrl/profile/${Uri.encodeComponent(userId)}';
  }

  static String webProfileUrlByUsername(String username) {
    return '$webBaseUrl/user/${Uri.encodeComponent(username)}';
  }

  static String appProfileUrlById(String userId) {
    return '${appScheme}profile/${Uri.encodeComponent(userId)}';
  }

  static String normalizeIncomingProfileLink(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;

    final host = uri.host.toLowerCase();
    final isStreamersTipHost =
        host == 'streamerstip.app' || host == 'www.streamerstip.app' ||
        host == 'streamerstip.com' || host == 'www.streamerstip.com';

    if ((uri.scheme == 'http' || uri.scheme == 'https') && isStreamersTipHost) {
      return '$appScheme${uri.path.startsWith('/') ? uri.path.substring(1) : uri.path}'
          '${uri.hasQuery ? '?${uri.query}' : ''}';
    }

    if (uri.scheme == 'streamerstip') {
      final normalizedPath =
          uri.host.isNotEmpty ? '${uri.host}${uri.path}' : uri.path;
      return '$appScheme${normalizedPath.startsWith('/') ? normalizedPath.substring(1) : normalizedPath}'
          '${uri.hasQuery ? '?${uri.query}' : ''}';
    }

    return rawUrl;
  }
}
