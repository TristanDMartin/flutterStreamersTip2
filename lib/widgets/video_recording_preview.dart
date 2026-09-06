import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../features/publish/pending_post.dart';
import '../features/publish/preview_captions_sheet.dart';
import '../features/publish/preview_crop_sheet.dart';
import '../features/publish/preview_text_sheet.dart';
import '../features/publish/preview_trim_playback.dart';
import '../features/publish/preview_trim_sheet.dart';
import '../features/publish/preview_video_frame.dart';
import '../features/publish/publish_flow_tokens.dart';
import '../features/publish/video_draft.dart';
import '../services/video_draft_store.dart';
import '../services/video_filmstrip_cache.dart';
import '../utils/video_preview_letterbox.dart';
import 'video_publishing_screen.dart';

/// Returned when the user chooses Retake from Edit.
enum VideoRecordingPreviewRetake {
  retake,
}

/// Edit step: video canvas + Trim / Text / Captions / Cover → Next → Share.
class VideoRecordingPreview extends StatefulWidget {
  final VideoDraft draft;

  const VideoRecordingPreview({
    super.key,
    required this.draft,
  });

  @override
  State<VideoRecordingPreview> createState() => _VideoRecordingPreviewState();
}

class _VideoRecordingPreviewState extends State<VideoRecordingPreview> {
  VideoPlayerController? _controller;
  PreviewTrimPlayback? _trimPlayback;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isSubmitting = false;
  bool _isReady = false;
  String? _errorMessage;
  late VideoDraft _draft;
  String? _selectedTextLayerId;
  String? _scaleLayerId;
  double _scaleBaseNormX = 0.5;
  double _scaleBaseNormY = 0.42;
  double _scaleBaseScale = 1.0;
  double _scaleBaseRotation = 0.0;

  bool get _hasMeaningfulEdits => _draft.hasMeaningfulEdits;

  PendingPost get _pendingView => _draft.toPendingPost();

  VideoPlayerController get _requireController {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      throw StateError('Video controller is not ready');
    }
    return controller;
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _initializeVideo();
  }

  Future<void> _persistDraft(VideoDraft next) async {
    _draft = next.markEditsDirty();
    await VideoDraftStore.instance.saveDebounced(_draft);
    // Do not bake here — FFmpeg steals the hardware decoder and preview
    // play/pause stops responding on device.
  }

  Future<void> _initializeVideo() async {
    VideoPlayerController? created;
    try {
      final File videoFile = File(_draft.sourceFilePath);
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }
      final int fileSize = await videoFile.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }
      created = VideoPlayerController.file(videoFile);
      _controller = created;
      created.addListener(_onVideoPlayerError);
      await created.initialize();
      if (!mounted) {
        return;
      }
      final Duration duration = created.value.duration;
      final double aspect = created.value.size.height > 0
          ? created.value.size.width / created.value.size.height
          : 9 / 16;
      final int width = created.value.size.width.round();
      final int height = created.value.size.height.round();
      _draft = _draft.copyWith(
        duration: duration.inMilliseconds > 0 ? duration : _draft.duration,
        width: width > 0 ? width : _draft.width,
        height: height > 0 ? height : _draft.height,
        aspectRatio: aspect,
        trimEnd: _draft.trimEnd > Duration.zero &&
                _draft.trimEnd <= duration
            ? _draft.trimEnd
            : duration,
        updatedAt: DateTime.now(),
      );
      await VideoDraftStore.instance.saveNow(_draft);
      final PendingPost pending = _draft.toPendingPost();
      _trimPlayback = PreviewTrimPlayback(
        controller: created,
        pending: pending,
        onTick: () {
          if (mounted) {
            setState(() {});
          }
        },
      );
      setState(() {
        _isInitialized = true;
        _isReady =
            created!.value.isInitialized && duration.inMilliseconds > 0;
      });
      _validateVideo(duration);
      await _trimPlayback!.seekToTrimStart();
      VideoFilmstripCache.instance.prefetchFull(
        path: _draft.sourceFilePath,
        duration: _draft.duration,
      );
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (created != null && identical(_controller, created)) {
        created.removeListener(_onVideoPlayerError);
        await created.dispose();
        _controller = null;
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = 'Failed to load video. Please try recording again.';
        });
      }
    }
  }

  void _onVideoPlayerError() {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.value.hasError && mounted) {
      setState(() {
        _errorMessage = 'Video playback error. Please try recording again.';
        _isReady = false;
      });
    }
  }

  void _validateVideo(Duration duration) {
    final int durationSeconds = duration.inSeconds;
    if (durationSeconds < 1) {
      setState(() {
        _errorMessage = 'Video too short (minimum 1 second)';
        _isReady = false;
      });
    } else if (durationSeconds > 300) {
      setState(() {
        _errorMessage = 'Video too long (maximum 5 minutes)';
        _isReady = false;
      });
    } else {
      setState(() {
        _errorMessage = null;
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _trimPlayback?.dispose();
    final VideoPlayerController? controller = _controller;
    if (controller != null) {
      controller.removeListener(_onVideoPlayerError);
      controller.dispose();
      _controller = null;
    }
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final PendingPost pending = _pendingView;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }
    final Duration position = controller.value.position;
    final Duration endGuard = pending.trimEnd > const Duration(milliseconds: 80)
        ? pending.trimEnd - const Duration(milliseconds: 80)
        : pending.trimStart;
    if (position < pending.trimStart || position >= endGuard) {
      await controller.seekTo(pending.trimStart);
    }
    await controller.play();
    if (mounted) {
      setState(() => _isPlaying = controller.value.isPlaying);
    }
  }

  Future<void> _handleBack() async {
    if (_hasMeaningfulEdits) {
      final bool? discard = await _showDiscardEditsDialog();
      if (discard != true || !mounted) {
        return;
      }
      await VideoDraftStore.instance.delete(_draft.draftId);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _releasePreviewPlayer() async {
    _trimPlayback?.dispose();
    _trimPlayback = null;
    final VideoPlayerController? controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.removeListener(_onVideoPlayerError);
        if (controller.value.isInitialized) {
          await controller.pause();
        }
        await controller.dispose();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isPlaying = false;
        _isReady = false;
      });
    }
  }

  Future<void> _handleNext() async {
    final VideoPlayerController? controller = _controller;
    if (!_isReady || _isSubmitting || controller == null) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);
    // Release the Edit decoder before Share opens another player.
    // Never start FFmpeg while any preview player is alive.
    await _releasePreviewPlayer();
    await VideoDraftStore.instance.saveNow(_draft);
    if (!mounted) {
      return;
    }
    final Object? shareResult = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: '/camera/publish'),
        builder: (BuildContext context) {
          return VideoPublishingScreen(
            videoFile: File(_draft.sourceFilePath),
            videoDraft: _draft,
            pendingPost: _draft.toPendingPost(),
            caption: '',
            hashtags: const <String>[],
            onPublish: () {
              Navigator.of(context).pop(true);
            },
            onCancel: () {
              Navigator.of(context).pop(false);
            },
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (shareResult == true) {
      Navigator.of(context).pop();
      return;
    }
    // Returned to Edit — restore soft preview playback.
    await _initializeVideo();
  }

  Future<void> _handleRetake() async {
    final bool? shouldDiscard = await _showDiscardDialog();
    if (shouldDiscard == true && mounted) {
      await VideoDraftStore.instance.delete(_draft.draftId);
      if (mounted) {
        Navigator.of(context).pop(VideoRecordingPreviewRetake.retake);
      }
    }
  }

  Duration _trimRelativePosition(Duration absolute) {
    final Duration relative = absolute - _draft.trimStart;
    if (relative.isNegative) {
      return Duration.zero;
    }
    final Duration max = _draft.effectiveDuration;
    if (relative > max) {
      return max;
    }
    return relative;
  }

  Future<void> _openTrimEditor() async {
    final VideoPlayerController? controller = _controller;
    if (controller != null && _isPlaying) {
      await controller.pause();
      if (!mounted) {
        return;
      }
      setState(() => _isPlaying = false);
    }
    // Disable clamp while scrubbing the full timeline in the trim sheet;
    // otherwise seeks past the old trimEnd snap back to trimStart.
    _trimPlayback?.isEnabled = false;
    final ({Duration start, Duration end})? result =
        await PreviewTrimSheet.show(
      context: context,
      draft: _draft,
      onSeek: (Duration position) {
        unawaited(_requireController.seekTo(position));
      },
    );
    if (!mounted) {
      return;
    }
    _trimPlayback?.isEnabled = true;
    if (result == null) {
      await _trimPlayback?.seekToTrimStart();
      return;
    }
    if (result.end <= result.start) {
      _showSnack('End time must be after start time.');
      return;
    }
    if (result.end - result.start < VideoDraft.minTrimSegment) {
      _showSnack('Clip must be at least 1 second.');
      return;
    }
    final VideoDraft next = _draft.copyWith(
      trimStart: result.start,
      trimEnd: result.end,
      textLayers: _clampTextLayersToTrim(
        _draft.textLayers,
        result.start,
        result.end,
      ),
      updatedAt: DateTime.now(),
    );
    await _persistDraft(next);
    _trimPlayback?.applyPending(_draft.toPendingPost());
    final VideoPlayerController playController = _requireController;
    await playController.seekTo(result.start);
    await playController.play();
    if (mounted) {
      setState(() => _isPlaying = playController.value.isPlaying);
    }
  }

  List<PendingTextLayer> _clampTextLayersToTrim(
    List<PendingTextLayer> layers,
    Duration trimStart,
    Duration trimEnd,
  ) {
    if (layers.isEmpty) {
      return layers;
    }
    return layers.map((PendingTextLayer layer) {
      Duration start = layer.start ?? trimStart;
      Duration end = layer.end ?? trimEnd;
      if (start < trimStart) {
        start = trimStart;
      }
      if (end > trimEnd) {
        end = trimEnd;
      }
      if (end <= start) {
        start = trimStart;
        end = trimEnd;
      }
      return layer.copyWith(start: start, end: end);
    }).toList();
  }

  Future<void> _openTextEditor({PendingTextLayer? existing}) async {
    // Toolbar Text should edit the selected/first layer, not silently spawn
    // duplicates that look like "double text".
    final PendingTextLayer layer = existing ??
        (_draft.textLayers.isNotEmpty
            ? _draft.textLayers.first
            : PendingTextLayer(
                id: 'text_${DateTime.now().millisecondsSinceEpoch}',
                text: '',
                start: _draft.trimStart,
                end: _draft.trimEnd,
              ));
    final PreviewTextEditResult? result = await PreviewTextSheet.show(
      context: context,
      initial: layer,
      trimStart: _draft.trimStart,
      trimEnd: _draft.trimEnd,
    );
    if (result == null || !mounted) {
      return;
    }
    final List<PendingTextLayer> layers =
        List<PendingTextLayer>.from(_draft.textLayers);
    if (result.delete) {
      layers.removeWhere((PendingTextLayer item) => item.id == layer.id);
    } else {
      final int index =
          layers.indexWhere((PendingTextLayer item) => item.id == layer.id);
      if (index >= 0) {
        layers[index] = result.layer;
      } else {
        layers
          ..clear()
          ..add(result.layer);
      }
    }
    await _persistDraft(
      _draft.copyWith(textLayers: layers, updatedAt: DateTime.now()),
    );
    if (mounted) {
      setState(
        () => _selectedTextLayerId = result.delete ? null : result.layer.id,
      );
    }
  }

  Future<void> _openCaptionsEditor() async {
    final PreviewCaptionsResult? result = await PreviewCaptionsSheet.show(
      context: context,
      pending: _draft.toPendingPost(),
    );
    if (result == null || !mounted) {
      return;
    }
    await _persistDraft(
      _draft.copyWith(
        captionsEnabled: result.captionsEnabled,
        manualCaptionText: result.manualCaptionText,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCoverEditor() async {
    final Duration? frame = await PreviewCoverSheet.show(
      context: context,
      draft: _draft,
      onSeek: (Duration position) {
        unawaited(_requireController.seekTo(position));
      },
    );
    if (frame == null || !mounted) {
      return;
    }
    await _persistDraft(
      _draft.copyWith(coverFrameTime: frame, updatedAt: DateTime.now()),
    );
    if (mounted) {
      setState(() {});
    }
    await _requireController.seekTo(frame);
  }

  Future<void> _openCropEditor() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    final double aspect = controller.value.size.height > 0
        ? controller.value.size.width / controller.value.size.height
        : 9 / 16;
    final PreviewCropMode? mode = await PreviewCropSheet.show(
      context: context,
      selected: _draft.cropMode,
      isLandscape: aspect > 1.0,
    );
    if (mode == null || !mounted) {
      return;
    }
    await _persistDraft(
      _draft.copyWith(
        cropMode: mode,
        aspectRatio: aspect,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showDiscardEditsDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1220),
          title: const Text(
            'Discard edits?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Your trim, text, captions, and cover changes will be lost.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Keep editing',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Discard',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1220),
          title: const Text(
            'Discard this recording?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Keep',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Discard',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final int totalSeconds = duration.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _showLetterboxWarning {
    final PendingPost pending = _pendingView;
    final VideoPlayerController? controller = _controller;
    if (!_isInitialized || controller == null) {
      return false;
    }
    final double aspect = pending.aspectRatio ??
        (controller.value.size.height > 0
            ? controller.value.size.width / controller.value.size.height
            : 9 / 16);
    return pending.cropMode == PreviewCropMode.fit &&
        shouldLetterboxNonVerticalAspectRatio(aspect);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasMeaningfulEdits,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: PublishFlowTokens.background,
        body: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(child: _buildCanvas()),
            if (_isInitialized && _isReady) _buildTools(),
            _buildNextBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: _handleBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Back',
            ),
            const Expanded(
              child: Text(
                'New post',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: _handleRetake,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white70,
                size: 22,
              ),
              tooltip: 'Retake',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final PendingPost pending = _pendingView;
    final VideoPlayerController? controller = _controller;
    if (_isInitialized && _errorMessage != null && !_isReady) {
      return _buildErrorState();
    }
    if (!_isInitialized || !_isReady || controller == null) {
      return const ColoredBox(color: Colors.black);
    }
    final Duration position = controller.value.position;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: PreviewVideoFrame(
                        controller: controller,
                        pending: pending,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        unawaited(_togglePlayPause());
                      },
                    ),
                  ),
                  if (_showLetterboxWarning)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _buildLetterboxBanner(),
                    ),
                  ..._buildDraggableTextLayers(position),
                  if (pending.hasCaptionOverlay)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 72,
                      child: _buildCaptionOverlay(pending),
                    ),
                  IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${_formatDuration(_trimRelativePosition(position))} / '
                          '${_formatDuration(pending.effectiveDuration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _openCropEditor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration:
                                PublishFlowTokens.glassPanel(radius: 999),
                            child: const Text(
                              'Aspect',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTools() {
    final PendingPost pending = _pendingView;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _EditToolButton(
              label: 'Trim',
              icon: Icons.content_cut_rounded,
              isActive: pending.hasTrim,
              onTap: _openTrimEditor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _EditToolButton(
              label: 'Text',
              icon: Icons.text_fields_rounded,
              isActive: pending.hasTextLayers,
              onTap: () => _openTextEditor(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _EditToolButton(
              label: 'Captions',
              icon: Icons.subtitles_outlined,
              isActive: pending.hasCaptionOverlay,
              onTap: _openCaptionsEditor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _EditToolButton(
              label: 'Cover',
              icon: Icons.image_outlined,
              isActive: pending.hasCoverSelection,
              onTap: _openCoverEditor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDraggableTextLayers(Duration position) {
    final List<PendingTextLayer> visible = _draft.textLayers.where(
      (PendingTextLayer layer) {
        if (layer.text.trim().isEmpty) {
          return false;
        }
        final Duration start = layer.start ?? _draft.trimStart;
        final Duration end = layer.end ?? _draft.trimEnd;
        return position >= start && position <= end;
      },
    ).toList();
    if (visible.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      Positioned.fill(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                for (final PendingTextLayer layer in visible)
                  Positioned(
                    left: layer.normX * constraints.maxWidth - 80,
                    top: layer.normY * constraints.maxHeight - 24,
                    width: 160,
                    child: GestureDetector(
                      onTap: () => _openTextEditor(existing: layer),
                      onScaleStart: (ScaleStartDetails details) {
                        _scaleLayerId = layer.id;
                        _scaleBaseNormX = layer.normX;
                        _scaleBaseNormY = layer.normY;
                        _scaleBaseScale = layer.scale;
                        _scaleBaseRotation = layer.rotation;
                        setState(() => _selectedTextLayerId = layer.id);
                      },
                      onScaleUpdate: (ScaleUpdateDetails details) {
                        if (_scaleLayerId != layer.id) {
                          return;
                        }
                        final double nextX = (_scaleBaseNormX +
                                details.focalPointDelta.dx /
                                    constraints.maxWidth)
                            .clamp(0.08, 0.92);
                        final double nextY = (_scaleBaseNormY +
                                details.focalPointDelta.dy /
                                    constraints.maxHeight)
                            .clamp(0.08, 0.92);
                        _scaleBaseNormX = nextX;
                        _scaleBaseNormY = nextY;
                        final double nextScale = details.pointerCount >= 2
                            ? (_scaleBaseScale * details.scale)
                                .clamp(0.5, 3.0)
                            : _scaleBaseScale;
                        final double nextRotation = details.pointerCount >= 2
                            ? _scaleBaseRotation + details.rotation
                            : _scaleBaseRotation;
                        final List<PendingTextLayer> layers =
                            List<PendingTextLayer>.from(_draft.textLayers);
                        final int index = layers.indexWhere(
                          (PendingTextLayer item) => item.id == layer.id,
                        );
                        if (index < 0) {
                          return;
                        }
                        layers[index] = layers[index].copyWith(
                          normX: nextX,
                          normY: nextY,
                          scale: nextScale,
                          rotation: nextRotation,
                        );
                        setState(() {
                          _draft = _draft.copyWith(textLayers: layers);
                        });
                      },
                      onScaleEnd: (ScaleEndDetails details) {
                        if (_scaleLayerId == layer.id) {
                          _scaleLayerId = null;
                          final VideoDraft dirty = _draft.markEditsDirty();
                          setState(() => _draft = dirty);
                          unawaited(
                            VideoDraftStore.instance.saveDebounced(dirty),
                          );
                        }
                      },
                      child: Transform.rotate(
                        angle: layer.rotation,
                        child: Transform.scale(
                          scale: layer.scale,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: _selectedTextLayerId == layer.id
                                  ? Border.all(
                                      color: PublishFlowTokens.primaryStart,
                                    )
                                  : null,
                            ),
                            child: Text(
                              layer.text,
                              textAlign: layer.alignment,
                              style: TextStyle(
                                color: Color(layer.colorValue),
                                fontSize: layer.fontSize,
                                fontWeight: layer.fontFamily == 'Bold'
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                shadows: const <Shadow>[
                                  Shadow(
                                    blurRadius: 6,
                                    color: Color(0x99000000),
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ];
  }

  Widget _buildNextBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_errorMessage != null) ...<Widget>[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _isReady && !_isSubmitting
                      ? PublishFlowTokens.primaryGradient
                      : null,
                  color: _isReady && !_isSubmitting
                      ? null
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isReady && !_isSubmitting ? _handleNext : null,
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isReady = false;
                });
                _initializeVideo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PublishFlowTokens.primaryStart,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionOverlay(PendingPost pending) {
    return IgnorePointer(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          pending.manualCaptionText.trim().isNotEmpty
              ? pending.manualCaptionText.trim()
              : (pending.captionSegments.isNotEmpty
                  ? pending.captionSegments.first.text
                  : ''),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildLetterboxBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PublishFlowTokens.border),
      ),
      child: const Text(
        'This video may appear letterboxed in the feed. '
        'Use Aspect for a tighter preview.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

class _EditToolButton extends StatelessWidget {
  const _EditToolButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: PublishFlowTokens.glassPanel(radius: 14).copyWith(
            border: Border.all(
              color: isActive
                  ? PublishFlowTokens.primaryStart.withValues(alpha: 0.55)
                  : PublishFlowTokens.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
