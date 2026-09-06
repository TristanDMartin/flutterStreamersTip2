import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:streamers_tip/utils/secure_log.dart';

import '../features/publish/pending_post.dart';
import '../features/publish/video_draft.dart';

class VideoRenderResult {
  const VideoRenderResult({
    required this.success,
    this.outputFile,
    this.errorMessage,
  });

  final bool success;
  final File? outputFile;
  final String? errorMessage;
}

/// Bakes trim + text + manual captions into a publishable MP4.
///
/// Never mutates the draft source file. Caption ASR tracks stay Phase C;
/// manual caption segments are burned when present on the draft.
class VideoRenderService {
  VideoRenderService._internal();

  static final VideoRenderService instance = VideoRenderService._internal();

  Future<VideoRenderResult> renderDraft(VideoDraft draft) async {
    if (!draft.requiresRender) {
      return VideoRenderResult(
        success: true,
        outputFile: draft.sourceFile,
      );
    }
    final File source = draft.sourceFile;
    if (!await source.exists()) {
      return const VideoRenderResult(
        success: false,
        errorMessage: 'Source video is missing.',
      );
    }
    try {
      final Directory temp = await getTemporaryDirectory();
      final String outPath = p.join(
        temp.path,
        '${draft.draftId}_render_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final double startSec = draft.trimStart.inMilliseconds / 1000.0;
      final double durationSec =
          draft.effectiveDuration.inMilliseconds / 1000.0;
      final int outW = draft.width > 0 ? draft.width : 1080;
      final int outH = draft.height > 0 ? draft.height : 1920;
      final int rotation = await _probeRotationDegrees(source.path);
      final List<String> filters = <String>[];
      final List<String> overlayInputs = <String>[];
      final List<File> tempOverlays = <File>[];
      // Trim in-filter so overlay enable() times stay relative to 0..duration.
      final String prep = _buildOrientationPrep(
        rotationDegrees: rotation,
        outWidth: outW,
        outHeight: outH,
      );
      filters.add(
        '[0:v]trim=start=$startSec:duration=$durationSec,'
        'setpts=PTS-STARTPTS,$prep[base]',
      );
      String lastLabel = 'base';
      int overlayIndex = 1;
      for (final PendingTextLayer layer in draft.textLayers) {
        if (layer.text.trim().isEmpty) {
          continue;
        }
        final File? png = await _renderTextOverlayPng(
          draft: draft,
          layer: layer,
          tempDir: temp,
          width: outW,
          height: outH,
        );
        if (png == null) {
          continue;
        }
        tempOverlays.add(png);
        overlayInputs.add('-i');
        overlayInputs.add(png.path);
        final double start =
            ((layer.start ?? draft.trimStart) - draft.trimStart)
                    .inMilliseconds /
                1000.0;
        final double end = ((layer.end ?? draft.trimEnd) - draft.trimStart)
                .inMilliseconds /
            1000.0;
        final double safeStart = start.clamp(0.0, durationSec);
        final double safeEnd = end.clamp(safeStart + 0.05, durationSec);
        final String outLabel = 'v$overlayIndex';
        filters.add(
          '[$lastLabel][$overlayIndex:v]overlay=0:0:'
          "enable='between(t\\,$safeStart\\,$safeEnd)'[$outLabel]",
        );
        lastLabel = outLabel;
        overlayIndex += 1;
      }
      for (final PendingCaptionSegment segment in draft.captionTrack) {
        if (!draft.captionsEnabled || segment.text.trim().isEmpty) {
          continue;
        }
        final PendingTextLayer asLayer = PendingTextLayer(
          id: segment.id,
          text: segment.text,
          fontFamily: 'Classic',
          fontSize: 22,
          colorValue: 0xFFFFFFFF,
          alignment: TextAlign.center,
          normX: 0.5,
          normY: 0.82,
          start: segment.start,
          end: segment.end,
        );
        final File? png = await _renderTextOverlayPng(
          draft: draft,
          layer: asLayer,
          tempDir: temp,
          width: outW,
          height: outH,
          withBackdrop: true,
        );
        if (png == null) {
          continue;
        }
        tempOverlays.add(png);
        overlayInputs.add('-i');
        overlayInputs.add(png.path);
        final double start =
            (segment.start - draft.trimStart).inMilliseconds / 1000.0;
        final double end =
            (segment.end - draft.trimStart).inMilliseconds / 1000.0;
        final double safeStart = start.clamp(0.0, durationSec);
        final double safeEnd = end.clamp(safeStart + 0.05, durationSec);
        final String outLabel = 'v$overlayIndex';
        filters.add(
          '[$lastLabel][$overlayIndex:v]overlay=0:0:'
          "enable='between(t\\,$safeStart\\,$safeEnd)'[$outLabel]",
        );
        lastLabel = outLabel;
        overlayIndex += 1;
      }
      if (draft.captionsEnabled &&
          draft.manualCaptionText.trim().isNotEmpty &&
          draft.captionTrack.isEmpty) {
        final PendingTextLayer manual = PendingTextLayer(
          id: 'manual_caption',
          text: draft.manualCaptionText.trim(),
          fontFamily: 'Classic',
          fontSize: 22,
          colorValue: 0xFFFFFFFF,
          alignment: TextAlign.center,
          normX: 0.5,
          normY: 0.82,
          start: draft.trimStart,
          end: draft.trimEnd,
        );
        final File? png = await _renderTextOverlayPng(
          draft: draft,
          layer: manual,
          tempDir: temp,
          width: outW,
          height: outH,
          withBackdrop: true,
        );
        if (png != null) {
          tempOverlays.add(png);
          overlayInputs.add('-i');
          overlayInputs.add(png.path);
          final String outLabel = 'v$overlayIndex';
          filters.add(
            '[$lastLabel][$overlayIndex:v]overlay=0:0:'
            "enable='between(t\\,0\\,$durationSec)'[$outLabel]",
          );
          lastLabel = outLabel;
          overlayIndex += 1;
        }
      }
      // Accurate trim via trim/atrim filters; overlays timed on reset PTS.
      final StringBuffer command = StringBuffer();
      command.write('-y -i "${source.path}" ');
      if (overlayInputs.isNotEmpty) {
        command.write('${overlayInputs.join(' ')} ');
      }
      final bool hasAudioMap = true;
      filters.add(
        '[0:a]atrim=start=$startSec:duration=$durationSec,'
        'asetpts=PTS-STARTPTS[aout]',
      );
      command.write(
        '-filter_complex "${filters.join(';')}" '
        '-map "[$lastLabel]" -map "[aout]" '
        '-c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k '
        '-movflags +faststart "$outPath"',
      );
      secureLog('VideoRenderService: $command');
      var session = await FFmpegKit.execute(command.toString());
      var code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code) && hasAudioMap) {
        // Retry without audio if source has no usable audio track.
        final StringBuffer videoOnly = StringBuffer();
        videoOnly.write('-y -i "${source.path}" ');
        if (overlayInputs.isNotEmpty) {
          videoOnly.write('${overlayInputs.join(' ')} ');
        }
        final List<String> videoFilters = filters
            .where((String f) => !f.contains('atrim='))
            .toList();
        videoOnly.write(
          '-filter_complex "${videoFilters.join(';')}" '
          '-map "[$lastLabel]" '
          '-c:v libx264 -preset veryfast -crf 23 -an '
          '-movflags +faststart "$outPath"',
        );
        secureLog('VideoRenderService retry video-only: $videoOnly');
        session = await FFmpegKit.execute(videoOnly.toString());
        code = await session.getReturnCode();
      }
      for (final File file in tempOverlays) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      if (!ReturnCode.isSuccess(code)) {
        final String? logs = await session.getAllLogsAsString();
        secureLog('VideoRenderService failed: $logs');
        return const VideoRenderResult(
          success: false,
          errorMessage: 'Could not render your edits. Please try again.',
        );
      }
      final File out = File(outPath);
      if (!await out.exists() || await out.length() == 0) {
        return const VideoRenderResult(
          success: false,
          errorMessage: 'Rendered video file is empty.',
        );
      }
      return VideoRenderResult(success: true, outputFile: out);
    } catch (e, st) {
      secureLog('VideoRenderService exception: $e\n$st');
      return VideoRenderResult(
        success: false,
        errorMessage: 'Render failed: $e',
      );
    }
  }

  String _buildOrientationPrep({
    required int rotationDegrees,
    required int outWidth,
    required int outHeight,
  }) {
    final int normalized = ((rotationDegrees % 360) + 360) % 360;
    final List<String> steps = <String>[];
    if (normalized == 90) {
      steps.add('transpose=1');
    } else if (normalized == 270) {
      steps.add('transpose=2');
    } else if (normalized == 180) {
      steps.add('transpose=1');
      steps.add('transpose=1');
    }
    steps.add(
      'scale=$outWidth:$outHeight:force_original_aspect_ratio=decrease',
    );
    steps.add('pad=$outWidth:$outHeight:(ow-iw)/2:(oh-ih)/2');
    steps.add('setsar=1');
    return steps.join(',');
  }

  Future<int> _probeRotationDegrees(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final information = session.getMediaInformation();
      if (information == null) {
        return 0;
      }
      final List<StreamInformation> streams = information.getStreams();
      if (streams.isEmpty) {
        return 0;
      }
      for (final StreamInformation stream in streams) {
        if (stream.getType() != 'video') {
          continue;
        }
        final Map<dynamic, dynamic>? props = stream.getAllProperties();
        if (props == null) {
          continue;
        }
        final dynamic tags = props['tags'];
        if (tags is Map && tags['rotate'] != null) {
          return int.tryParse('${tags['rotate']}') ?? 0;
        }
        final dynamic sideData = props['side_data_list'];
        if (sideData is List) {
          for (final dynamic item in sideData) {
            if (item is! Map) {
              continue;
            }
            final dynamic rotation = item['rotation'];
            if (rotation != null) {
              final double value = double.tryParse('$rotation') ?? 0;
              return value.round();
            }
          }
        }
      }
    } catch (e) {
      secureLog('VideoRenderService rotation probe failed: $e');
    }
    return 0;
  }

  Future<File?> _renderTextOverlayPng({
    required VideoDraft draft,
    required PendingTextLayer layer,
    required Directory tempDir,
    required int width,
    required int height,
    bool withBackdrop = false,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0x00000000),
    );
    final TextStyle style = TextStyle(
      color: Color(layer.colorValue),
      fontSize: layer.fontSize,
      fontWeight: layer.fontFamily == 'Bold'
          ? FontWeight.w800
          : FontWeight.w700,
      fontFamily: _resolveFontFamily(layer.fontFamily),
      shadows: const <Shadow>[
        Shadow(blurRadius: 6, color: Color(0x99000000), offset: Offset(0, 1)),
      ],
    );
    final TextPainter painter = TextPainter(
      text: TextSpan(text: layer.text, style: style),
      textAlign: layer.alignment,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    );
    painter.layout(maxWidth: width * 0.86);
    final double centerX = layer.normX * width;
    final double centerY = layer.normY * height;
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(layer.rotation);
    canvas.scale(layer.scale);
    final double drawX = -painter.width / 2;
    final double drawY = -painter.height / 2;
    if (withBackdrop) {
      final RRect bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          drawX - 10,
          drawY - 6,
          painter.width + 20,
          painter.height + 12,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        bg,
        Paint()..color = const Color(0x99000000),
      );
    }
    painter.paint(canvas, Offset(drawX, drawY));
    canvas.restore();
    final ui.Image image = await recorder.endRecording().toImage(width, height);
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      return null;
    }
    final File out = File(
      p.join(
        tempDir.path,
        '${draft.draftId}_${layer.id}_'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await out.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return out;
  }

  String? _resolveFontFamily(String token) {
    switch (token) {
      case 'Modern':
        return 'sans-serif';
      case 'Bold':
        return 'sans-serif';
      case 'Serif':
        return 'serif';
      case 'Rounded':
        return 'sans-serif';
      case 'Mono':
        return 'monospace';
      case 'Classic':
      default:
        return null;
    }
  }
}
