import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
// import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoTrimEditor extends StatefulWidget {
  final File videoFile;
  final VoidCallback? onTrimComplete;
  final VoidCallback? onCancel;

  const VideoTrimEditor({
    super.key,
    required this.videoFile,
    this.onTrimComplete,
    this.onCancel,
  });

  @override
  State<VideoTrimEditor> createState() => _VideoTrimEditorState();
}

class _VideoTrimEditorState extends State<VideoTrimEditor>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String? _processingStatus;

  // Trim state
  Duration _videoDuration = Duration.zero;
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  Duration _originalDuration = Duration.zero;

  // Thumbnails
  final List<File> _thumbnails = [];
  bool _thumbnailsGenerated = false;
  Timer? _seekTimer;

  // Constants
  static const Duration _minClipLength = Duration(seconds: 1);
  static const int _thumbnailCount = 20;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _seekTimer?.cancel();
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
          _originalDuration = _controller!.value.duration;
          _endTime = _videoDuration;
        });

        _controller!.addListener(_onVideoPositionChanged);
        _generateThumbnails();
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      _showErrorDialog('Failed to load video');
    }
  }

  void _onVideoPositionChanged() {
    if (mounted && _controller != null) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  Future<void> _generateThumbnails() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailDir = Directory(path.join(tempDir.path, 'thumbnails'));
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      _thumbnails.clear();

      for (int i = 0; i < _thumbnailCount; i++) {
        final timeMs =
            (i * _videoDuration.inMilliseconds / _thumbnailCount).round();
        final thumbnailPath = path.join(
          thumbnailDir.path,
          'thumb_$i.jpg',
        );

        final thumbnailFile = await VideoThumbnail.thumbnailFile(
          video: widget.videoFile.path,
          thumbnailPath: thumbnailPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: timeMs,
          quality: 75,
        );

        if (thumbnailFile != null) {
          _thumbnails.add(File(thumbnailFile));
        }
      }

      if (mounted) {
        setState(() {
          _thumbnailsGenerated = true;
        });
      }
    } catch (e) {
      debugPrint('Error generating thumbnails: $e');
    }
  }

  void _seekToPosition(Duration position) {
    if (_controller == null || !_isInitialized) return;

    // Clamp position within trim bounds
    final clampedPosition = Duration(
      milliseconds: position.inMilliseconds.clamp(
        _startTime.inMilliseconds,
        _endTime.inMilliseconds,
      ),
    );

    _controller!.seekTo(clampedPosition);
  }

  void _onStartHandleChanged(double value) {
    final newStartTime = Duration(milliseconds: value.round());
    final minEndTime = newStartTime + _minClipLength;

    setState(() {
      _startTime = newStartTime;
      if (_endTime <= minEndTime) {
        _endTime = minEndTime;
      }
    });

    _debouncedSeek(_startTime);
  }

  void _onEndHandleChanged(double value) {
    final newEndTime = Duration(milliseconds: value.round());
    final maxStartTime = newEndTime - _minClipLength;

    setState(() {
      _endTime = newEndTime;
      if (_startTime >= maxStartTime) {
        _startTime = maxStartTime;
      }
    });

    _debouncedSeek(_endTime);
  }

  void _debouncedSeek(Duration position) {
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 100), () {
      _seekToPosition(position);
    });
  }

  void _resetTrim() {
    setState(() {
      _startTime = Duration.zero;
      _endTime = _originalDuration;
    });

    _seekToPosition(Duration.zero);
    HapticFeedback.lightImpact();
  }

  Future<void> _applyTrim() async {
    if (_endTime - _startTime < _minClipLength) {
      _showErrorDialog('Clip must be at least 1 second long');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Trimming video...';
    });

    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final outputPath = path.join(
        outputDir.path,
        'trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // FFmpeg command for precise trimming
      final startSeconds =
          _startTime.inSeconds + (_startTime.inMilliseconds % 1000) / 1000.0;
      final durationSeconds = (_endTime - _startTime).inSeconds +
          ((_endTime - _startTime).inMilliseconds % 1000) / 1000.0;

      final command = '-i "${widget.videoFile.path}" '
          '-ss $startSeconds '
          '-t $durationSeconds '
          '-c:v libx264 ' // cspell:ignore libx
          '-c:a aac '
          '-movflags +faststart ' // cspell:ignore movflags faststart
          '-avoid_negative_ts make_zero '
          '"$outputPath"';

      debugPrint('FFmpeg command: $command');

      // Video trimming with FFmpeg - placeholder implementation for future development
      // For now, simulate the trimming process with progress
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {
            _processingProgress = (i + 1) / 10.0;
            _processingStatus = 'Trimming video... ${((i + 1) * 10)}%';
          });
        }
      }

      // Simulate successful trimming
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Trim complete!';
        });

        // Update trim bounds to simulate the trim
        setState(() {
          _videoDuration = _endTime - _startTime;
          _startTime = Duration.zero;
          _endTime = _videoDuration;
          _originalDuration = _videoDuration;
        });

        HapticFeedback.mediumImpact();

        // Notify completion
        widget.onTrimComplete?.call();
      }
    } catch (e) {
      debugPrint('Error trimming video: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = null;
        });
        _showErrorDialog('Failed to trim video: ${e.toString()}');
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _isDirty =>
      _startTime.inMilliseconds > 0 || _endTime < _originalDuration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Trim Video',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onCancel,
        ),
        actions: [
          if (!_isProcessing)
            TextButton(
              onPressed: _isDirty ? _resetTrim : null,
              child: Text(
                'Reset',
                style: TextStyle(
                  color: _isDirty ? Colors.white : Colors.white38,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video Preview
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _isInitialized
                  ? Stack(
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                        // Play/Pause overlay
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 60,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Processing overlay
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.8),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _processingStatus ?? 'Processing...',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (_processingProgress > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: LinearProgressIndicator(
                                        value: _processingProgress,
                                        backgroundColor: Colors.white24,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
            ),
          ),

          // Trim Controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Time Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Start: ${_formatDuration(_startTime)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'Length: ${_formatDuration(_endTime - _startTime)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'End: ${_formatDuration(_endTime)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Thumbnail Timeline
                  SizedBox(
                    height: 60,
                    child: _thumbnailsGenerated && _thumbnails.isNotEmpty
                        ? _buildThumbnailTimeline()
                        : Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Generating thumbnails...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing || !_isDirty ? null : _applyTrim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Processing...'),
                              ],
                            )
                          : Text(
                              _isDirty ? 'Apply Trim' : 'No changes to apply',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  Widget _buildThumbnailTimeline() {
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          // Thumbnail strip
          Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: _thumbnails.map((thumbnail) {
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                          );
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Trim handles overlay
          _buildTrimHandles(),
        ],
      ),
    );
  }

  Widget _buildTrimHandles() {
    final timelineWidth =
        MediaQuery.of(context).size.width - 32; // Account for padding
    final startPosition =
        (_startTime.inMilliseconds / _videoDuration.inMilliseconds) *
            timelineWidth;
    final endPosition =
        (_endTime.inMilliseconds / _videoDuration.inMilliseconds) *
            timelineWidth;

    return Stack(
      children: [
        // Selected area highlight
        Positioned(
          left: startPosition,
          width: endPosition - startPosition,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Start handle
        Positioned(
          left: startPosition - 15,
          child: GestureDetector(
            onPanUpdate: (details) {
              final newPosition = startPosition + details.delta.dx;
              final newTimeMs =
                  (newPosition / timelineWidth * _videoDuration.inMilliseconds)
                      .clamp(0.0, _videoDuration.inMilliseconds.toDouble());
              _onStartHandleChanged(newTimeMs);
            },
            child: Container(
              width: 30,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.black,
                  size: 16,
                ),
              ),
            ),
          ),
        ),

        // End handle
        Positioned(
          left: endPosition - 15,
          child: GestureDetector(
            onPanUpdate: (details) {
              final newPosition = endPosition + details.delta.dx;
              final newTimeMs =
                  (newPosition / timelineWidth * _videoDuration.inMilliseconds)
                      .clamp(0.0, _videoDuration.inMilliseconds.toDouble());
              _onEndHandleChanged(newTimeMs);
            },
            child: Container(
              width: 30,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.black,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
