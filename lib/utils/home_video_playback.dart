import '../models/home_video.dart';
import 'video_url_resolver.dart';

bool isHomeVideoProcessing(HomeVideo video) {
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
