import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'video_publishing_screen.dart';
import 'instant_response_button.dart';
import '../services/video_processing_service.dart';
import '../services/hashtag_lock_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

// Constants for video editing
class _VideoEditingConstants {
  static const double minVideoDurationSeconds = 3.0;
  static const double maxVideoDurationSeconds = 60.0;
  static const double minTrimDurationPercent = 0.05;
  static const double videoPreviewHeight = 300.0;
  static const double sliderHeight = 80.0;
  static const double sliderThumbRadius = 10.0;
  static const double sliderOverlayRadius = 20.0;
  static const int seekDebounceMs = 100;
  static const int hashtagDebounceMs = 500;
  static const Color primaryColor = Color(0xFF9248D2);
  static const Color backgroundColor = Color(0xFF0E1220);
}

class VideoEditingScreen extends StatefulWidget {
  final File videoFile;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const VideoEditingScreen({
    super.key,
    required this.videoFile,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<VideoEditingScreen> createState() => _VideoEditingScreenState();
}

class _VideoEditingScreenState extends State<VideoEditingScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  late TabController _tabController;
  String? _initializationError;

  // Editing state
  String _selectedFilter = 'none';
  String _caption = '';
  final List<String> _hashtags = [];

  // Trimming state
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  Timer? _seekTimer;
  double? _dragStartValue;
  double? _dragEndValue;

  // Video processing
  final VideoProcessingService _videoProcessor = VideoProcessingService();
  File? _processedVideoFile;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingMessage = '';

  // Hashtag validation
  Timer? _hashtagValidationTimer;
  final TextEditingController _hashtagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();

      // Validate video duration
      final duration = _controller!.value.duration;
      if (duration.inSeconds < _VideoEditingConstants.minVideoDurationSeconds) {
        throw Exception(
            'Video is too short (minimum ${_VideoEditingConstants.minVideoDurationSeconds}s)');
      }
      if (duration.inSeconds > _VideoEditingConstants.maxVideoDurationSeconds) {
        throw Exception(
            'Video is too long (maximum ${_VideoEditingConstants.maxVideoDurationSeconds}s)');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _initializationError = null;
        });
      }
    } catch (e) {
      developer.log('❌ Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _initializationError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _seekTimer?.cancel();
    _hashtagValidationTimer?.cancel();
    _hashtagController.dispose();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    if (_controller != null) {
      try {
        _controller!.pause();
        _controller!.dispose();
      } catch (e) {
        developer.log('⚠️ Error disposing controller: $e');
      } finally {
        _controller = null;
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _VideoEditingConstants.backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildVideoPreview(),
          _buildEditingTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swiping to prevent gesture conflicts
              children: [
                _buildTrimTab(),
                _buildAudioTab(),
                _buildEffectsTab(),
                _buildTextTab(),
              ],
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: _VideoEditingConstants.sliderHeight / 4,
        right: _VideoEditingConstants.sliderHeight / 4,
        bottom: _VideoEditingConstants.sliderHeight / 4,
      ),
      child: Row(
        children: [
          InstantIconButton(
            onPressed: widget.onCancel,
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
            hapticType: HapticFeedbackType.selectionClick,
          ),
          const SizedBox(width: 16),
          const Text(
            'Edit Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InstantResponseButton(
            onPressed: _isInitialized ? _showPreview : null,
            hapticType: HapticFeedbackType.mediumImpact,
            scaleOnPress: 0.95,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isInitialized
                    ? _VideoEditingConstants.primaryColor
                    : Colors.grey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      height: _VideoEditingConstants.videoPreviewHeight,
      margin: const EdgeInsets.symmetric(
          horizontal: _VideoEditingConstants.sliderHeight / 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        color: Colors.black,
      ),
      child: Stack(
        children: [
          if (_isInitialized && _controller != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_initializationError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading video',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _initializationError!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          if (_isInitialized && _controller != null)
            Center(
              child: InstantResponseButton(
                onPressed: _togglePlayPause,
                hapticType: HapticFeedbackType.lightImpact,
                scaleOnPress: 0.9,
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
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
          if (_selectedFilter != 'none')
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  color: _getFilterColor().withValues(alpha: 0.3),
                ),
              ),
            ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _processingProgress > 0 ? _processingProgress : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            _VideoEditingConstants.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _processingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_processingProgress > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(_processingProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditingTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: _VideoEditingConstants.sliderHeight / 4,
          vertical: _VideoEditingConstants.sliderHeight / 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _VideoEditingConstants.primaryColor,
          borderRadius: BorderRadius.circular(AppSizes.radius),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        tabs: const [
          Tab(text: 'Trim'),
          Tab(text: 'Audio'),
          Tab(text: 'Effects'),
          Tab(text: 'Text'),
        ],
      ),
    );
  }

  Widget _buildTrimTab() {
    print('📑 ===== TRIM TAB BUILDING =====');
    print('📑 _isInitialized: $_isInitialized');
    print('📑 _controller: ${_controller != null}');
    developer.log('📑 ===== TRIM TAB BUILDING =====');
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(_VideoEditingConstants.sliderHeight / 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trim Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                print('📑 Building duration text');
                if (_isInitialized && _controller != null) {
                  return Text(
                    'Duration: ${_controller!.value.duration.inSeconds}s',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  );
                } else {
                  return Text(
                    'Status: initialized=$_isInitialized, controller=${_controller != null}',
                    style: const TextStyle(color: Colors.red),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            // DEBUG: Always show slider container
            Container(
              height: _VideoEditingConstants.sliderHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 3), // DEBUG: Thick red border
              ),
              child: Builder(
                builder: (context) {
                  print('📑 Building slider container child');
                  print('📑 _isInitialized: $_isInitialized, _controller: ${_controller != null}');
                  if (_isInitialized && _controller != null) {
                    print('📑 Calling _buildTimelineSlider()');
                    return _buildTimelineSlider();
                  } else {
                    print('📑 Showing loading indicator');
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InstantResponseButton(
                  onPressed:
                      (_isInitialized && _hasTrimChanges()) ? _resetTrim : null,
                  hapticType: HapticFeedbackType.selectionClick,
                  scaleOnPress: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: (_isInitialized && _hasTrimChanges())
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: (_isInitialized && _hasTrimChanges())
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InstantResponseButton(
                  onPressed: (_isInitialized &&
                          !_isProcessing &&
                          _hasTrimChanges())
                      ? _applyTrim
                      : null,
                  hapticType: HapticFeedbackType.mediumImpact,
                  scaleOnPress: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: (_isInitialized &&
                              !_isProcessing &&
                              _hasTrimChanges())
                          ? _VideoEditingConstants.primaryColor
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Processing...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )
                        : const Text(
                            'Apply Trim',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isInitialized && _controller != null)
            Builder(
              builder: (context) {
                final duration = _controller!.value.duration;
                final startMs = _trimStart * duration.inMilliseconds;
                final endMs = _trimEnd * duration.inMilliseconds;
                final lengthMs = (_trimEnd - _trimStart) * duration.inMilliseconds;
                return Text(
                  'Start: ${_formatDuration(startMs)} | End: ${_formatDuration(endMs)} | Length: ${_formatDuration(lengthMs)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSlider() {
    print('🔍 _buildTimelineSlider() CALLED');
    print('🔍 Controller null? ${_controller == null}');
    if (_controller != null) {
      print('🔍 Controller initialized? ${_controller!.value.isInitialized}');
      print('🔍 Controller value: ${_controller!.value}');
    }
    
    if (_controller == null) {
      print('⚠️ Slider not built: controller is NULL');
      return Container(
        height: 40,
        color: Colors.red.withValues(alpha: 0.3),
        child: const Center(child: Text('CONTROLLER NULL', style: TextStyle(color: Colors.white))),
      );
    }
    
    if (!_controller!.value.isInitialized) {
      print('⚠️ Slider not built: controller not initialized');
      return Container(
        height: 40,
        color: Colors.orange.withValues(alpha: 0.3),
        child: const Center(child: Text('CONTROLLER NOT INITIALIZED', style: TextStyle(color: Colors.white))),
      );
    }

    // Determine if slider should be enabled
    final bool isEnabled = _isInitialized && !_isProcessing && _controller != null;
    
    print('🎚️ ===== SLIDER BUILDING =====');
    print('🎚️ Enabled: $isEnabled');
    print('🎚️ Initialized: $_isInitialized');
    print('🎚️ Processing: $_isProcessing');
    print('🎚️ Controller exists: ${_controller != null}');
    print('🎚️ Trim values: start=$_trimStart, end=$_trimEnd');
    print('🎚️ onChanged will be: ${isEnabled ? "CALLBACK" : "NULL"}');
    developer.log('🎚️ ===== SLIDER BUILDING =====');
    developer.log('🎚️ Enabled: $isEnabled');

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _VideoEditingConstants.primaryColor,
        inactiveTrackColor: Colors.white.withValues(alpha: isEnabled ? 0.3 : 0.1),
        thumbColor: _VideoEditingConstants.primaryColor,
        overlayColor: _VideoEditingConstants.primaryColor.withValues(alpha: 0.3),
        trackHeight: 6,
        disabledActiveTrackColor: Colors.grey,
        disabledThumbColor: Colors.grey,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: _VideoEditingConstants.sliderThumbRadius,
          disabledThumbRadius: _VideoEditingConstants.sliderThumbRadius,
        ),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: _VideoEditingConstants.sliderOverlayRadius,
        ),
      ),
      child: RangeSlider(
        values: RangeValues(_trimStart, _trimEnd),
        min: 0.0,
        max: 1.0,
        onChanged: isEnabled ? (RangeValues values) {
          print('🎚️🎚️🎚️ onChanged CALLED! start=${values.start}, end=${values.end}');
          developer.log('🎚️ onChanged: start=${values.start}, end=${values.end}');
          setState(() {
            _trimStart = values.start;
            _trimEnd = values.end;
          });
          _debouncedSeekToTrimStart();
        } : null,
        onChangeStart: isEnabled ? (RangeValues values) {
          print('🎚️🎚️🎚️ onChangeStart CALLED! start=${values.start}, end=${values.end}');
          _dragStartValue = _trimStart;
          _dragEndValue = _trimEnd;
          developer.log('🎚️ onChangeStart: start=${values.start}, end=${values.end}');
        } : null,
        onChangeEnd: isEnabled ? (RangeValues values) {
          developer.log('🎚️ onChangeEnd: start=${values.start}, end=${values.end}');
          
          double finalStart = values.start.clamp(0.0, 1.0);
          double finalEnd = values.end.clamp(0.0, 1.0);
          
          if (finalStart >= finalEnd) {
            final temp = finalStart;
            finalStart = finalEnd;
            finalEnd = temp;
          }
          
          final minDuration = _VideoEditingConstants.minTrimDurationPercent;
          if (finalEnd - finalStart < minDuration) {
            if (_dragStartValue != null && _dragEndValue != null) {
              final startDelta = (finalStart - _dragStartValue!).abs();
              final endDelta = (finalEnd - _dragEndValue!).abs();
              
              if (startDelta >= endDelta) {
                finalEnd = (finalStart + minDuration).clamp(0.0, 1.0);
                if (finalEnd >= 1.0) {
                  finalEnd = 1.0;
                  finalStart = (1.0 - minDuration).clamp(0.0, 1.0);
                }
              } else {
                finalStart = (finalEnd - minDuration).clamp(0.0, 1.0);
                if (finalStart <= 0.0) {
                  finalStart = 0.0;
                  finalEnd = minDuration.clamp(0.0, 1.0);
                }
              }
            } else {
              final midpoint = (finalStart + finalEnd) / 2;
              finalStart = (midpoint - minDuration / 2).clamp(0.0, 1.0);
              finalEnd = (midpoint + minDuration / 2).clamp(0.0, 1.0);
            }
          }
          
          setState(() {
            _trimStart = finalStart;
            _trimEnd = finalEnd;
            _dragStartValue = null;
            _dragEndValue = null;
          });
          
          _seekToTrimStart();
          developer.log('🎚️ Final: start=$finalStart, end=$finalEnd');
        } : null,
      ),
    );
  }

  void _resetTrim() {
    setState(() {
      _trimStart = 0.0;
      _trimEnd = 1.0;
    });
    _seekToTrimStart();
  }

  void _seekToTrimStart() {
    if (!_isInitialized || _controller == null) return;
    try {
      final startTime = Duration(
        milliseconds: (_trimStart *
                _controller!.value.duration.inMilliseconds)
            .round(),
      );
      _controller!.seekTo(startTime);
    } catch (e) {
      developer.log('⚠️ Error seeking to trim start: $e');
    }
  }

  void _debouncedSeekToTrimStart() {
    _seekTimer?.cancel();
    _seekTimer = Timer(
        const Duration(
            milliseconds: _VideoEditingConstants.seekDebounceMs), () {
      _seekToTrimStart();
    });
  }

  bool _hasTrimChanges() {
    return _trimStart > 0.01 || _trimEnd < 0.99;
  }

  String _formatDuration(double milliseconds) {
    final duration = Duration(milliseconds: milliseconds.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final ms = (duration.inMilliseconds % 1000) ~/ 100;
    if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$ms';
    } else {
      return '${seconds}.${ms}s';
    }
  }

  Future<void> _applyTrim() async {
    if (!_isInitialized || _controller == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Trimming video...';
      _processingProgress = 0.0;
    });

    try {
      final startTime = Duration(
        milliseconds:
            (_trimStart * _controller!.value.duration.inMilliseconds).round(),
      );
      final endTime = Duration(
        milliseconds:
            (_trimEnd * _controller!.value.duration.inMilliseconds).round(),
      );

      developer.log(
          '🎬 Applying trim: ${startTime.inSeconds}s - ${endTime.inSeconds}s');

      final result = await _videoProcessor.trimVideo(
        inputFile: _processedVideoFile ?? widget.videoFile,
        videoId: 'trim_${DateTime.now().millisecondsSinceEpoch}',
        startTime: startTime,
        endTime: endTime,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _processingProgress = progress;
            });
          }
        },
      );

      _processedVideoFile = result;

      await _reloadVideoController(_processedVideoFile!);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _trimStart = 0.0;
          _trimEnd = 1.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Video trimmed successfully! ${startTime.inSeconds}s - ${endTime.inSeconds}s'),
            backgroundColor: _VideoEditingConstants.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      developer.log('❌ Error trimming video: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error trimming video. Video trimming requires FFmpeg and is not yet implemented. Error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _reloadVideoController(File videoFile) async {
    try {
      final oldController = _controller;
      _controller = null;

      if (oldController != null) {
        try {
          await oldController.pause();
          await oldController.dispose();
        } catch (e) {
          developer.log('⚠️ Error disposing old controller: $e');
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));

      _controller = VideoPlayerController.file(videoFile);
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = false;
        });
      }
    } catch (e) {
      developer.log('❌ Error reloading video controller: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _initializationError = e.toString();
        });
      }
      rethrow;
    }
  }

  Widget _buildAudioTab() {
    return Padding(
      padding: const EdgeInsets.all(_VideoEditingConstants.sliderHeight / 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio & Music',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: const Column(
              children: [
                Icon(Icons.music_note, color: Colors.white70, size: 48),
                SizedBox(height: 16),
                Text(
                  'Audio & Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Audio mixing, music library, and voiceover features will be available in a future update.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsTab() {
    return Padding(
      padding: const EdgeInsets.all(_VideoEditingConstants.sliderHeight / 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters & Effects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: const Column(
              children: [
                Icon(Icons.photo_filter, color: Colors.white70, size: 48),
                SizedBox(height: 16),
                Text(
                  'Video Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Video filters and effects will be available in a future update. FFmpeg integration required.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(_VideoEditingConstants.sliderHeight / 4),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Text & Captions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: _caption)
                ..selection = TextSelection.collapsed(
                    offset: _caption.length),
              onChanged: (value) => setState(() => _caption = value),
              style: const TextStyle(color: Colors.white),
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: _VideoEditingConstants.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Text Overlay\n(Coming Soon)',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hashtags',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hashtagController,
              onChanged: _onHashtagInputChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add hashtags (e.g., #gaming #fun #viral)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: _VideoEditingConstants.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_hashtags.isNotEmpty) ...[
              const Text(
                'Detected Hashtags:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _hashtags
                    .map((hashtag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _VideoEditingConstants.primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            hashtag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Popular Hashtags:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHashtagChip('#trending'),
                _buildHashtagChip('#viral'),
                _buildHashtagChip('#fyp'),
                _buildHashtagChip('#gaming'),
                _buildHashtagChip('#fun'),
                _buildHashtagChip('#streaming'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onHashtagInputChanged(String value) {
    _hashtagValidationTimer?.cancel();
    _hashtagValidationTimer = Timer(
        const Duration(
            milliseconds: _VideoEditingConstants.hashtagDebounceMs), () {
      _validateAndExtractHashtags(value);
    });
  }

  Future<void> _validateAndExtractHashtags(String value) async {
    final hashtagRegex = RegExp(r'#\w+');
    final matches = hashtagRegex.allMatches(value);
    final extractedHashtags =
        matches.map((match) => match.group(0)!).toSet().toList();

    final currentUser = FirebaseAuth.instance.currentUser;
    final hashtagService = HashtagLockService();
    final validHashtags = <String>[];

    for (final hashtag in extractedHashtags) {
      final cleaned = hashtag.replaceAll('#', '');
      try {
        final validation =
            await hashtagService.validateHashtag(cleaned, currentUser?.uid);
        if (validation.isValid) {
          validHashtags.add(hashtag);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${validation.errorMessage} for #$cleaned'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        developer.log('⚠️ Error validating hashtag $hashtag: $e');
      }
    }

    if (mounted) {
      setState(() {
        _hashtags.clear();
        _hashtags.addAll(validHashtags);
      });
    }
  }

  Widget _buildHashtagChip(String hashtag) {
    final isSelected = _hashtags.contains(hashtag);
    return InstantResponseButton(
      onPressed: () {
        setState(() {
          if (isSelected) {
            _hashtags.remove(hashtag);
          } else {
            _hashtags.add(hashtag);
          }
        });
        _hashtagController.text = _hashtags.join(' ');
      },
      hapticType: HapticFeedbackType.selectionClick,
      scaleOnPress: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? _VideoEditingConstants.primaryColor
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _VideoEditingConstants.primaryColor
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          hashtag,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(_VideoEditingConstants.sliderHeight / 4),
      child: Row(
        children: [
          Expanded(
            child: InstantResponseButton(
              onPressed: widget.onCancel,
              hapticType: HapticFeedbackType.mediumImpact,
              scaleOnPress: 0.95,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InstantResponseButton(
              onPressed: _isInitialized ? _proceedToPublishing : null,
              hapticType: HapticFeedbackType.mediumImpact,
              scaleOnPress: 0.95,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _VideoEditingConstants.primaryColor,
                      AppColors.tertiary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: _isInitialized
                      ? const Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getFilterColor() {
    switch (_selectedFilter) {
      case 'vintage':
        return Colors.brown;
      case 'b&w':
        return Colors.grey;
      case 'sepia':
        return Colors.orange;
      case 'cool':
        return Colors.blue;
      case 'warm':
        return Colors.red;
      case 'bright':
        return Colors.yellow;
      case 'dark':
        return Colors.black;
      case 'blur':
        return Colors.purple;
      default:
        return Colors.transparent;
    }
  }

  void _showPreview() {
    if (_controller == null || !_isInitialized) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: InstantIconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
                hapticType: HapticFeedbackType.selectionClick,
              ),
            ),
            Center(
              child: InstantResponseButton(
                onPressed: _togglePlayPause,
                hapticType: HapticFeedbackType.lightImpact,
                scaleOnPress: 0.9,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (_controller != null && _isPlaying) {
        _controller!.pause();
        setState(() => _isPlaying = false);
      }
    });
  }

  void _proceedToPublishing() {
    if (!_isInitialized) return;
    final videoFileToUse = _processedVideoFile ?? widget.videoFile;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPublishingScreen(
          videoFile: videoFileToUse,
          caption: _caption,
          hashtags: _hashtags,
          onPublish: widget.onSave,
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
