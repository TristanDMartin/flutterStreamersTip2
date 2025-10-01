import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class RecordingPreviewView extends StatefulWidget {
  final File videoFile;
  final VoidCallback? onBack;
  final VoidCallback? onUseVideo;

  const RecordingPreviewView({
    super.key,
    required this.videoFile,
    this.onBack,
    this.onUseVideo,
  });

  @override
  State<RecordingPreviewView> createState() => _RecordingPreviewViewState();
}

class _RecordingPreviewViewState extends State<RecordingPreviewView> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  bool _showControls = true;
  
  // Video adjustment settings
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  bool _showAdjustments = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _videoDuration = _controller!.value.duration;
        });
        
        // Listen to video position changes
        _controller!.addListener(_onVideoPositionChanged);
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        _showErrorDialog('Failed to load video');
      }
    }
  }

  void _onVideoPositionChanged() {
    if (mounted) {
      setState(() {
        _currentPosition = _controller!.value.position;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (_isPlaying) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
    
    HapticFeedback.lightImpact();
  }

  void _seekTo(Duration position) {
    if (_controller == null || !_isInitialized) return;
    _controller!.seekTo(position);
  }

  void _changePlaybackSpeed() {
    if (_controller == null || !_isInitialized) return;
    
    setState(() {
      _playbackSpeed = _playbackSpeed == 1.0 ? 1.5 : _playbackSpeed == 1.5 ? 2.0 : 1.0;
      _controller!.setPlaybackSpeed(_playbackSpeed);
    });
    
    HapticFeedback.lightImpact();
  }

  void _resetAdjustments() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
    });
    HapticFeedback.lightImpact();
  }

  void _toggleAdjustments() {
    setState(() {
      _showAdjustments = !_showAdjustments;
    });
    HapticFeedback.lightImpact();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Video Preview
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: Stack(
                  children: [
                    // Video Player
                    Center(
                      child: _isInitialized
                          ? AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            )
                          : const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                    ),
                    
                    // Video Adjustments Overlay
                    if (_showAdjustments) _buildAdjustmentsOverlay(),
                    
                    // Controls Overlay
                    if (_showControls) _buildControlsOverlay(),
                  ],
                ),
              ),
            ),
            
            // Bottom Controls
            if (_showControls) _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          // Title
          const Text(
            'Edit Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          // Adjustments toggle
          GestureDetector(
            onTap: _toggleAdjustments,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showAdjustments ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune,
                color: _showAdjustments ? Colors.white : Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentsOverlay() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Brightness
            _buildAdjustmentSlider(
              'Brightness',
              _brightness,
              -1.0,
              1.0,
              (value) => setState(() => _brightness = value),
              Icons.brightness_6,
            ),
            
            const SizedBox(height: 16),
            
            // Contrast
            _buildAdjustmentSlider(
              'Contrast',
              _contrast,
              0.5,
              2.0,
              (value) => setState(() => _contrast = value),
              Icons.contrast,
            ),
            
            const SizedBox(height: 16),
            
            // Saturation
            _buildAdjustmentSlider(
              'Saturation',
              _saturation,
              0.0,
              2.0,
              (value) => setState(() => _saturation = value),
              Icons.color_lens,
            ),
            
            const SizedBox(height: 16),
            
            // Reset button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _resetAdjustments,
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: _toggleAdjustments,
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Play/Pause button
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
            
            // Speed control
            GestureDetector(
              onTap: _changePlaybackSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          if (_isInitialized) _buildProgressBar(),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              // Retake button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Retake',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Use video button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (widget.onUseVideo != null) {
                      widget.onUseVideo!();
                    } else {
                      // Save or share the video
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Use Video',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _currentPosition.inMilliseconds.toDouble(),
            min: 0.0,
            max: _videoDuration.inMilliseconds.toDouble(),
            onChanged: (value) {
              _seekTo(Duration(milliseconds: value.round()));
            },
          ),
        ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_currentPosition),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              _formatDuration(_videoDuration),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
