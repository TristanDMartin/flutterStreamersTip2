import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../utils/video_preview_letterbox.dart';
import 'pending_post.dart';

/// Renders [controller] inside a feed-style frame using [pending] crop settings.
class PreviewVideoFrame extends StatelessWidget {
  const PreviewVideoFrame({
    super.key,
    required this.controller,
    required this.pending,
    this.borderRadius = 16,
    this.maxWidth,
  });

  final VideoPlayerController controller;
  final PendingPost pending;
  final double borderRadius;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final double videoAspect = pending.aspectRatio ??
        (controller.value.size.height > 0
            ? controller.value.size.width / controller.value.size.height
            : 9 / 16);

    final double frameAspect = _frameAspectRatio(pending.cropMode, videoAspect);
    final BoxFit boxFit = _boxFitForMode(pending.cropMode, videoAspect);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: AspectRatio(
          aspectRatio: frameAspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: boxFit,
                alignment: Alignment.center,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _frameAspectRatio(
    PreviewCropMode mode,
    double videoAspect,
  ) {
    switch (mode) {
      case PreviewCropMode.oneOne:
        return 1;
      case PreviewCropMode.nineSixteen:
        return 9 / 16;
      case PreviewCropMode.original:
        return videoAspect > 0 ? videoAspect : 9 / 16;
      case PreviewCropMode.fit:
      case PreviewCropMode.fill:
        return 9 / 16;
    }
  }

  static BoxFit _boxFitForMode(PreviewCropMode mode, double videoAspect) {
    switch (mode) {
      case PreviewCropMode.fit:
        return shouldLetterboxNonVerticalAspectRatio(videoAspect)
            ? BoxFit.contain
            : BoxFit.cover;
      case PreviewCropMode.fill:
      case PreviewCropMode.nineSixteen:
      case PreviewCropMode.oneOne:
        return BoxFit.cover;
      case PreviewCropMode.original:
        return BoxFit.contain;
    }
  }
}
