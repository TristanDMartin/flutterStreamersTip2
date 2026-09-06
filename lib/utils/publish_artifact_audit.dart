import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Strict local media audit before Mux upload.
///
/// >50KB alone is not enough — corrupt files can be larger. Publish may only
/// consume artifacts that exist, have MP4 structure, decode, and report a
/// sane duration.
class PublishArtifactAudit {
  const PublishArtifactAudit({
    required this.path,
    required this.byteLength,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasFtyp,
    required this.canDecode,
    required this.isAcceptable,
    required this.rejectReason,
    this.stage = 'unspecified',
  });

  final String path;
  final int byteLength;
  final int durationMs;
  final int width;
  final int height;
  final bool hasFtyp;
  final bool canDecode;
  final bool isAcceptable;
  final String? rejectReason;
  final String stage;

  /// Reject incomplete/corrupt captures (e.g. 8KB stubs from aborted records).
  static const int minBytes = 50 * 1024;

  /// ~1MB/min at low bitrate is unrealistic for 720p; use a soft floor that
  /// still rejects stub MP4s while allowing short real clips.
  static const int minBytesPerSecond = 25 * 1024;
  static const int minDurationMs = 1000;
  static const int maxDurationMs = 5 * 60 * 1000;

  void logArtifactAudit() {
    debugPrint(
      'ARTIFACT_AUDIT stage=$stage path=$path sizeBytes=$byteLength '
      'durationMs=$durationMs wh=${width}x$height ftyp=$hasFtyp '
      'canDecode=$canDecode ok=$isAcceptable'
      '${rejectReason != null ? ' reason=$rejectReason' : ''}',
    );
  }

  static Future<PublishArtifactAudit> inspect({
    required File file,
    String stage = 'unspecified',
    int durationMsHint = 0,
    int widthHint = 0,
    int heightHint = 0,
    bool probeDecode = true,
  }) async {
    final String path = file.path;
    if (!await file.exists()) {
      final PublishArtifactAudit missing = PublishArtifactAudit(
        path: path,
        byteLength: 0,
        durationMs: durationMsHint,
        width: widthHint,
        height: heightHint,
        hasFtyp: false,
        canDecode: false,
        isAcceptable: false,
        rejectReason: 'Video file is missing',
        stage: stage,
      );
      missing.logArtifactAudit();
      return missing;
    }
    final int bytes = await file.length();
    final bool hasFtyp = await _hasMp4Ftyp(file);
    int durationMs = durationMsHint;
    int width = widthHint;
    int height = heightHint;
    bool canDecode = false;
    if (probeDecode && hasFtyp && bytes >= minBytes) {
      final _DecodeProbe? probed = await _probeWithVideoPlayer(file);
      if (probed != null) {
        canDecode = true;
        if (probed.durationMs > 0) {
          durationMs = probed.durationMs;
        }
        if (probed.width > 0) {
          width = probed.width;
        }
        if (probed.height > 0) {
          height = probed.height;
        }
      }
    }
    String? rejectReason;
    if (bytes < minBytes) {
      rejectReason =
          'Recording is incomplete (${(bytes / 1024).toStringAsFixed(1)} KB). '
          'Hold to record for at least 1 second.';
    } else if (!hasFtyp) {
      rejectReason = 'Video file is not a valid MP4';
    } else if (probeDecode && !canDecode) {
      rejectReason = 'Video file cannot be opened for playback';
    } else if (durationMs > 0 && durationMs < minDurationMs) {
      rejectReason = 'Video too short (minimum 1 second)';
    } else if (durationMs > maxDurationMs) {
      rejectReason = 'Video too long (maximum 5 minutes)';
    } else if (durationMs >= minDurationMs) {
      final int minExpected =
          (minBytesPerSecond * (durationMs / 1000)).round();
      if (bytes < minExpected) {
        rejectReason =
            'Recording looks corrupt '
            '(${(bytes / 1024).toStringAsFixed(1)} KB for '
            '${(durationMs / 1000).toStringAsFixed(1)}s). '
            'Please record again.';
      }
    } else if (widthHint <= 0 && heightHint <= 0 && width <= 0 && height <= 0) {
      // Duration unknown and no size — require decode to have succeeded with
      // at least one dimension when probing.
      if (probeDecode && canDecode && width <= 0 && height <= 0) {
        rejectReason = 'Video dimensions are invalid';
      }
    }
    final PublishArtifactAudit result = PublishArtifactAudit(
      path: path,
      byteLength: bytes,
      durationMs: durationMs,
      width: width,
      height: height,
      hasFtyp: hasFtyp,
      canDecode: canDecode,
      isAcceptable: rejectReason == null,
      rejectReason: rejectReason,
      stage: stage,
    );
    result.logArtifactAudit();
    return result;
  }

  static Future<_DecodeProbe?> _probeWithVideoPlayer(File file) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(file);
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!controller.value.isInitialized || controller.value.hasError) {
        return null;
      }
      final int durationMs = controller.value.duration.inMilliseconds;
      final int width = controller.value.size.width.round();
      final int height = controller.value.size.height.round();
      return _DecodeProbe(
        durationMs: durationMs,
        width: width,
        height: height,
      );
    } catch (e) {
      debugPrint('ARTIFACT_AUDIT decode_probe_failed path=${file.path} error=$e');
      return null;
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  static Future<bool> _hasMp4Ftyp(File file) async {
    try {
      final RandomAccessFile raf = await file.open();
      try {
        final Uint8List header = await raf.read(64);
        if (header.length < 8) {
          return false;
        }
        for (int i = 0; i <= header.length - 4; i++) {
          if (header[i] == 0x66 &&
              header[i + 1] == 0x74 &&
              header[i + 2] == 0x79 &&
              header[i + 3] == 0x70) {
            return true;
          }
        }
        return false;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }
}

class _DecodeProbe {
  const _DecodeProbe({
    required this.durationMs,
    required this.width,
    required this.height,
  });

  final int durationMs;
  final int width;
  final int height;
}
