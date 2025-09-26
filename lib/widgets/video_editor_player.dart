import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../services/logging_service.dart';

class VideoEditorPlayer extends StatefulWidget {
  final File videoFile;
  final Duration? startTime;
  final Duration? endTime;
  final bool isPlaying;
  final Function(Duration position)? onPositionChanged;
  final Function(bool isPlaying)? onPlayPauseChanged;
  final Function(Duration startTime, Duration endTime)? onTrimChanged;
  final VoidCallback? onTap;

  const VideoEditorPlayer({
    super.key,
    required this.videoFile,
    this.startTime,
    this.endTime,
    this.isPlaying = false,
    this.onPositionChanged,
    this.onPlayPauseChanged,
    this.onTrimChanged,
    this.onTap,
  });

  @override
  State<VideoEditorPlayer> createState() => _VideoEditorPlayerState();
}

class _VideoEditorPlayerState extends State<VideoEditorPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _isPlaying = widget.isPlaying;
    _startTime = widget.startTime ?? Duration.zero;
    _endTime = widget.endTime ?? Duration.zero;
  }

  @override
  void didUpdateWidget(VideoEditorPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _isPlaying = widget.isPlaying;
      if (_isPlaying) {
        _play();
      } else {
        _pause();
      }
    }
    if (oldWidget.startTime != widget.startTime || oldWidget.endTime != widget.endTime) {
      _startTime = widget.startTime ?? Duration.zero;
      _endTime = widget.endTime ?? Duration.zero;
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _duration = _controller!.value.duration;
          _endTime = _endTime == Duration.zero ? _duration : _endTime;
        });
        
        // Set up position listener
        _controller!.addListener(_onPositionChanged);
        
        // Set initial position
        if (_startTime > Duration.zero) {
          await _controller!.seekTo(_startTime);
        }
      }
    } catch (e) {
      LoggingService.instance.error('Error initializing video player', tag: 'VideoEditorPlayer', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  void _onPositionChanged() {
    if (_controller != null && mounted) {
      final position = _controller!.value.position;
      setState(() {
        _position = position;
      });
      
      widget.onPositionChanged?.call(position);
      
      // Auto-pause at end time
      if (_endTime > Duration.zero && position >= _endTime) {
        _pause();
        _seekTo(_startTime);
      }
    }
  }

  Future<void> _play() async {
    if (_controller != null && _isInitialized) {
      await _controller!.play();
      setState(() {
        _isPlaying = true;
      });
      widget.onPlayPauseChanged?.call(true);
    }
  }

  Future<void> _pause() async {
    if (_controller != null && _isInitialized) {
      await _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
      widget.onPlayPauseChanged?.call(false);
    }
  }

  Future<void> _seekTo(Duration position) async {
    if (_controller != null && _isInitialized) {
      await _controller!.seekTo(position);
      setState(() {
        _position = position;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPositionChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return GestureDetector(
      onTap: widget.onTap ?? _togglePlayPause,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video player
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              
              // Play/Pause overlay
              if (!_isPlaying)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              
              // Progress indicator
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildProgressBar(),
              ),
              
              // Time display
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration.inMilliseconds > 0 
        ? _position.inMilliseconds / _duration.inMilliseconds 
        : 0.0;
    
    final startProgress = _duration.inMilliseconds > 0 
        ? _startTime.inMilliseconds / _duration.inMilliseconds 
        : 0.0;
    
    final endProgress = _duration.inMilliseconds > 0 
        ? _endTime.inMilliseconds / _duration.inMilliseconds 
        : 1.0;

    return Container(
      height: 4,
      margin: const EdgeInsets.all(8),
      child: Stack(
        children: [
          // Background track
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Trimmed area
          Positioned(
            left: startProgress * MediaQuery.of(context).size.width,
            right: (1 - endProgress) * MediaQuery.of(context).size.width,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Progress indicator
          Positioned(
            left: 0,
            child: Container(
              width: progress * MediaQuery.of(context).size.width,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF9248D2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializeVideo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9248D2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Public methods for external control
  void play() => _play();
  void pause() => _pause();
  void seekTo(Duration position) => _seekTo(position);
  void setTrimRange(Duration startTime, Duration endTime) {
    setState(() {
      _startTime = startTime;
      _endTime = endTime;
    });
    widget.onTrimChanged?.call(startTime, endTime);
  }

  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
}
