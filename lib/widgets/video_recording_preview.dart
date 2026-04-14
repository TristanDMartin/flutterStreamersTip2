import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

enum VideoRecordingPreviewAction {
  retake,
  useVideo,
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
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isSubmitting = false;
  bool _isReady = false;
  String? _errorMessage;
  Duration? _videoDuration;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Check if file exists and is readable
      if (!await widget.videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      final fileSize = await widget.videoFile.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }

      _controller = VideoPlayerController.file(widget.videoFile);

      // Add error listener
      _controller.addListener(_onVideoPlayerError);

      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _videoDuration = _controller.value.duration;
          _isReady = _controller.value.isInitialized &&
              _controller.value.duration.inMilliseconds > 0;
        });

        // Validate video
        _validateVideo();
      }
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

  void _validateVideo() {
    if (_videoDuration == null) return;

    final durationSeconds = _videoDuration!.inSeconds;

    if (durationSeconds < 1) {
      setState(() {
        _errorMessage = 'Video too short (minimum 1 second)';
        _isReady = false;
      });
    } else if (durationSeconds > 300) {
      // 5 minutes max
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
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _handleConfirm() async {
    if (!_isReady || _isSubmitting) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isSubmitting = true;
    });

    // Freeze preview frame
    if (_isPlaying) {
      _controller.pause();
    }

    if (!mounted) return;
    Navigator.of(context).pop(VideoRecordingPreviewAction.useVideo);
  }

  Future<void> _handleRetake() async {
    final shouldDiscard = await _showDiscardDialog();
    if (shouldDiscard == true && mounted) {
      Navigator.of(context).pop(VideoRecordingPreviewAction.retake);
    }
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
        actions: [
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
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Video Player - Fullscreen
          if (_isInitialized && _isReady)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else if (_isInitialized && _errorMessage != null)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
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
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
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
                    colors: [
                      Colors.black.withValues(alpha: 0.48),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.18, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Top Controls
          _buildTopControls(),

          // Bottom Controls
          if (_isInitialized) _buildBottomControls(),

          // Play/Pause Overlay
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

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleRetake,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Expanded(
            child: Column(
              children: [
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
          if (_videoDuration != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                _formatDuration(_videoDuration!),
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

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 18,
      left: 16,
      right: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _errorMessage == null
                        ? const Color(0xFF1FBF75).withValues(alpha: 0.18)
                        : Colors.red.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _errorMessage == null
                          ? const Color(0xFF1FBF75).withValues(alpha: 0.35)
                          : Colors.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _errorMessage == null ? 'Ready to post' : 'Needs attention',
                    style: TextStyle(
                      color: _errorMessage == null
                          ? const Color(0xFF7FF0B7)
                          : const Color(0xFFFFA6A6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (_videoDuration != null)
                  Text(
                    'Duration ${_formatDuration(_videoDuration!)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1322).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _handleRetake,
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Retake',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isReady && !_isSubmitting ? _handleConfirm : null,
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: _isReady && !_isSubmitting
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF9248D2),
                                    Color(0xFF1670DE),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.withValues(alpha: 0.25),
                                    Colors.grey.withValues(alpha: 0.25),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _isReady && !_isSubmitting
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF9248D2)
                                        .withValues(alpha: 0.30),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Use video',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
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
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.22),
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
          ],
        ),
      ),
    );
  }
}
