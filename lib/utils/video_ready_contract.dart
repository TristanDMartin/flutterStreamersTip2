/// Canonical Mux → Firestore → Feed readiness helpers (Flutter).
///
/// Playable media may come from any supported field generation:
/// muxPlaybackId OR canonicalPlaybackUrl OR hlsUrl OR playbackUrl (etc.).
///
/// Feed exposure: explicit [isReadyForFeed] == false always excludes.
/// Missing [isReadyForFeed] is allowed for legacy playable docs.
/// New uploads: Worker/webhook alone sets [isReadyForFeed] == true after Mux.
/// Never forge READY / feed-ready from the client.
library;

bool _isNonEmptyString(Object? value) {
  return value is String && value.trim().isNotEmpty;
}

bool _isHttpMediaUrl(String url) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final String lower = trimmed.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('videos/');
}

/// True when any canonical supported playback source exists.
bool videoHasPlayableSource(Map<String, dynamic> data) {
  if (_isNonEmptyString(data['muxPlaybackId']) ||
      _isNonEmptyString(data['mux_playback_id']) ||
      _isNonEmptyString(data['playbackId'])) {
    return true;
  }
  for (final String key in <String>[
    'canonicalPlaybackUrl',
    'hlsUrl',
    'hls_url',
    'playbackUrl',
    'playback_url',
    'videoUrl',
    'videoURL',
    'video_url',
  ]) {
    final Object? value = data[key];
    if (value is String && _isHttpMediaUrl(value)) {
      return true;
    }
  }
  return false;
}

/// Legacy alias — name kept for call sites; not Mux-id-only.
bool videoHasPlayableMuxSource(Map<String, dynamic> data) =>
    videoHasPlayableSource(data);

bool videoStatusIsFailed(Map<String, dynamic> data) {
  final String status = (data['status'] as String? ?? '').toLowerCase();
  final String processingState =
      (data['processingState'] as String? ?? '').toLowerCase();
  final String muxStatus = (data['muxStatus'] as String? ?? '').toLowerCase();
  if (status == 'failed' ||
      processingState == 'failed' ||
      muxStatus == 'failed') {
    return true;
  }
  final Object? err = data['transcodingError'] ?? data['uploadError'];
  return err is String && err.trim().isNotEmpty;
}

bool videoStatusIsReady(Map<String, dynamic> data) {
  final String status = (data['status'] as String? ?? '').toLowerCase();
  return status == 'ready' || status == 'active' || status == 'published';
}

/// Owner / upload-chip "Processing → Ready" (includes private playable videos).
bool isCanonicalPlaybackReady(Map<String, dynamic> data) {
  if (videoStatusIsFailed(data)) {
    return false;
  }
  if (!videoStatusIsReady(data)) {
    return false;
  }
  if (!videoHasPlayableSource(data)) {
    return false;
  }
  final bool? playbackReady = data['playbackReady'] as bool?;
  if (playbackReady == false) {
    return false;
  }
  return true;
}

/// Confirmed global promotion for a *new* publish (LIVE toast / swap).
/// Requires explicit server [isReadyForFeed] — never grandfather legacy here.
bool isCanonicalFeedReady(Map<String, dynamic> data) {
  if (data['isReadyForFeed'] != true) {
    return false;
  }
  return isCanonicalPlaybackReady(data);
}
