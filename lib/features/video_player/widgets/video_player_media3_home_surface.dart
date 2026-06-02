import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../models/home_video.dart';
import '../../../services/thumbnail_service.dart';
import '../platform/android_media3_home_controller.dart';
import 'video_player_thumbnail_poster.dart';

/// Android Media3 platform view for home-feed cells.
class VideoPlayerMedia3HomeSurface extends StatelessWidget {
  const VideoPlayerMedia3HomeSurface({
    super.key,
    required this.video,
    required this.url,
    required this.autoplay,
    required this.thumbnailVisible,
    required this.thumbnailService,
    required this.onPlatformViewCreated,
  });

  final HomeVideo video;
  final String url;
  final bool autoplay;
  final bool thumbnailVisible;
  final ThumbnailService thumbnailService;
  final void Function(AndroidMedia3HomeController controller)
      onPlatformViewCreated;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AndroidView(
          key: ValueKey('Media3Home:${video.id}:$url'),
          viewType: 'streamers_tip/media3_player',
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: <String, Object?>{
            'videoId': video.id,
            'url': url,
            'autoplay': autoplay,
            'muted': !autoplay,
            'loop': true,
          },
          onPlatformViewCreated: (int id) {
            final AndroidMedia3HomeController controller =
                AndroidMedia3HomeController(id);
            onPlatformViewCreated(controller);
          },
        ),
        if (thumbnailVisible)
          Positioned.fill(
            child: VideoPlayerThumbnailPoster(
              video: video,
              thumbnailService: thumbnailService,
            ),
          ),
      ],
    );
  }
}
