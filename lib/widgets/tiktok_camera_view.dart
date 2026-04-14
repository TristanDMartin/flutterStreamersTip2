import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tiktok_camera_service.dart';
import '../services/global_playback_manager.dart';
import '../providers/home_provider.dart';
import 'video_recording_preview.dart';
import 'video_publishing_screen.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFocusing = false;
  bool _showGrid = false;
  bool _showQualityInfo = false;
  Offset? _focusPoint;
  double _currentZoom = 1.0; // Will be updated to minZoom after initialization
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔊 AUDIO FIX: Immediately pause all videos to prevent audio bleeding
    // Block playback first to prevent any new videos from starting
    GlobalPlaybackManager.instance.block(reason: 'cameraViewOpened');
    // Also explicitly pause all videos for immediate effect
    GlobalPlaybackManager.instance.pauseAll();

    // 🔧 FIXED: Delay provider modification until after widget tree is built
    // Cannot modify providers during initState - use post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final homeNotifier = ref.read(homeProvider.notifier);
        homeNotifier.pauseAllVideos();
        log('🔇 TikTokCameraView: Paused all HomeView videos via provider');
      } catch (e) {
        log('⚠️ TikTokCameraView: Could not pause via home provider: $e');
      }
    });

    // 🔒 FIXED: Lock screen orientation to portrait for camera
    // This prevents preview from rotating and ensures consistent 9:16 video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _cameraService.dispose();

    // 🔊 AUDIO FIX: Unblock playback when leaving camera
    GlobalPlaybackManager.instance.unblock();

    // 🔒 FIXED: Unlock screen orientation when leaving camera
    // Allow all orientations to be used in other parts of the app
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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

      // 🔍 FIXED: Set zoom to minimum level for widest field of view
      // This prevents camera from starting zoomed in and ensures full sensor coverage
      if (_cameraService.controller != null &&
          _cameraService.controller!.value.isInitialized) {
        try {
          // Try setting to 0.1 first - camera will clamp to actual minimum automatically
          await _cameraService.controller!.setZoomLevel(0.1);
          _currentZoom = 0.1; // Camera will clamp this to the actual minimum
          log('🔍 TikTokCameraView: Zoom set to minimum (attempted 0.1, camera will clamp)');
        } catch (e) {
          // Fallback to 1.0
          try {
            await _cameraService.controller!.setZoomLevel(1.0);
            _currentZoom = 1.0;
            log('🔍 TikTokCameraView: Zoom set to 1.0 (fallback)');
          } catch (e2) {
            log('⚠️ TikTokCameraView: Could not set zoom: $e2');
          }
        }
      }

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

      if (mounted) {
        await _openPreviewAndMaybePublish(File(videoFile.path));
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
        await _openPreviewAndMaybePublish(File(video.path));
      }
    } catch (e) {
      log('❌ Error picking video from gallery: $e');
      _showErrorDialog('Error selecting video: ${e.toString()}');
    }
  }

  Future<void> _openPreviewAndMaybePublish(File videoFile) async {
    final previewAction =
        await Navigator.of(context).push<VideoRecordingPreviewAction>(
      MaterialPageRoute(
        builder: (context) => VideoRecordingPreview(
          videoFile: videoFile,
        ),
      ),
    );

    if (!mounted || previewAction != VideoRecordingPreviewAction.useVideo) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPublishingScreen(
          videoFile: videoFile,
          caption: '',
          hashtags: const [],
          onPublish: () {
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (!mounted) return;
    log('🎬 TikTokCameraView: Returned from publishing flow');
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
          // Camera preview with proper aspect ratio - fills entire screen
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

  /// Build camera preview with native camera field of view (no cropping)
  ///
  /// FIXED:
  /// - Uses camera's native aspect ratio (no forced cropping)
  /// - Uses BoxFit.contain to show full FOV without zoom effect
  /// - Front camera is mirrored horizontally for natural selfie experience
  /// - Never crops the preview (shows full sensor width)
  Widget _buildCameraPreview() {
    final isFrontCamera =
        _cameraService.currentLensDirection == CameraLensDirection.front;

    final controller = _cameraService.controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.previewSize == null) {
      return const Positioned.fill(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // The plugin reports previewSize in LANDSCAPE orientation (width > height)
    // For a portrait UI, we need to swap them to get the correct portrait aspect ratio
    final Size ps = controller.value.previewSize!;
    final double cameraAspectPortrait =
        ps.height / ps.width; // e.g., 16/9 ≈ 1.778 or 4/3 ≈ 1.333

    log('📐 Camera preview size (landscape): ${ps.width}x${ps.height}');
    log('📐 Camera aspect ratio (portrait): ${cameraAspectPortrait.toStringAsFixed(3)}');

    // Calculate what aspect ratio this is (16:9 = 1.778, 4:3 = 1.333, etc.)
    String aspectRatioName = 'Unknown';
    bool is16by9 = false;
    if ((cameraAspectPortrait - 1.778).abs() < 0.02) {
      aspectRatioName = '16:9';
      is16by9 = true;
    } else if ((cameraAspectPortrait - 1.333).abs() < 0.02) {
      aspectRatioName = '4:3';
    } else if ((cameraAspectPortrait - 1.5).abs() < 0.02) {
      aspectRatioName = '3:2';
    } else if ((cameraAspectPortrait - 2.0).abs() < 0.02) {
      aspectRatioName = '2:1';
    }
    log('📐 Aspect ratio type: $aspectRatioName (${cameraAspectPortrait.toStringAsFixed(3)})');

    // Target 16:9 aspect ratio for portrait (9:16 = 0.5625, but in portrait it's height/width)
    // 16:9 in landscape becomes 9:16 in portrait = height/width = 9/16 = 0.5625
    // But we're calculating portrait aspect as height/width, so 16:9 = 16/9 ≈ 1.778
    const double target16by9Portrait = 16.0 / 9.0; // ≈ 1.778

    // If we have 16:9 natively, use it and fill screen with BoxFit.cover
    // If we don't have 16:9, crop to 16:9 with BoxFit.cover (native camera behavior)
    final double displayAspectRatio =
        is16by9 ? cameraAspectPortrait : target16by9Portrait;

    log('📐 Display aspect ratio: ${displayAspectRatio.toStringAsFixed(3)} (${is16by9 ? "native 16:9" : "cropped to 16:9"})');

    // Build camera preview
    // If native 16:9, use camera's aspect ratio
    // If not 16:9, crop to 16:9 to match native camera behavior
    final cameraPreview = AspectRatio(
      aspectRatio: displayAspectRatio,
      child: Transform(
        alignment: Alignment.center,
        // Mirror front camera horizontally for natural selfie experience
        transform:
            isFrontCamera ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
        child: ClipRect(
          // Clip to 16:9 if camera doesn't provide it natively
          child: CameraPreview(
            controller,
            key: ValueKey(_cameraService.currentLensDirection.toString()),
          ),
        ),
      ),
    );

    // Use BoxFit.cover to fill screen (native camera behavior)
    // This will crop to 16:9 if needed, matching how native camera apps work
    // If camera is already 16:9, no cropping happens - perfect match
    return Positioned.fill(
      child: GestureDetector(
        onTapDown: _onTapToFocus,
        onScaleUpdate: _onScaleUpdate,
        child: ColoredBox(
          // Clean black background (shouldn't show if 16:9 matches screen)
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit
                .cover, // Fill screen - crop to 16:9 if needed (native camera behavior)
            alignment: Alignment.center,
            child: SizedBox(
              // Use 16:9 aspect ratio for display (portrait orientation)
              // Portrait 16:9: height/width = 16/9, so width = height * 9/16
              // In portrait: height = ps.width (landscape width), width = ps.height (landscape height)
              // If native 16:9: width = ps.height (already correct)
              // If not 16:9: crop to width = ps.width * 9/16 (crop width, keep full height)
              width: is16by9
                  ? ps.height // Native 16:9 - already correct width
                  : ps.width * (9.0 / 16.0), // Crop to 16:9 width
              height: ps
                  .width, // Use full height from camera (portrait orientation)
              child: cameraPreview,
            ),
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
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          _buildGlassIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Capture something worth posting',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildModeChip(
                _showGrid ? 'Grid on' : 'Grid off',
                icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                onTap: _toggleGrid,
              ),
              const SizedBox(width: 8),
              _buildGlassIconButton(
                icon: Icons.info_outline_rounded,
                onTap: _toggleQualityInfo,
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
      bottom: MediaQuery.of(context).padding.bottom + 18,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusChip(
                _isRecording ? 'Recording' : 'Ready',
                color: _isRecording
                    ? const Color(0xFFFF5F57)
                    : const Color(0xFF1FBF75),
              ),
              const Spacer(),
              Text(
                _isRecording ? _formatDuration(_recordingDuration) : 'Hold to record',
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
                    onTap: _pickFromGallery,
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
                            Icons.photo_library_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Gallery',
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
                GestureDetector(
                  onTapDown: (_) => _startRecording(),
                  onTapUp: (_) => _stopRecording(),
                  onTapCancel: () => _stopRecording(),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording
                            ? const Color(0xFFFF5F57)
                            : Colors.white,
                        width: 4,
                      ),
                      color: _isRecording
                          ? const Color(0xFFFF5F57).withValues(alpha: 0.22)
                          : Colors.transparent,
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF5F57)
                                    .withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: _isRecording ? 34 : 68,
                        height: _isRecording ? 34 : 68,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? const Color(0xFFFF5F57)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(
                            _isRecording ? 12 : 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _switchCamera,
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
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Flip',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build recording indicator
  Widget _buildRecordingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 84,
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

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildModeChip(
    String label, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == const Color(0xFF1FBF75)
              ? const Color(0xFF7FF0B7)
              : const Color(0xFFFFB2AD),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Pause all HomeView videos to prevent audio bleeding
  // ignore: unused_element
  void _pauseAllHomeViewVideos() {
    try {
      log('🔇 TikTokCameraView: Pausing all HomeView videos to prevent audio bleeding');

      // 🔊 AUDIO FIX: Use GlobalPlaybackManager to block playback
      GlobalPlaybackManager.instance.block(reason: 'camera_view');

      // Also pause through home provider for compatibility
      final homeNotifier = ref.read(homeProvider.notifier);
      homeNotifier.pauseAllVideos();

      log('✅ TikTokCameraView: All HomeView videos paused successfully');
    } catch (e) {
      log('❌ TikTokCameraView: Error pausing HomeView videos: $e');
    }
  }

  /// Reactivate HomeView when returning from camera
  // ignore: unused_element
  void _reactivateHomeView() {
    try {
      log('🔄 TikTokCameraView: Reactivating HomeView for seamless return');

      // 🔊 AUDIO FIX: Use GlobalPlaybackManager to unblock playback
      GlobalPlaybackManager.instance.unblock();

      // Also resume through home provider for compatibility
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
