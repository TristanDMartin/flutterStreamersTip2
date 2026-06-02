import '../utils/sensitive_data_redactor.dart';

/// Public profile and deep-link URLs. Prefer username-based links so Firebase
/// UIDs are not embedded in shared URLs.
class ProfileLinkService {
  ProfileLinkService._();

  static const String webBaseUrl = 'https://streamerstip.app';
  static const String appScheme = 'streamerstip://';

  /// Username-first link for sharing (no UID in URL when username is known).
  static String publicProfileUrl({
    String? username,
    String? userId,
  }) {
    final String? cleanUsername = username?.trim();
    if (cleanUsername != null && cleanUsername.isNotEmpty) {
      if (SensitiveDataRedactor.looksLikeFirebaseUid(cleanUsername)) {
        return webProfileUrlById(cleanUsername);
      }
      return webProfileUrlByUsername(cleanUsername);
    }
    final String? cleanUserId = userId?.trim();
    if (cleanUserId != null && cleanUserId.isNotEmpty) {
      return webProfileUrlById(cleanUserId);
    }
    return webBaseUrl;
  }

  /// Legacy UID path; kept for inbound links only.
  static String webProfileUrlById(String userId) {
    return '$webBaseUrl/profile/${Uri.encodeComponent(userId)}';
  }

  static String webProfileUrlByUsername(String username) {
    return '$webBaseUrl/user/${Uri.encodeComponent(username)}';
  }

  static String appProfileUrlByUsername(String username) {
    return '${appScheme}user/${Uri.encodeComponent(username)}';
  }

  /// Legacy app deep link with UID.
  static String appProfileUrlById(String userId) {
    return '${appScheme}profile/${Uri.encodeComponent(userId)}';
  }

  static String publicAppProfileUrl({
    String? username,
    String? userId,
  }) {
    final String? cleanUsername = username?.trim();
    if (cleanUsername != null && cleanUsername.isNotEmpty) {
      if (SensitiveDataRedactor.looksLikeFirebaseUid(cleanUsername)) {
        return appProfileUrlById(cleanUsername);
      }
      return appProfileUrlByUsername(cleanUsername);
    }
    final String? cleanUserId = userId?.trim();
    if (cleanUserId != null && cleanUserId.isNotEmpty) {
      return appProfileUrlById(cleanUserId);
    }
    return appScheme;
  }

  static String normalizeIncomingProfileLink(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;

    final host = uri.host.toLowerCase();
    final isStreamersTipHost = host == 'streamerstip.app' ||
        host == 'www.streamerstip.app' ||
        host == 'streamerstip.com' ||
        host == 'www.streamerstip.com';

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
