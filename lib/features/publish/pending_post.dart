import 'dart:io';

/// How the clip is framed in the 9:16 feed preview.
enum PreviewCropMode {
  fit,
  fill,
  nineSixteen,
  oneOne,
  original,
}

/// Edits applied on the camera preview before publish.
class PendingPost {
  PendingPost({
    required this.videoPath,
    required this.duration,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.cropMode = PreviewCropMode.fit,
    this.aspectRatio,
    this.captionsEnabled = false,
    this.manualCaptionText = '',
  }) : trimEnd = trimEnd ?? duration;

  final String videoPath;
  final Duration duration;
  final Duration trimStart;
  final Duration trimEnd;
  final PreviewCropMode cropMode;
  final double? aspectRatio;
  final bool captionsEnabled;
  final String manualCaptionText;

  static const Duration minTrimSegment = Duration(seconds: 1);

  factory PendingPost.fromVideoFile({
    required File videoFile,
    required Duration duration,
    PreviewCropMode? defaultCropMode,
    double? videoAspectRatio,
  }) {
    final bool isLandscape = videoAspectRatio != null && videoAspectRatio > 1.0;
    return PendingPost(
      videoPath: videoFile.path,
      duration: duration,
      trimEnd: duration,
      cropMode: defaultCropMode ??
          (isLandscape ? PreviewCropMode.fit : PreviewCropMode.fill),
      aspectRatio: videoAspectRatio,
    );
  }

  Duration get effectiveDuration {
    final Duration segment = trimEnd - trimStart;
    if (segment <= Duration.zero) {
      return duration;
    }
    return segment;
  }

  bool get hasTrim => trimStart > Duration.zero || trimEnd < duration;

  bool get hasCaptionOverlay =>
      captionsEnabled && manualCaptionText.trim().isNotEmpty;

  PendingPost copyWith({
    String? videoPath,
    Duration? duration,
    Duration? trimStart,
    Duration? trimEnd,
    PreviewCropMode? cropMode,
    double? aspectRatio,
    bool? captionsEnabled,
    String? manualCaptionText,
  }) {
    return PendingPost(
      videoPath: videoPath ?? this.videoPath,
      duration: duration ?? this.duration,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      cropMode: cropMode ?? this.cropMode,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      captionsEnabled: captionsEnabled ?? this.captionsEnabled,
      manualCaptionText: manualCaptionText ?? this.manualCaptionText,
    );
  }

  Map<String, dynamic> toPublishMetadata() {
    return <String, dynamic>{
      'preview_trim_start_ms': trimStart.inMilliseconds,
      'preview_trim_end_ms': trimEnd.inMilliseconds,
      'preview_effective_duration_ms': effectiveDuration.inMilliseconds,
      'preview_crop_mode': cropMode.name,
      if (aspectRatio != null) 'preview_aspect_ratio': aspectRatio,
      'preview_captions_enabled': captionsEnabled,
      if (manualCaptionText.trim().isNotEmpty)
        'preview_manual_caption': manualCaptionText.trim(),
    };
  }
}
