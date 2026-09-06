import '../models/home_video.dart';
import 'video_url_resolver.dart';

bool isHomeVideoLocalFileUrl(String url) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final String lower = trimmed.toLowerCase();
  return lower.startsWith('file://') ||
      lower.startsWith('/') ||
      (!lower.startsWith('http://') &&
          !lower.startsWith('https://') &&
          lower.endsWith('.mp4'));
}

/// Owner-only optimistic item with a durable local MP4 (instant publish).
bool isHomeVideoOwnerPendingLocal(HomeVideo video) {
  final String status = video.status.toLowerCase();
  final bool pendingStatus = status == 'uploading' ||
      status == 'processing' ||
      status == 'pending' ||
      status == 'failed' ||
      status == 'upload_failed';
  if (!pendingStatus) {
    return false;
  }
  return isHomeVideoLocalFileUrl(video.videoURL);
}

bool isHomeVideoProcessing(HomeVideo video) {
  if (isHomeVideoOwnerPendingLocal(video)) {
    return false;
  }
  final String status = video.status.toLowerCase();
  if (status == 'uploading' ||
      status == 'processing' ||
      status == 'failed' ||
      status == 'upload_failed') {
    return true;
  }
  return video.videoURL.trim().isEmpty;
}

bool isHomeVideoPlayable(HomeVideo video) {
  if (isHomeVideoOwnerPendingLocal(video)) {
    return true;
  }
  if (isHomeVideoProcessing(video)) {
    return false;
  }
  if (video.videoURL.trim().isEmpty) {
    return false;
  }
  return isReadyPlaybackStatus(
    video.status,
    isReadyForFeed: true,
  );
}
