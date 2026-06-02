import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/home_video.dart';
import '../../../services/thumbnail_service.dart';
import 'video_player_thumbnail_poster.dart';

/// Letterboxed / non-9:16 video staging helpers.
abstract final class VideoPlayerContainedStageLogic {
  static const double targetVerticalAspectRatio = 9 / 16;
  static const double verticalTolerance = 0.09;

  static bool shouldUseContainedStage(double videoAspectRatio) {
    if (videoAspectRatio <= 0) return false;
    return (videoAspectRatio - targetVerticalAspectRatio).abs() >
        verticalTolerance;
  }
}

class VideoPlayerContainedBackdrop extends StatelessWidget {
  const VideoPlayerContainedBackdrop({
    super.key,
    required this.video,
    this.thumbnailService,
  });

  final HomeVideo video;
  final ThumbnailService? thumbnailService;

  @override
  Widget build(BuildContext context) {
    final String? url = VideoPlayerThumbnailUrl.resolve(
      context: context,
      video: video,
      thumbnailService: thumbnailService,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                const Color(0xFF0B071D).withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VideoPlayerContainedStageScrim extends StatelessWidget {
  const VideoPlayerContainedStageScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.16),
              Colors.black.withValues(alpha: 0.34),
            ],
            stops: const [0.58, 0.82, 1.0],
          ),
        ),
      ),
    );
  }
}
