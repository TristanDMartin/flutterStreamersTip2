String resolveVideoUrl(Map<String, dynamic> data) {
  // If status exists, only allow ready/published videos to surface a URL.
  final status = data['status'];
  if (status is String && status.isNotEmpty) {
    // Allow both 'ready' and 'published' statuses
    if (status != 'ready' && status != 'published') {
      return '';
    }
  }

  final canonical = data['canonicalPlaybackUrl'];
  if (canonical is String && canonical.trim().isNotEmpty) {
    return canonical.trim();
  }

  const candidateKeys = [
    'mp4_1080_url',
    'mp4_720_url',
    'mp4_480_url',
    'mp4Url',
    'videoUrl',
    'videoURL',
    'hlsUrl',
    'hls_url',
  ];

  final rawCandidates = <String>[];
  for (final key in candidateKeys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      rawCandidates.add(value.trim());
    }
  }

  bool looksLikeMp4(String url) => url.toLowerCase().contains('.mp4');
  bool looksLikeHls(String url) => url.toLowerCase().contains('.m3u8');

  final mp4 = rawCandidates.firstWhere(
    looksLikeMp4,
    orElse: () => '',
  );
  if (mp4.isNotEmpty) return mp4;

  final hls = rawCandidates.firstWhere(
    looksLikeHls,
    orElse: () => '',
  );
  if (hls.isNotEmpty) return hls;

  final videoMap = data['video'];
  if (videoMap is Map<String, dynamic>) {
    final nested = resolveVideoUrl(videoMap);
    if (nested.isNotEmpty) return nested;
  }

  return rawCandidates.isNotEmpty ? rawCandidates.first : '';
}
