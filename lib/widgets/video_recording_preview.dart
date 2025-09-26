import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class VideoRecordingPreview extends StatefulWidget {
  final File videoFile;
  final VoidCallback onRetake;
  final VoidCallback onUseVideo;

  const VideoRecordingPreview({
    super.key,
    required this.videoFile,
    required this.onRetake,
    required this.onUseVideo,
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
          _isReady = _controller.value.isInitialized && _controller.value.duration.inMilliseconds > 0;
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
    } else if (durationSeconds > 300) { // 5 minutes max
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
    
    // Navigate to next screen with video data
    widget.onUseVideo();
  }

  Future<void> _handleRetake() async {
    final shouldDiscard = await _showDiscardDialog();
    if (shouldDiscard == true) {
      widget.onRetake();
    }
  }

  Future<void> _handleBack() async {
    final shouldDiscard = await _showDiscardDialog();
    if (shouldDiscard == true && mounted) {
      Navigator.of(context).pop();
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

          // Top Controls
          _buildTopControls(),

          // Bottom Controls
          if (_isInitialized) _buildBottomControls(),

          // Play/Pause Overlay
          if (_isInitialized && _isReady)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
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
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: _handleBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Title
          const Text(
            'Preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Placeholder for balance
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Left: Retake button
            GestureDetector(
              onTap: _handleRetake,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            
            // Center: Spacer for visual balance
            const Expanded(child: SizedBox()),
            
            // Right: Confirm button
            GestureDetector(
              onTap: _isReady && !_isSubmitting ? _handleConfirm : null,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: _isReady && !_isSubmitting
                      ? const LinearGradient(
                          colors: [Color(0xFF9248D2), Color(0xFF1670DE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.grey.withValues(alpha: 0.3),
                            Colors.grey.withValues(alpha: 0.3),
                          ],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: _isReady && !_isSubmitting
                      ? [
                          BoxShadow(
                            color: const Color(0xFF9248D2).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.check,
                        color: _isReady ? Colors.white : Colors.grey,
                        size: 32,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

