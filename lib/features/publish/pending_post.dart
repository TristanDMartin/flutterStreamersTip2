import 'dart:io';

import 'package:flutter/painting.dart';

/// How the clip is framed in the 9:16 feed preview.
enum PreviewCropMode {
  fit,
  fill,
  nineSixteen,
  oneOne,
  original,
}

/// On-video text overlay (creative editor), distinct from post caption
/// and from speech subtitle tracks.
class PendingTextLayer {
  const PendingTextLayer({
    required this.id,
    required this.text,
    this.fontFamily = 'Classic',
    this.fontSize = 28,
    this.colorValue = 0xFFFFFFFF,
    this.alignment = TextAlign.center,
    this.normX = 0.5,
    this.normY = 0.42,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.start,
    this.end,
  });

  final String id;
  final String text;
  final String fontFamily;
  final double fontSize;
  final int colorValue;
  final TextAlign alignment;
  final double normX;
  final double normY;
  final double scale;
  final double rotation;
  final Duration? start;
  final Duration? end;

  PendingTextLayer copyWith({
    String? text,
    String? fontFamily,
    double? fontSize,
    int? colorValue,
    TextAlign? alignment,
    double? normX,
    double? normY,
    double? scale,
    double? rotation,
    Duration? start,
    Duration? end,
    bool clearTiming = false,
  }) {
    return PendingTextLayer(
      id: id,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      alignment: alignment ?? this.alignment,
      normX: normX ?? this.normX,
      normY: normY ?? this.normY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      start: clearTiming ? null : (start ?? this.start),
      end: clearTiming ? null : (end ?? this.end),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'colorValue': colorValue,
      'alignment': alignment.name,
      'normX': normX,
      'normY': normY,
      'scale': scale,
      'rotation': rotation,
      if (start != null) 'startMs': start!.inMilliseconds,
      if (end != null) 'endMs': end!.inMilliseconds,
    };
  }

  factory PendingTextLayer.fromJson(Map<String, dynamic> json) {
    return PendingTextLayer(
      id: (json['id'] as String?) ?? 'text_${DateTime.now().millisecondsSinceEpoch}',
      text: (json['text'] as String?) ?? '',
      fontFamily: (json['fontFamily'] as String?) ?? 'Classic',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      alignment: TextAlign.values.firstWhere(
        (TextAlign value) => value.name == json['alignment'],
        orElse: () => TextAlign.center,
      ),
      normX: (json['normX'] as num?)?.toDouble() ?? 0.5,
      normY: (json['normY'] as num?)?.toDouble() ?? 0.42,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      start: json['startMs'] == null
          ? null
          : Duration(milliseconds: (json['startMs'] as num).toInt()),
      end: json['endMs'] == null
          ? null
          : Duration(milliseconds: (json['endMs'] as num).toInt()),
    );
  }
}

/// Speech / Tippy video captions (on-screen subtitles), not the social
/// post caption written on the Share screen.
class PendingCaptionSegment {
  const PendingCaptionSegment({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
  });

  final String id;
  final String text;
  final Duration start;
  final Duration end;

  PendingCaptionSegment copyWith({
    String? text,
    Duration? start,
    Duration? end,
  }) {
    return PendingCaptionSegment(
      id: id,
      text: text ?? this.text,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
    };
  }

  factory PendingCaptionSegment.fromJson(Map<String, dynamic> json) {
    return PendingCaptionSegment(
      id: (json['id'] as String?) ??
          'cap_${DateTime.now().millisecondsSinceEpoch}',
      text: (json['text'] as String?) ?? '',
      start: Duration(milliseconds: (json['startMs'] as num?)?.toInt() ?? 0),
      end: Duration(milliseconds: (json['endMs'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Edit-session draft carried Edit → Share (trim/text/captions/cover).
/// Post caption / hashtags / audience live on the Share screen only.
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
    this.coverFrame = Duration.zero,
    this.captionStyle = 'clean',
    List<PendingTextLayer>? textLayers,
    List<PendingCaptionSegment>? captionSegments,
  })  : trimEnd = trimEnd ?? duration,
        textLayers = List<PendingTextLayer>.unmodifiable(
          textLayers ?? const <PendingTextLayer>[],
        ),
        captionSegments = List<PendingCaptionSegment>.unmodifiable(
          captionSegments ?? const <PendingCaptionSegment>[],
        );

  final String videoPath;
  final Duration duration;
  final Duration trimStart;
  final Duration trimEnd;
  final PreviewCropMode cropMode;
  final double? aspectRatio;
  final bool captionsEnabled;
  final String manualCaptionText;
  final Duration coverFrame;
  final String captionStyle;
  final List<PendingTextLayer> textLayers;
  final List<PendingCaptionSegment> captionSegments;

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
      captionsEnabled &&
      (manualCaptionText.trim().isNotEmpty || captionSegments.isNotEmpty);

  bool get hasTextLayers => textLayers.any(
        (PendingTextLayer layer) => layer.text.trim().isNotEmpty,
      );

  bool get hasCoverSelection => coverFrame > Duration.zero;

  /// True when the creator made edit-screen changes worth confirming on Back.
  bool get hasMeaningfulEdits =>
      hasTrim ||
      hasCaptionOverlay ||
      hasTextLayers ||
      hasCoverSelection ||
      cropMode == PreviewCropMode.nineSixteen ||
      cropMode == PreviewCropMode.oneOne;

  PendingPost copyWith({
    String? videoPath,
    Duration? duration,
    Duration? trimStart,
    Duration? trimEnd,
    PreviewCropMode? cropMode,
    double? aspectRatio,
    bool? captionsEnabled,
    String? manualCaptionText,
    Duration? coverFrame,
    String? captionStyle,
    List<PendingTextLayer>? textLayers,
    List<PendingCaptionSegment>? captionSegments,
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
      coverFrame: coverFrame ?? this.coverFrame,
      captionStyle: captionStyle ?? this.captionStyle,
      textLayers: textLayers ?? this.textLayers,
      captionSegments: captionSegments ?? this.captionSegments,
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
      'preview_cover_frame_ms': coverFrame.inMilliseconds,
      'preview_caption_style': captionStyle,
      if (textLayers.isNotEmpty)
        'preview_text_layers':
            textLayers.map((PendingTextLayer e) => e.toJson()).toList(),
      if (captionSegments.isNotEmpty)
        'preview_caption_segments': captionSegments
            .map((PendingCaptionSegment e) => e.toJson())
            .toList(),
    };
  }
}
