import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../features/publish/pending_post.dart';
import '../features/publish/preview_captions_sheet.dart';
import '../features/publish/preview_crop_sheet.dart';
import '../features/publish/preview_trim_playback.dart';
import '../features/publish/preview_trim_sheet.dart';
import '../features/publish/preview_video_frame.dart';
import '../features/publish/publish_flow_tokens.dart';
import '../utils/video_preview_letterbox.dart';

/// Returned when the user chooses Retake from preview.
enum VideoRecordingPreviewRetake {
  retake,
}

class VideoRecordingPreview extends StatefulWidget {
  final File videoFile;

  const VideoRecordingPreview({
    super.key,
    required this.videoFile,
  });

  @override
  State<VideoRecordingPreview> createState() => _VideoRecordingPreviewState();
}

class _VideoRecordingPreviewState extends State<VideoRecordingPreview> {
  late VideoPlayerController _controller;
  PreviewTrimPlayback? _trimPlayback;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isSubmitting = false;
  bool _isReady = false;
  String? _errorMessage;
  late PendingPost _pending;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (!await widget.videoFile.exists()) {
        throw Exception('Video file does not exist');
      }
      final int fileSize = await widget.videoFile.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }
      _controller = VideoPlayerController.file(widget.videoFile);
      _controller.addListener(_onVideoPlayerError);
      await _controller.initialize();
      if (!mounted) {
        return;
      }
      final Duration duration = _controller.value.duration;
      final double aspect = _controller.value.size.height > 0
          ? _controller.value.size.width / _controller.value.size.height
          : 9 / 16;
      _pending = PendingPost.fromVideoFile(
        videoFile: widget.videoFile,
        duration: duration,
        videoAspectRatio: aspect,
      );
      _trimPlayback = PreviewTrimPlayback(
        controller: _controller,
        pending: _pending,
        onTick: () {
          if (mounted) {
            setState(() {});
          }
        },
      );
      setState(() {
        _isInitialized = true;
        _isReady =
            _controller.value.isInitialized && duration.inMilliseconds > 0;
      });
      _validateVideo(duration);
      await _trimPlayback!.seekToTrimStart();
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = 'Failed to load video. Please try recording again.';
        });
      }
    }
  }

  void _onVideoPlayerError() {
    if (_controller.value.hasError && mounted) {
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
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        final Duration position = _controller.value.position;
        if (position < _pending.trimStart || position >= _pending.trimEnd) {
          _controller.seekTo(_pending.trimStart);
        }
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _handleConfirm() async {
    if (!_isReady || _isSubmitting) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);
    if (_isPlaying) {
      _controller.pause();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_pending);
  }

  Future<void> _handleRetake() async {
    final bool? shouldDiscard = await _showDiscardDialog();
    if (shouldDiscard == true && mounted) {
      Navigator.of(context).pop(VideoRecordingPreviewRetake.retake);
    }
  }

  Future<void> _openTrimEditor() async {
    final ({Duration start, Duration end})? result =
        await PreviewTrimSheet.show(context: context, pending: _pending);
    if (result == null || !mounted) {
      return;
    }
    if (result.end <= result.start) {
      _showSnack('End time must be after start time.');
      return;
    }
    if (result.end - result.start < PendingPost.minTrimSegment) {
      _showSnack('Clip must be at least 1 second.');
      return;
    }
    setState(() {
      _pending = _pending.copyWith(
        trimStart: result.start,
        trimEnd: result.end,
      );
      _trimPlayback?.applyPending(_pending);
    });
    if (_isPlaying) {
      await _controller.seekTo(_pending.trimStart);
    }
  }

  Future<void> _openCropEditor() async {
    final double aspect = _controller.value.size.height > 0
        ? _controller.value.size.width / _controller.value.size.height
        : 9 / 16;
    final PreviewCropMode? mode = await PreviewCropSheet.show(
      context: context,
      selected: _pending.cropMode,
      isLandscape: aspect > 1.0,
    );
    if (mode == null || !mounted) {
      return;
    }
    setState(() {
      _pending = _pending.copyWith(
        cropMode: mode,
        aspectRatio: aspect,
      );
    });
  }

  Future<void> _openCaptionsEditor() async {
    final PreviewCaptionsResult? result = await PreviewCaptionsSheet.show(
      context: context,
      pending: _pending,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _pending = _pending.copyWith(
        captionsEnabled: result.captionsEnabled,
        manualCaptionText: result.manualCaptionText,
      );
    });
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

  Future<bool?> _showDiscardDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            child: const Text('Keep', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final int totalSeconds = duration.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _showLetterboxWarning {
    if (!_isInitialized) {
      return false;
    }
    final double aspect = _pending.aspectRatio ??
        (_controller.value.size.height > 0
            ? _controller.value.size.width / _controller.value.size.height
            : 9 / 16);
    return _pending.cropMode == PreviewCropMode.fit &&
        shouldLetterboxNonVerticalAspectRatio(aspect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          if (_isInitialized && _isReady)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: PreviewVideoFrame(
                    controller: _controller,
                    pending: _pending,
                  ),
                ),
              ),
            )
          else if (_isInitialized && _errorMessage != null)
            _buildErrorState()
          else
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.48),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const <double>[0.0, 0.18, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),
          _buildTopControls(),
          if (_isInitialized && _isReady && _showLetterboxWarning)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              left: 20,
              right: 20,
              child: _buildLetterboxBanner(),
            ),
          if (_isInitialized && _isReady && _pending.hasCaptionOverlay)
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.paddingOf(context).bottom + 200,
              child: _buildCaptionOverlay(),
            ),
          if (_isInitialized && _isReady) _buildQuickToolsRow(),
          if (_isInitialized) _buildBottomControls(),
          if (_isInitialized && _isReady)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
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
                  backgroundColor: const Color(0xFF9248D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionOverlay() {
    return IgnorePointer(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _pending.manualCaptionText.trim(),
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

  Widget _buildTopControls() {
    final Duration badgeDuration =
        _isReady ? _pending.effectiveDuration : Duration.zero;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: _handleRetake,
            child: Container(
              width: 44,
              height: 44,
              decoration: PublishFlowTokens.glassCircle(),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  'Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check the framing before you post',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: PublishFlowTokens.glassPanel(radius: 999),
              child: Text(
                _pending.hasTrim
                    ? '${_formatDuration(badgeDuration)} trimmed'
                    : _formatDuration(badgeDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
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
        'Try 9:16 for best reach.',
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

  Widget _buildQuickToolsRow() {
    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + 118,
      left: 16,
      right: 16,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _PreviewToolButton(
              label: 'Trim',
              icon: Icons.content_cut_rounded,
              isActive: _pending.hasTrim,
              onTap: _openTrimEditor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PreviewToolButton(
              label: 'Crop',
              icon: Icons.crop_rounded,
              isActive: _pending.cropMode != PreviewCropMode.fit,
              onTap: _openCropEditor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PreviewToolButton(
              label: 'Captions',
              icon: Icons.subtitles_outlined,
              isActive: _pending.hasCaptionOverlay,
              onTap: _openCaptionsEditor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + 18,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_errorMessage != null) ...<Widget>[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.28)),
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
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: PublishFlowTokens.glassPanel(radius: 24),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: _handleRetake,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PublishFlowTokens.border),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Retake',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _isReady && !_isSubmitting ? _handleConfirm : null,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _isReady && !_isSubmitting
                            ? PublishFlowTokens.primaryGradient
                            : null,
                        color: _isReady && !_isSubmitting
                            ? null
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Use Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewToolButton extends StatelessWidget {
  const _PreviewToolButton({
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: PublishFlowTokens.glassPanel(radius: 12).copyWith(
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
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: 10,
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
