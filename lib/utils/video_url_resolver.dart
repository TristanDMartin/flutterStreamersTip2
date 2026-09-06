import 'package:flutter/foundation.dart';
import '../services/device_capability_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Mobile must NEVER play original.mp4 (ExoPlayer OOM, codec errors).
bool containsOriginalMp4(String url) =>
    url.toLowerCase().contains('original.mp4');

bool looksLikeImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.webp') ||
      lower.contains('.gif') ||
      lower.contains('/thumbnail');
}

bool looksLikeLocalOrPlaceholderVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.startsWith('file://') ||
      lower.startsWith('/') ||
      lower.contains('placehold.co') ||
      lower.contains('placeholder');
}

bool isReadyPlaybackStatus(String? rawStatus, {bool? isReadyForFeed}) {
  final String status = (rawStatus ?? '').trim().toLowerCase();
  final bool statusOk =
      status == 'ready' || status == 'active' || status == 'published';
  if (!statusOk) {
    return false;
  }
  // Explicit false excludes. Missing allowed for legacy playable docs.
  if (isReadyForFeed == false) {
    return false;
  }
  return true;
}

String? resolveReadyPlaybackUrl(Map<String, dynamic> video) {
  final bool? feedFlag = video['isReadyForFeed'] as bool?;
  final String? rawStatus = video['status'] as String?;
  if (!isReadyPlaybackStatus(rawStatus, isReadyForFeed: feedFlag)) {
    return null;
  }

  final String? url = firstNonEmpty(<dynamic>[
    video['canonicalPlaybackUrl'],
    video['hlsUrl'],
    video['mp4Url'],
    video['playbackUrl'],
    video['hls_url'],
    video['videoUrl'],
    video['videoURL'],
  ]);
  if (url == null ||
      looksLikeImageUrl(url) ||
      looksLikeLocalOrPlaceholderVideoUrl(url) ||
      containsOriginalMp4(url)) {
    final String? playbackId = firstNonEmpty(<dynamic>[
      video['muxPlaybackId'],
      video['playbackId'],
      video['mux_playback_id'],
    ]);
    if (playbackId == null) {
      return null;
    }
    return _rejectOriginalOnMobile(
      normalizeMuxHlsUrl('https://stream.mux.com/$playbackId.m3u8'),
    );
  }
  return _rejectOriginalOnMobile(normalizeMuxHlsUrl(url));
}

bool hasReadyPlaybackSource(Map<String, dynamic> video) =>
    resolveReadyPlaybackUrl(video) != null;

/// Normalize Mux playback URLs to the adaptive master manifest.
String normalizeMuxHlsUrl(String url) {
  if (url.isEmpty) return url;

  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'stream.mux.com') return url;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return url;

  final first = segments.first.trim();
  if (first.isEmpty) return url;

  final playbackId = first
      .replaceAll('.m3u8', '')
      .replaceAll('/high', '')
      .replaceAll('/medium', '')
      .replaceAll('/low', '');

  if (playbackId.isEmpty) return url;
  return 'https://stream.mux.com/$playbackId.m3u8';
}

/// Convert raw GCS URLs to Firebase Storage API format so Storage rules apply.
/// Raw storage.googleapis.com URLs bypass Firebase rules (use GCS IAM) and often 403.
String toFirebaseStorageUrlIfNeeded(String url) {
  if (url.isEmpty) return url;
  const prefix = 'https://storage.googleapis.com/';
  if (!url.startsWith(prefix)) return url;
  final after = url.substring(prefix.length);
  final slash = after.indexOf('/');
  if (slash < 0) return url;
  final bucket = after.substring(0, slash);
  final path = after.substring(slash + 1);
  if (path.isEmpty || !bucket.contains('firebasestorage')) return url;
  final encoded = Uri.encodeComponent(path);
  return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media';
}

/// Resolve video URL with device-aware quality selection
/// Prefers resolution based on device capabilities (720p for low memory, 1080p for high memory)
Future<String> resolveVideoUrlWithQuality(
  Map<String, dynamic> data, {
  String? preferredResolution,
}) async {
  final resolvedPlaybackUrl = resolvePlaybackUrl(data);
  if (resolvedPlaybackUrl != null &&
      resolvedPlaybackUrl.trim().isNotEmpty &&
      !containsOriginalMp4(resolvedPlaybackUrl)) {
    return _rejectOriginalOnMobile(resolvedPlaybackUrl.trim());
  }

  final status = data['status'];
  if (status is String && status.isNotEmpty) {
    if (status != 'ready' &&
        status != 'published' &&
        status != 'processing' &&
        status != 'active') {
      return '';
    }
  }

  final playbackId = data['muxPlaybackId'] as String?;
  if (playbackId != null && playbackId.trim().isNotEmpty) {
    return normalizeMuxHlsUrl(
        'https://stream.mux.com/${playbackId.trim()}.m3u8');
  }

  final renditions = data['renditions'];
  if (renditions is Map<String, dynamic>) {
    final mp4720 = renditions['mp4_720'];
    final url720 = mp4720 is Map ? mp4720['url'] as String? : null;
    if (url720 != null &&
        url720.trim().isNotEmpty &&
        !containsOriginalMp4(url720)) {
      return _rejectOriginalOnMobile(normalizeMuxHlsUrl(url720.trim()));
    }
    final mp41080 = renditions['mp4_1080'];
    final url1080 = mp41080 is Map ? mp41080['url'] as String? : null;
    if (url1080 != null &&
        url1080.trim().isNotEmpty &&
        !containsOriginalMp4(url1080)) {
      return _rejectOriginalOnMobile(normalizeMuxHlsUrl(url1080.trim()));
    }
  }

  final canonical = data['canonicalPlaybackUrl'];
  if (canonical is String &&
      canonical.trim().isNotEmpty &&
      !containsOriginalMp4(canonical)) {
    return _rejectOriginalOnMobile(normalizeMuxHlsUrl(canonical.trim()));
  }

  final resolution = preferredResolution ??
      await DeviceCapabilityService.instance.getRecommendedResolution();

  final resolutionKey = 'mp4_${resolution}_url';
  final preferredUrl = data[resolutionKey] as String?;
  if (preferredUrl != null &&
      preferredUrl.trim().isNotEmpty &&
      !containsOriginalMp4(preferredUrl)) {
    return _rejectOriginalOnMobile(normalizeMuxHlsUrl(preferredUrl.trim()));
  }

  if (resolution == '720') {
    final fallback480 = data['mp4_480_url'] as String?;
    if (fallback480 != null &&
        fallback480.trim().isNotEmpty &&
        !containsOriginalMp4(fallback480)) {
      return _rejectOriginalOnMobile(normalizeMuxHlsUrl(fallback480.trim()));
    }
    final fallback1080 = data['mp4_1080_url'] as String?;
    if (fallback1080 != null &&
        fallback1080.trim().isNotEmpty &&
        !containsOriginalMp4(fallback1080)) {
      return _rejectOriginalOnMobile(normalizeMuxHlsUrl(fallback1080.trim()));
    }
  }

  return resolveVideoUrl(data);
}

String _rejectOriginalOnMobile(String url) {
  if (!kIsWeb && containsOriginalMp4(url)) {
    secureLog('FATAL: original.mp4 attempted on mobile - rejecting');
    return '';
  }
  return toFirebaseStorageUrlIfNeeded(url);
}

/// First non-empty string from a list of dynamic field values.
String? firstNonEmpty(List<dynamic> values) {
  for (final dynamic value in values) {
    if (value == null) {
      continue;
    }
    final String text = value.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

/// Resolve video URL with standard priority (backward compatible).
String? resolvePlaybackUrl(Map<String, dynamic> video) {
  String firstValidString(List<String> keys) {
    for (final key in keys) {
      final value = video[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty ||
          looksLikeImageUrl(text) ||
          looksLikeLocalOrPlaceholderVideoUrl(text) ||
          containsOriginalMp4(text)) {
        continue;
      }
      return text;
    }
    return '';
  }

  final canonical = firstValidString(
    const ['canonicalPlaybackUrl'],
  );
  if (canonical.isNotEmpty) {
    return normalizeMuxHlsUrl(canonical);
  }

  final sharedPlaybackUrl = firstValidString(
    const [
      'hlsUrl',
      'mp4Url',
      'playbackUrl',
      'streamUrl',
      'hls_url',
      'playbackURL',
    ],
  );
  if (sharedPlaybackUrl.isNotEmpty) {
    return normalizeMuxHlsUrl(sharedPlaybackUrl);
  }

  final muxPlaybackId = firstValidString(
    const ['muxPlaybackId', 'playbackId', 'mux_playback_id'],
  );
  if (muxPlaybackId.isNotEmpty) {
    return normalizeMuxHlsUrl('https://stream.mux.com/$muxPlaybackId.m3u8');
  }

  final videoUrl = firstValidString(
    const [
      'mp4_720_url',
      'mp4_480_url',
      'mp4_1080_url',
      'videoUrl',
      'downloadUrl',
      'url',
      'fileUrl',
      'videoURL',
      'video_url'
    ],
  );
  if (videoUrl.isNotEmpty) {
    return normalizeMuxHlsUrl(videoUrl);
  }

  return null;
}

String resolveVideoUrl(Map<String, dynamic> data) {
  final resolvedPlaybackUrl = resolvePlaybackUrl(data);
  if (resolvedPlaybackUrl != null &&
      resolvedPlaybackUrl.trim().isNotEmpty &&
      !containsOriginalMp4(resolvedPlaybackUrl)) {
    return _rejectOriginalOnMobile(resolvedPlaybackUrl.trim());
  }

  final status = data['status'];
  if (status is String && status.isNotEmpty) {
    if (status != 'ready' &&
        status != 'published' &&
        status != 'processing' &&
        status != 'active') {
      return '';
    }
  }

  final playbackId = data['muxPlaybackId'] as String?;
  if (playbackId != null && playbackId.trim().isNotEmpty) {
    return normalizeMuxHlsUrl(
        'https://stream.mux.com/${playbackId.trim()}.m3u8');
  }

  final renditions = data['renditions'];
  if (renditions is Map<String, dynamic>) {
    final mp4720 = renditions['mp4_720'];
    final url720 = mp4720 is Map ? mp4720['url'] as String? : null;
    if (url720 != null &&
        url720.trim().isNotEmpty &&
        !containsOriginalMp4(url720)) {
      return _rejectOriginalOnMobile(normalizeMuxHlsUrl(url720.trim()));
    }
    final mp41080 = renditions['mp4_1080'];
    final url1080 = mp41080 is Map ? mp41080['url'] as String? : null;
    if (url1080 != null &&
        url1080.trim().isNotEmpty &&
        !containsOriginalMp4(url1080)) {
      return _rejectOriginalOnMobile(normalizeMuxHlsUrl(url1080.trim()));
    }
  }

  final canonical = data['canonicalPlaybackUrl'];
  if (canonical is String &&
      canonical.trim().isNotEmpty &&
      !containsOriginalMp4(canonical)) {
    return _rejectOriginalOnMobile(normalizeMuxHlsUrl(canonical.trim()));
  }

  const candidateKeys = [
    'hlsUrl',
    'hls_url',
    'mp4_1080_url',
    'mp4_720_url',
    'mp4_480_url',
    'mp4Url',
    'videoUrl',
    'videoURL',
    'video_url',
  ];

  final rawCandidates = <String>[];
  for (final key in candidateKeys) {
    final value = data[key];
    if (value is String &&
        value.trim().isNotEmpty &&
        !containsOriginalMp4(value)) {
      rawCandidates.add(normalizeMuxHlsUrl(value.trim()));
    }
  }

  bool looksLikeMp4(String url) => url.toLowerCase().contains('.mp4');
  bool looksLikeHls(String url) =>
      url.toLowerCase().contains('.m3u8') ||
      url.toLowerCase().contains('stream.mux.com');

  final hls = rawCandidates.firstWhere(looksLikeHls, orElse: () => '');
  if (hls.isNotEmpty) return _rejectOriginalOnMobile(hls);

  final mp4 = rawCandidates.firstWhere(looksLikeMp4, orElse: () => '');
  if (mp4.isNotEmpty) return _rejectOriginalOnMobile(mp4);

  final videoMap = data['video'];
  if (videoMap is Map<String, dynamic>) {
    final nested = resolveVideoUrl(videoMap);
    if (nested.isNotEmpty) return _rejectOriginalOnMobile(nested);
  }

  if (rawCandidates.isNotEmpty) {
    return _rejectOriginalOnMobile(rawCandidates.first);
  }
  return '';
}

/// Canonical owner ID from video doc (single source of truth for filtering).
/// Use this when building HomeVideo or filtering user videos.
String? getOwnerId(Map<String, dynamic> data) {
  const ownerKeys = <String>[
    'ownerId',
    'userId',
    'user_id',
    'authorId',
    'uid',
    'creatorId',
    'creator_id',
    'videoOwnerId',
  ];
  for (final String key in ownerKeys) {
    final Object? value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  final Object? meta = data['meta'];
  if (meta is Map) {
    final Map<String, dynamic> metaMap = Map<String, dynamic>.from(meta);
    for (final String key in <String>['creator_id', 'creatorId', 'userId']) {
      final Object? v = metaMap[key];
      if (v is String && v.trim().isNotEmpty) {
        return v.trim();
      }
    }
  }
  return null;
}

bool looksLikeFirebaseAuthUid(String value) {
  final String trimmed = value.trim();
  if (trimmed.length < 20 || trimmed.length > 40) {
    return false;
  }
  final RegExp uidPattern = RegExp(r'^[A-Za-z0-9]+$');
  return uidPattern.hasMatch(trimmed);
}

/// When [videoId] is `{uid}_{suffix}`, returns the UID prefix for legacy docs.
String? inferOwnerIdFromVideoDocumentId(String videoId) {
  final int underscoreIndex = videoId.indexOf('_');
  if (underscoreIndex <= 0) {
    return null;
  }
  final String candidate = videoId.substring(0, underscoreIndex).trim();
  if (!looksLikeFirebaseAuthUid(candidate)) {
    return null;
  }
  return candidate;
}
