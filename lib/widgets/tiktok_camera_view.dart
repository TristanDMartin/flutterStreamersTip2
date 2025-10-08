import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tiktok_camera_service.dart';
import '../services/global_playback_coordinator.dart';
import '../providers/home_provider.dart';
import 'video_recording_preview.dart';
import 'video_edit_view.dart';

/// TikTok-quality camera view with professional video recording
///
/// Implements the complete TikTok camera spec:
/// - Zero stretch/squash distortion
/// - True 9:16 vertical video
/// - Stable autofocus/exposure/white-balance
/// - Smooth 60fps with stabilization
/// - High quality encoding
class TikTokCameraView extends ConsumerStatefulWidget {
  const TikTokCameraView({super.key});

  @override
  ConsumerState<TikTokCameraView> createState() => _TikTokCameraViewState();
}

class _TikTokCameraViewState extends ConsumerState<TikTokCameraView>
    with WidgetsBindingObserver {
  final TikTokCameraService _cameraService = TikTokCameraService();
  final GlobalPlaybackCoordinator _playbackCoordinator =
      GlobalPlaybackCoordinator();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFocusing = false;
  bool _showGrid = false;
  bool _showQualityInfo = false;
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Pause all videos when opening camera
    _playbackCoordinator.pauseAll(reason: 'cameraViewOpened');

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _cameraService.dispose();

    // Resume playback when leaving camera
    _playbackCoordinator.resumePlayback();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCamera();
    }
  }

  /// Initialize camera with TikTok-quality settings
  Future<void> _initializeCamera() async {
    try {
      log('🎥 TikTokCameraView: Initializing camera...');

      await _cameraService.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        log('✅ TikTokCameraView: Camera initialized successfully');
      }
    } catch (e) {
      log('❌ TikTokCameraView: Camera initialization failed: $e');
      _showErrorDialog('Camera initialization failed: ${e.toString()}');
    }
  }

  /// Pause camera when app goes to background
  Future<void> _pauseCamera() async {
    if (_isRecording) {
      await _stopRecording();
    }
    // Camera will be automatically paused by the system
  }

  /// Resume camera when app comes to foreground
  Future<void> _resumeCamera() async {
    // Camera will be automatically resumed by the system
  }

  /// Handle tap-to-focus with TikTok-style feedback
  void _onTapToFocus(TapDownDetails details) async {
    if (!_isInitialized || _isRecording) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPoint = renderBox.globalToLocal(details.globalPosition);

      // Calculate normalized coordinates (0.0 to 1.0)
      final double x = localPoint.dx / renderBox.size.width;
      final double y = localPoint.dy / renderBox.size.height;

      // Clamp to valid range
      final double clampedX = x.clamp(0.0, 1.0);
      final double clampedY = y.clamp(0.0, 1.0);

      setState(() {
        _focusPoint = localPoint;
        _isFocusing = true;
      });

      // Set focus and exposure points
      await _cameraService.setFocusPoint(Offset(clampedX, clampedY));

      // Hide focus indicator after animation
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isFocusing = false;
          });
        }
      });

      // Haptic feedback
      HapticFeedback.lightImpact();
      log('🎯 Focus point set: ($clampedX, $clampedY)');
    } catch (e) {
      log('❌ Error setting focus: $e');
    }
  }

  /// Handle zoom gestures
  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (!_isInitialized || _isRecording) return;

    try {
      final double newZoom = (_currentZoom * details.scale).clamp(1.0, 4.0);

      setState(() {
        _currentZoom = newZoom;
      });

      await _cameraService.setZoomLevel(newZoom);
      log('🔍 Zoom set to: $newZoom');
    } catch (e) {
      log('❌ Error setting zoom: $e');
    }
  }

  /// Start video recording with TikTok-quality settings
  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording) return;

    try {
      log('🎬 Starting TikTok-quality video recording...');

      await _cameraService.startRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });

      // Haptic feedback
      HapticFeedback.mediumImpact();
      log('✅ Video recording started');
    } catch (e) {
      log('❌ Error starting recording: $e');
      _showErrorDialog('Failed to start recording: ${e.toString()}');
    }
  }

  /// Stop video recording
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      log('🛑 Stopping video recording...');

      final videoFile = await _cameraService.stopRecording();

      setState(() {
        _isRecording = false;
      });

      _recordingTimer?.cancel();
      _recordingTimer = null;

      // Haptic feedback
      HapticFeedback.lightImpact();

      // Navigate to VideoRecordingPreview
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoRecordingPreview(
              videoFile: File(videoFile.path),
              onRetake: () => Navigator.of(context).pop(),
              onUseVideo: () {
                // Close VideoRecordingPreview and navigate to VideoEditView
                Navigator.of(context).pop(); // Close VideoRecordingPreview
                Navigator.of(context).pop(); // Close CameraView
                // Navigate to VideoEditView
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VideoEditView(
                      videoFile: File(videoFile.path),
                      onCancel: () => Navigator.of(context).pop(),
                      onNext: () {
                        // Handle next step (publishing, etc.)
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      log('✅ Video recording stopped: ${videoFile.path}');
    } catch (e) {
      log('❌ Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording: ${e.toString()}');
    }
  }

  /// Switch between front and back cameras
  Future<void> _switchCamera() async {
    if (!_isInitialized || _isRecording) return;

    try {
      log('🔄 Switching camera...');

      // Temporarily set initialized to false to show loading
      setState(() {
        _isInitialized = false;
      });

      await _cameraService.switchCamera();

      // Small delay to ensure camera is fully initialized
      await Future.delayed(const Duration(milliseconds: 100));

      // Debug camera state
      log('🔍 Camera state after switch:');
      log('  - Controller: ${_cameraService.controller != null}');
      log('  - IsInitialized: ${_cameraService.isInitialized}');
      log('  - CurrentLensDirection: ${_cameraService.currentLensDirection}');
      if (_cameraService.controller != null) {
        log('  - ControllerValue.isInitialized: ${_cameraService.controller!.value.isInitialized}');
        log('  - PreviewSize: ${_cameraService.controller!.value.previewSize}');
      }

      // Update state to show the new camera
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Force a rebuild to ensure the preview updates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }

      // Haptic feedback
      HapticFeedback.lightImpact();

      log('✅ Camera switched successfully');
    } catch (e) {
      log('❌ Error switching camera: $e');

      // Reset to initialized state even if there was an error
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      _showErrorDialog('Failed to switch camera: ${e.toString()}');
    }
  }

  /// Toggle grid lines
  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
    HapticFeedback.lightImpact();
  }

  /// Toggle quality info display
  void _toggleQualityInfo() {
    setState(() {
      _showQualityInfo = !_showQualityInfo;
    });
    HapticFeedback.lightImpact();

    // Log Pixel 6 quality status for debugging
    if (_showQualityInfo) {
      final qualityStatus = _cameraService.getPixel6QualityStatus();
      final qualityInfo = _cameraService.getQualityInfo();
      log('📱 Pixel 6 Quality Status: $qualityStatus');
      log('📱 Current Camera: ${qualityInfo['cameraType']} - ${qualityInfo['qualityLevel']}');
    }
  }

  /// Pick video from gallery (TikTok style)
  Future<void> _pickFromGallery() async {
    try {
      log('📱 Opening gallery picker...');

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5 minute limit
      );

      if (video != null && mounted) {
        log('📱 Video selected from gallery: ${video.path}');
        HapticFeedback.lightImpact();

        // Navigate to VideoRecordingPreview
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoRecordingPreview(
              videoFile: File(video.path),
              onRetake: () => Navigator.of(context).pop(),
              onUseVideo: () {
                // Close VideoRecordingPreview and navigate to VideoEditView
                Navigator.of(context).pop(); // Close VideoRecordingPreview
                Navigator.of(context).pop(); // Close CameraView
                // Navigate to VideoEditView
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VideoEditView(
                      videoFile: File(video.path),
                      onCancel: () => Navigator.of(context).pop(),
                      onNext: () {
                        // Handle next step (publishing, etc.)
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      log('❌ Error picking video from gallery: $e');
      _showErrorDialog('Error selecting video: ${e.toString()}');
    }
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Format recording duration
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview with proper aspect ratio
          _buildCameraPreview(),

          // Grid overlay
          if (_showGrid) _buildGridOverlay(),

          // Focus indicator
          if (_isFocusing) _buildFocusIndicator(),

          // Quality info overlay
          if (_showQualityInfo) _buildQualityInfo(),

          // Top controls
          _buildTopControls(),

          // Bottom controls
          _buildBottomControls(),

          // Recording indicator
          if (_isRecording) _buildRecordingIndicator(),
        ],
      ),
    );
  }

  /// Build camera preview with TikTok-quality aspect ratio
  Widget _buildCameraPreview() {
    return GestureDetector(
      onTapDown: _onTapToFocus,
      onScaleUpdate: _onScaleUpdate,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: _cameraService.controller != null &&
                _cameraService.controller!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _cameraService.getOptimalAspectRatio(),
                child: CameraPreview(
                  _cameraService.controller!,
                  key: ValueKey(_cameraService.currentLensDirection.toString()),
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Initializing Camera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Build grid overlay for composition
  Widget _buildGridOverlay() {
    return CustomPaint(
      painter: GridPainter(),
      size: Size.infinite,
    );
  }

  /// Build focus indicator
  Widget _buildFocusIndicator() {
    if (_focusPoint == null) return const SizedBox.shrink();

    return Positioned(
      left: _focusPoint!.dx - 30,
      top: _focusPoint!.dy - 30,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(
          child: Icon(
            Icons.center_focus_strong,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Build quality info overlay
  Widget _buildQualityInfo() {
    final qualityInfo = _cameraService.getQualityInfo();
    final pixel6Status = _cameraService.getPixel6QualityStatus();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '📱 Pixel 6 Quality Status',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...pixel6Status.entries.take(6).map((entry) => Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(
                    color: entry.value.toString().contains('YES')
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                )),
            const SizedBox(height: 8),
            Text(
              'Resolution: ${qualityInfo['resolution']}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              'FPS: ${qualityInfo['fps']} | Bitrate: ${qualityInfo['bitrate']}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              'Camera: ${qualityInfo['cameraType']} - ${qualityInfo['qualityLevel']}',
              style: TextStyle(
                color: qualityInfo['cameraType'] == 'Back Camera'
                    ? Colors.blue
                    : Colors.pink,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build top controls
  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),

          // Right side controls
          Row(
            children: [
              // Grid toggle
              IconButton(
                onPressed: _toggleGrid,
                icon: Icon(
                  _showGrid ? Icons.grid_on : Icons.grid_off,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 8),

              // Quality info toggle
              IconButton(
                onPressed: _toggleQualityInfo,
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build bottom controls
  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          IconButton(
            onPressed: _pickFromGallery,
            icon:
                const Icon(Icons.photo_library, color: Colors.white, size: 28),
          ),

          // Record button
          GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            onTapCancel: () => _stopRecording(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.white,
                  width: 4,
                ),
                color: _isRecording
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Switch camera button
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.flip_camera_ios,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  /// Build recording indicator
  Widget _buildRecordingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pause all HomeView videos to prevent audio bleeding
  // _pauseAllHomeViewVideos method removed - now handled by UnifiedVideoControlService
  // ignore: unused_element
  void _pauseAllHomeViewVideos() {
    try {
      log('🔇 TikTokCameraView: Pausing all HomeView videos to prevent audio bleeding');

      // Use GlobalPlaybackCoordinator to pause all videos
      final coordinator = GlobalPlaybackCoordinator();
      coordinator.block(reason: 'camera_view_pause');

      // Also pause through home provider
      final homeNotifier = ref.read(homeProvider.notifier);
      homeNotifier.pauseAllVideos();

      log('✅ TikTokCameraView: All HomeView videos paused successfully');
    } catch (e) {
      log('❌ TikTokCameraView: Error pausing HomeView videos: $e');
    }
  }

  /// Reactivate HomeView when returning from camera
  // _reactivateHomeView method removed - now handled by UnifiedVideoControlService
  // ignore: unused_element
  void _reactivateHomeView() {
    try {
      log('🔄 TikTokCameraView: Reactivating HomeView for seamless return');

      // Use GlobalPlaybackCoordinator to resume videos
      final coordinator = GlobalPlaybackCoordinator();
      coordinator.unblock();

      // Also resume through home provider
      final homeNotifier = ref.read(homeProvider.notifier);
      homeNotifier.resumeCurrentVideo();

      log('✅ TikTokCameraView: HomeView reactivated successfully');
    } catch (e) {
      log('❌ TikTokCameraView: Error reactivating HomeView: $e');
    }
  }
}

/// Custom painter for grid overlay
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
