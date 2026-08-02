import '../models/platform.dart';

/// Canonical platform type strings stored on user profiles.
abstract final class PlatformRules {
  static const List<String> editablePlatformTypes = <String>[
    'twitch',
    'youtube',
    'kick',
    'tiktok',
    'instagram',
    'facebook',
    'x',
    'discord',
    'patreon',
    'onlyfans',
    'other',
  ];

  static bool isAgeRestrictedType(String type) {
    final String normalized = normalizePlatformType(type);
    return normalized == 'patreon' || normalized == 'onlyfans';
  }

  static bool isAgeRestrictedEntry(Map<String, dynamic> platform) {
    final String type = normalizePlatformType(platform['type']?.toString() ?? '');
    if (isAgeRestrictedType(type)) {
      return true;
    }
    final String url = platform['url']?.toString() ?? '';
    if (type == 'other' && url.isNotEmpty) {
      final String? official = detectOfficialTypeFromUrl(url);
      return official == 'patreon' || official == 'onlyfans';
    }
    return false;
  }

  static String normalizePlatformType(String type) {
    switch (type.toLowerCase()) {
      case 'twitter':
        return 'x';
      case 'facebook_gaming':
        return 'facebook';
      default:
        return type.toLowerCase();
    }
  }

  static String displayUrlPrefix(String type) {
    final String normalized = normalizePlatformType(type);
    switch (normalized) {
      case 'twitch':
        return 'https://www.twitch.tv/';
      case 'youtube':
        return 'https://www.youtube.com/@';
      case 'kick':
        return 'https://www.kick.com/';
      case 'tiktok':
        return 'https://www.tiktok.com/@';
      case 'instagram':
        return 'https://www.instagram.com/';
      case 'facebook':
        return 'https://www.facebook.com/';
      case 'x':
        return 'https://www.x.com/';
      case 'discord':
        return 'https://www.discord.com/';
      case 'patreon':
        return 'https://www.patreon.com/';
      case 'onlyfans':
        return 'https://www.onlyfans.com/';
      case 'other':
        return 'https://';
      default:
        return '';
    }
  }

  static String? previewPlatformUrl(String type, String handle) {
    final String trimmed = handle.trim().replaceAll('@', '');
    if (trimmed.isEmpty) {
      return null;
    }
    final String normalized = normalizePlatformType(type);
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    switch (normalized) {
      case 'twitch':
        return 'https://www.twitch.tv/$trimmed';
      case 'youtube':
        return 'https://www.youtube.com/@$trimmed';
      case 'kick':
        return 'https://www.kick.com/$trimmed';
      case 'tiktok':
        return 'https://www.tiktok.com/@$trimmed';
      case 'instagram':
        return 'https://www.instagram.com/$trimmed';
      case 'facebook':
        return 'https://www.facebook.com/$trimmed';
      case 'x':
        return 'https://www.x.com/$trimmed';
      case 'discord':
        if (trimmed.contains('/') || trimmed.contains('.')) {
          final String asUrl = trimmed.startsWith('http')
              ? trimmed
              : 'https://$trimmed';
          return asUrl;
        }
        return 'https://www.discord.com/invite/$trimmed';
      case 'patreon':
        return 'https://www.patreon.com/$trimmed';
      case 'onlyfans':
        return 'https://www.onlyfans.com/$trimmed';
      case 'other':
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }
        return 'https://$trimmed';
      default:
        return null;
    }
  }

  /// Edit-links / Tippy shared row shape for Firestore `platforms`.
  static Map<String, dynamic> buildEditablePlatformEntry({
    required String type,
    required String username,
    String url = '',
    String? id,
    bool? isConnected,
  }) {
    final String normalized = normalizePlatformType(type);
    String handle = username.trim();
    String resolvedUrl = url.trim();
    if (handle.startsWith('http://') || handle.startsWith('https://')) {
      if (resolvedUrl.isEmpty) {
        resolvedUrl = handle;
      }
      handle = '';
    }
    if (handle.startsWith('@')) {
      handle = handle.substring(1);
    }
    if (resolvedUrl.isEmpty && handle.isNotEmpty) {
      resolvedUrl = previewPlatformUrl(normalized, handle) ?? '';
    }
    if (resolvedUrl.isNotEmpty &&
        !resolvedUrl.startsWith('http://') &&
        !resolvedUrl.startsWith('https://')) {
      resolvedUrl = 'https://$resolvedUrl';
    }
    final bool linked = handle.isNotEmpty || resolvedUrl.isNotEmpty;
    return <String, dynamic>{
      'id': id ?? 'platform_${normalized}_${DateTime.now().millisecondsSinceEpoch}',
      'type': normalized,
      'platformType': normalized,
      'username': handle,
      'url': resolvedUrl.isEmpty ? null : resolvedUrl,
      'followers': 0,
      'isConnected': isConnected ?? linked,
    };
  }

  static String handleHintForType(String type) {
    final String normalized = normalizePlatformType(type);
    switch (normalized) {
      case 'youtube':
      case 'tiktok':
        return 'username (without @)';
      case 'discord':
        return 'Invite or server URL';
      case 'other':
        return 'Full URL';
      case 'patreon':
      case 'onlyfans':
        return 'username or URL';
      default:
        return 'username';
    }
  }

  static String displayNameForType(String type) {
    switch (normalizePlatformType(type)) {
      case 'twitch':
        return 'Twitch';
      case 'youtube':
        return 'YouTube';
      case 'kick':
        return 'Kick';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X';
      case 'discord':
        return 'Discord';
      case 'patreon':
        return 'Patreon';
      case 'onlyfans':
        return 'OnlyFans';
      case 'other':
        return 'Other';
      case 'facebook':
        return 'Facebook';
      case 'bluesky':
        return 'Bluesky';
      case 'reddit':
        return 'Reddit';
      default:
        return type;
    }
  }

  static String? detectOfficialTypeFromUrl(String url) {
    if (hostMatchesUrl(url, 'patreon.com')) {
      return 'patreon';
    }
    if (hostMatchesUrl(url, 'onlyfans.com')) {
      return 'onlyfans';
    }
    return null;
  }

  static bool hostMatchesUrl(String url, String host) {
    final String trimmed = url.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return false;
    }
    String candidate = trimmed;
    if (!candidate.contains('://')) {
      candidate = 'https://$candidate';
    }
    final Uri? uri = Uri.tryParse(candidate);
    if (uri != null && uri.host.isNotEmpty) {
      final String uriHost = uri.host.toLowerCase();
      return uriHost == host || uriHost.endsWith('.$host');
    }
    return trimmed.contains(host);
  }

  static String? validatePlatformEntry({
    required String type,
    required String url,
    required String username,
  }) {
    final String normalizedType = normalizePlatformType(type);
    final String trimmedUrl = url.trim();
    final String trimmedUsername = username.trim();
    if (trimmedUrl.isEmpty && trimmedUsername.isEmpty) {
      return null;
    }
    if (trimmedUrl.isNotEmpty) {
      final String? officialFromUrl = detectOfficialTypeFromUrl(trimmedUrl);
      if (officialFromUrl != null && normalizedType == 'other') {
        return 'Use the ${displayNameForType(officialFromUrl)} platform '
            'instead of Other for this link.';
      }
      if (normalizedType == 'patreon' &&
          !hostMatchesUrl(trimmedUrl, 'patreon.com')) {
        return 'Enter a valid Patreon URL (patreon.com).';
      }
      if (normalizedType == 'onlyfans' &&
          !hostMatchesUrl(trimmedUrl, 'onlyfans.com')) {
        return 'Enter a valid OnlyFans URL (onlyfans.com).';
      }
    }
    if (normalizedType == 'patreon' &&
        trimmedUrl.isEmpty &&
        trimmedUsername.isEmpty) {
      return 'Add a Patreon URL or username.';
    }
    if (normalizedType == 'onlyfans' &&
        trimmedUrl.isEmpty &&
        trimmedUsername.isEmpty) {
      return 'Add an OnlyFans URL or username.';
    }
    return null;
  }

  static String? validatePlatformsList(List<Map<String, dynamic>> platforms) {
    int otherCount = 0;
    for (final Map<String, dynamic> raw in platforms) {
      final String type =
          normalizePlatformType(raw['type']?.toString() ?? '');
      if (type == 'other') {
        otherCount++;
      }
      final String? entryError = validatePlatformEntry(
        type: type,
        url: raw['url']?.toString() ?? '',
        username: raw['username']?.toString() ?? '',
      );
      if (entryError != null) {
        return entryError;
      }
    }
    if (otherCount > 1) {
      return 'You can only add one custom Other platform.';
    }
    return null;
  }

  static List<Map<String, dynamic>> normalizePlatformsForSave(
    List<Map<String, dynamic>> platforms,
  ) {
    final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> raw in platforms) {
      String type = normalizePlatformType(raw['type']?.toString() ?? 'other');
      String url = (raw['url']?.toString() ?? '').trim();
      final String username = (raw['username']?.toString() ?? '').trim();
      if (url.isNotEmpty &&
          !url.startsWith('http://') &&
          !url.startsWith('https://')) {
        url = 'https://$url';
      }
      final String? officialFromUrl =
          url.isNotEmpty ? detectOfficialTypeFromUrl(url) : null;
      if (officialFromUrl != null) {
        type = officialFromUrl;
      }
      normalized.add(<String, dynamic>{
        'id': raw['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'type': type,
        'username': username,
        'followers': (raw['followers'] as num?)?.toInt() ?? 0,
        'url': url.isEmpty ? null : url,
        // Preserve Tippy/onboarding stubs (empty handle, not yet linked).
        if (raw.containsKey('isConnected')) 'isConnected': raw['isConnected'],
        if (raw.containsKey('platformType'))
          'platformType': raw['platformType'],
      });
    }
    return normalized;
  }

  static PlatformType? toPlatformTypeEnum(String type) {
    final String normalized = normalizePlatformType(type);
    for (final PlatformType value in PlatformType.values) {
      if (value.name == normalized) {
        return value;
      }
    }
    return null;
  }
}
