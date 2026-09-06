import 'dart:io';

import 'pending_post.dart';

/// Where the draft media came from.
enum VideoDraftSourceType {
  camera,
  gallery,
  webUpload,
  unknown,
}

/// Local render / export lifecycle for a draft.
enum VideoDraftRenderStatus {
  idle,
  pending,
  rendering,
  ready,
  failed,
}

/// Canonical edit-session object until publish succeeds.
///
/// Camera and gallery both produce a [VideoDraft] that enters the same editor.
/// Publish must upload [publishFile], never the untouched source when edits
/// require a render.
class VideoDraft {
  VideoDraft({
    required this.draftId,
    required this.ownerUid,
    required this.sourceFilePath,
    required this.sourceType,
    required this.duration,
    this.width = 0,
    this.height = 0,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.textLayers = const <PendingTextLayer>[],
    this.captionTrack = const <PendingCaptionSegment>[],
    this.coverFrameTime = Duration.zero,
    this.cropMode = PreviewCropMode.fit,
    this.aspectRatio,
    this.captionsEnabled = false,
    this.manualCaptionText = '',
    this.captionStyle = 'clean',
    this.renderStatus = VideoDraftRenderStatus.idle,
    this.renderedFilePath,
    this.renderError,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : trimEnd = trimEnd ?? duration,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String draftId;
  final String ownerUid;
  final String sourceFilePath;
  final VideoDraftSourceType sourceType;
  final Duration duration;
  final int width;
  final int height;
  final Duration trimStart;
  final Duration trimEnd;
  final List<PendingTextLayer> textLayers;
  final List<PendingCaptionSegment> captionTrack;
  final Duration coverFrameTime;
  final PreviewCropMode cropMode;
  final double? aspectRatio;
  final bool captionsEnabled;
  final String manualCaptionText;
  final String captionStyle;
  final VideoDraftRenderStatus renderStatus;
  final String? renderedFilePath;
  final String? renderError;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const Duration minTrimSegment = Duration(seconds: 1);

  File get sourceFile => File(sourceFilePath);

  /// True when creator edits must be burned into published media.
  /// Alias for [requiresRender] — keep both names in sync.
  bool get hasBakedEdits => requiresRender;

  /// File that must be uploaded once edits are committed.
  ///
  /// Throws [StateError] if [hasBakedEdits] is true but no rendered artifact
  /// exists. Callers must never catch this and fall back to [sourceFile].
  File get publishFile {
    if (!hasBakedEdits) {
      return sourceFile;
    }
    final String? rendered = renderedFilePath;
    if (rendered == null || rendered.isEmpty) {
      throw StateError(
        'VideoDraft $draftId requires a rendered file before publish.',
      );
    }
    final File file = File(rendered);
    if (!file.existsSync()) {
      throw StateError(
        'Rendered file missing for VideoDraft $draftId: $rendered',
      );
    }
    return file;
  }

  Duration get effectiveDuration {
    final Duration segment = trimEnd - trimStart;
    if (segment <= Duration.zero) {
      return duration;
    }
    return segment;
  }

  bool get hasTrim =>
      trimStart > Duration.zero || trimEnd < duration;

  bool get hasTextLayers => textLayers.any(
        (PendingTextLayer layer) => layer.text.trim().isNotEmpty,
      );

  bool get hasCaptionOverlay =>
      captionsEnabled &&
      (manualCaptionText.trim().isNotEmpty || captionTrack.isNotEmpty);

  bool get hasCoverSelection => coverFrameTime > Duration.zero;

  bool get hasMeaningfulEdits =>
      hasTrim ||
      hasTextLayers ||
      hasCaptionOverlay ||
      hasCoverSelection ||
      cropMode == PreviewCropMode.nineSixteen ||
      cropMode == PreviewCropMode.oneOne;

  /// True when publish must bake a new media file before upload.
  bool get requiresRender =>
      hasTrim ||
      hasTextLayers ||
      (captionsEnabled &&
          (captionTrack.isNotEmpty || manualCaptionText.trim().isNotEmpty));

  bool get hasRenderableOutput {
    final String? path = renderedFilePath;
    if (path == null || path.isEmpty) {
      return false;
    }
    return File(path).existsSync();
  }

  bool get isRenderStale {
    if (!requiresRender) {
      return false;
    }
    if (renderStatus != VideoDraftRenderStatus.ready || !hasRenderableOutput) {
      return true;
    }
    return false;
  }

  VideoDraft copyWith({
    String? draftId,
    String? ownerUid,
    String? sourceFilePath,
    VideoDraftSourceType? sourceType,
    Duration? duration,
    int? width,
    int? height,
    Duration? trimStart,
    Duration? trimEnd,
    List<PendingTextLayer>? textLayers,
    List<PendingCaptionSegment>? captionTrack,
    Duration? coverFrameTime,
    PreviewCropMode? cropMode,
    double? aspectRatio,
    bool? captionsEnabled,
    String? manualCaptionText,
    String? captionStyle,
    VideoDraftRenderStatus? renderStatus,
    String? renderedFilePath,
    String? renderError,
    bool clearRenderedFile = false,
    bool clearRenderError = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoDraft(
      draftId: draftId ?? this.draftId,
      ownerUid: ownerUid ?? this.ownerUid,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      sourceType: sourceType ?? this.sourceType,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      textLayers: textLayers ?? this.textLayers,
      captionTrack: captionTrack ?? this.captionTrack,
      coverFrameTime: coverFrameTime ?? this.coverFrameTime,
      cropMode: cropMode ?? this.cropMode,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      captionsEnabled: captionsEnabled ?? this.captionsEnabled,
      manualCaptionText: manualCaptionText ?? this.manualCaptionText,
      captionStyle: captionStyle ?? this.captionStyle,
      renderStatus: renderStatus ?? this.renderStatus,
      renderedFilePath: clearRenderedFile
          ? null
          : (renderedFilePath ?? this.renderedFilePath),
      renderError:
          clearRenderError ? null : (renderError ?? this.renderError),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Invalidates any previous render after edit instructions change.
  VideoDraft markEditsDirty() {
    return copyWith(
      renderStatus: requiresRender
          ? VideoDraftRenderStatus.pending
          : VideoDraftRenderStatus.idle,
      clearRenderedFile: true,
      clearRenderError: true,
      updatedAt: DateTime.now(),
    );
  }

  PendingPost toPendingPost() {
    return PendingPost(
      videoPath: sourceFilePath,
      duration: duration,
      trimStart: trimStart,
      trimEnd: trimEnd,
      cropMode: cropMode,
      aspectRatio: aspectRatio,
      captionsEnabled: captionsEnabled,
      manualCaptionText: manualCaptionText,
      coverFrame: coverFrameTime,
      captionStyle: captionStyle,
      textLayers: textLayers,
      captionSegments: captionTrack,
    );
  }

  factory VideoDraft.fromPendingPost({
    required PendingPost pending,
    required String draftId,
    required String ownerUid,
    VideoDraftSourceType sourceType = VideoDraftSourceType.unknown,
    int width = 0,
    int height = 0,
  }) {
    return VideoDraft(
      draftId: draftId,
      ownerUid: ownerUid,
      sourceFilePath: pending.videoPath,
      sourceType: sourceType,
      duration: pending.duration,
      width: width,
      height: height,
      trimStart: pending.trimStart,
      trimEnd: pending.trimEnd,
      textLayers: pending.textLayers,
      captionTrack: pending.captionSegments,
      coverFrameTime: pending.coverFrame,
      cropMode: pending.cropMode,
      aspectRatio: pending.aspectRatio,
      captionsEnabled: pending.captionsEnabled,
      manualCaptionText: pending.manualCaptionText,
      captionStyle: pending.captionStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'draftId': draftId,
      'ownerUid': ownerUid,
      'sourceFilePath': sourceFilePath,
      'sourceType': sourceType.name,
      'durationMs': duration.inMilliseconds,
      'width': width,
      'height': height,
      'trimStartMs': trimStart.inMilliseconds,
      'trimEndMs': trimEnd.inMilliseconds,
      'textLayers': textLayers.map((PendingTextLayer e) => e.toJson()).toList(),
      'captionTrack':
          captionTrack.map((PendingCaptionSegment e) => e.toJson()).toList(),
      'coverFrameTimeMs': coverFrameTime.inMilliseconds,
      'cropMode': cropMode.name,
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
      'captionsEnabled': captionsEnabled,
      'manualCaptionText': manualCaptionText,
      'captionStyle': captionStyle,
      'renderStatus': renderStatus.name,
      if (renderedFilePath != null) 'renderedFilePath': renderedFilePath,
      if (renderError != null) 'renderError': renderError,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory VideoDraft.fromJson(Map<String, dynamic> json) {
    return VideoDraft(
      draftId: (json['draftId'] as String?) ??
          'draft_${DateTime.now().millisecondsSinceEpoch}',
      ownerUid: (json['ownerUid'] as String?) ?? '',
      sourceFilePath: (json['sourceFilePath'] as String?) ?? '',
      sourceType: VideoDraftSourceType.values.firstWhere(
        (VideoDraftSourceType value) => value.name == json['sourceType'],
        orElse: () => VideoDraftSourceType.unknown,
      ),
      duration: Duration(
        milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
      ),
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      trimStart: Duration(
        milliseconds: (json['trimStartMs'] as num?)?.toInt() ?? 0,
      ),
      trimEnd: Duration(
        milliseconds: (json['trimEndMs'] as num?)?.toInt() ?? 0,
      ),
      textLayers: ((json['textLayers'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> raw) => PendingTextLayer.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          )
          .toList(),
      captionTrack:
          ((json['captionTrack'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (Map<dynamic, dynamic> raw) => PendingCaptionSegment.fromJson(
                  Map<String, dynamic>.from(raw),
                ),
              )
              .toList(),
      coverFrameTime: Duration(
        milliseconds: (json['coverFrameTimeMs'] as num?)?.toInt() ?? 0,
      ),
      cropMode: PreviewCropMode.values.firstWhere(
        (PreviewCropMode value) => value.name == json['cropMode'],
        orElse: () => PreviewCropMode.fit,
      ),
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
      captionsEnabled: json['captionsEnabled'] == true,
      manualCaptionText: (json['manualCaptionText'] as String?) ?? '',
      captionStyle: (json['captionStyle'] as String?) ?? 'clean',
      renderStatus: VideoDraftRenderStatus.values.firstWhere(
        (VideoDraftRenderStatus value) => value.name == json['renderStatus'],
        orElse: () => VideoDraftRenderStatus.idle,
      ),
      renderedFilePath: json['renderedFilePath'] as String?,
      renderError: json['renderError'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
