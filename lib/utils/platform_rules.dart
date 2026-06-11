import '../models/platform.dart';

/// Canonical platform type strings stored on user profiles.
abstract final class PlatformRules {
  static const List<String> editablePlatformTypes = <String>[
    'twitch',
    'youtube',
    'kick',
    'tiktok',
    'instagram',
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
