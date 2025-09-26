import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'video_recording_preview.dart';
import 'video_edit_view.dart';
import '../services/enhanced_error_handling_service.dart';
import 'capture_button.dart';


enum NavigationState {
  none,
  recordingPreview,
  editDescription,
  editVideo,
  share,
}

enum VideoQuality {
  low,
  medium,
  high,
  ultra,
}

enum CameraMode {
  video,
  photo,
  slowMotion,
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  final List<File> _recordedClips = [];
  NavigationState _navigationState = NavigationState.none;
  File? _currentVideoFile;
  VideoPlayerController? _previewController;
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  // _recordingProgress removed - now handled by CaptureButton
  late AnimationController _pulseController;
  late AnimationController _recordButtonController;
  
  // New camera settings - optimized for performance
  VideoQuality _videoQuality = VideoQuality.low; // Start with lowest quality
  bool _isStabilizationEnabled = false; // Disabled for performance
  bool _isFlashEnabled = false;
  double _exposure = 0.0;
  
  // New UI state variables
  // _isFlashOn removed - flash button no longer available
  // Filter-related variables removed - no longer needed
  bool _showGrid = false;
  bool _showTimer = false;
  int _timerValue = 0;
  File? _lastCapturedImage;
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _recordingTimer;
  
  // Focus and zoom variables
  Offset? _focusPoint;
  double _currentZoom = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 4.0;
  bool _isFocusing = false;
  late AnimationController _focusAnimationController;
  final EnhancedErrorHandlingService _errorHandler = EnhancedErrorHandlingService();
  
  // Menu button debounce
  bool _isMenuButtonPressed = false;
  Timer? _debounceTimer;
  
  // Dynamic status bar
  Timer? _statusBarTimer;
  String _currentTime = '';
  String _batteryLevel = '';
  String _connectivityStatus = '';
  bool _isLowBattery = false;
  
  // Performance monitoring
  Timer? _performanceTimer;
  int _frameDropCount = 0;
  double _averageFPS = 0.0;
  int _memoryUsage = 0;
  bool _isPerformanceGood = true;
  List<double> _fpsHistory = [];
  
  // Error recovery
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;
  bool _isRecovering = false;
  
  void _resetMenuDebounce() {
    _debounceTimer?.cancel();
    _isMenuButtonPressed = false;
    debugPrint('Menu debounce reset');
  }
  
  void _initializeStatusBar() {
    _updateStatusBar();
    // Update status bar every 5 seconds to reduce overhead
    _statusBarTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateStatusBar();
    });
  }
  
  void _updateStatusBar() {
    if (!mounted) return;
    
    setState(() {
      // Update time
      final now = DateTime.now();
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Update connectivity (simplified for demo)
      _connectivityStatus = 'WiFi';
      
      // Update battery level (simplified for demo)
      _batteryLevel = '85%';
      _isLowBattery = false; // In real app, check actual battery level
    });
  }
  
  void _initializePerformanceMonitoring() {
    // Monitor performance every 10 seconds to reduce overhead
    _performanceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _monitorPerformance();
    });
  }
  
  void _monitorPerformance() {
    if (!mounted) return;
    
    // Simulate performance monitoring (in real app, use actual metrics)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    
    setState(() {
      // Simulate FPS monitoring
      final currentFPS = 25 + (random % 10); // 25-35 FPS
      _fpsHistory.add(currentFPS.toDouble());
      
      // Keep only last 10 measurements
      if (_fpsHistory.length > 10) {
        _fpsHistory.removeAt(0);
      }
      
      // Calculate average FPS
      _averageFPS = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
      
      // Simulate frame drops
      if (currentFPS < 28) {
        _frameDropCount++;
      }
      
      // Simulate memory usage
      _memoryUsage = 150 + (random % 50); // 150-200 MB
      
      // Determine if performance is good
      _isPerformanceGood = _averageFPS > 26 && _frameDropCount < 5;
      
      // Log performance issues
      if (!_isPerformanceGood) {
        debugPrint('⚠️ Performance Alert: FPS: ${_averageFPS.toStringAsFixed(1)}, Frame Drops: $_frameDropCount, Memory: ${_memoryUsage}MB');
      }
    });
  }
  
  
  // Error recovery methods
  Future<void> _retryCameraInitialization() async {
    if (_retryCount >= _maxRetries) {
      debugPrint('❌ Max retries reached. Showing error dialog.');
      _showRecoveryFailedDialog();
      return;
    }
    
    if (_isRecovering) return;
    
    _isRecovering = true;
    _retryCount++;
    
    debugPrint('🔄 Retrying camera initialization (attempt $_retryCount/$_maxRetries)');
    
    // Exponential backoff: wait longer between retries
    final delay = Duration(seconds: _retryCount * 2);
    
    _retryTimer = Timer(delay, () async {
      try {
        // Dispose current controller
        await _cameraController?.dispose();
        _cameraController = null;
        
        // Wait a bit more
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Retry initialization
        await _initializeCamera();
        
        if (_isInitialized) {
          debugPrint('✅ Camera initialization recovered successfully');
          _retryCount = 0; // Reset retry count on success
        } else {
          // Try again if still not initialized
          await _retryCameraInitialization();
        }
      } catch (e) {
        debugPrint('❌ Retry failed: $e');
        await _retryCameraInitialization();
      } finally {
        _isRecovering = false;
      }
    });
  }
  
  void _showRecoveryFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Camera Error',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Unable to initialize camera after multiple attempts. Please restart the app or check your device settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Exit camera view
            },
            child: const Text(
              'Exit Camera',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryCount = 0; // Reset retry count
              _checkPermissionsAndInitialize();
            },
            child: const Text(
              'Try Again',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleCameraError(String operation, dynamic error) async {
    debugPrint('❌ Camera error in $operation: $error');
    
    await _errorHandler.handleCameraError(
      operation: operation,
      error: error,
      context: {
        'retry_count': _retryCount,
        'is_recovering': _isRecovering,
        'performance_good': _isPerformanceGood,
      },
    );
    
    // Attempt recovery for critical operations
    if (operation == 'camera_initialization' && _retryCount < _maxRetries) {
      await _retryCameraInitialization();
    } else if (operation == 'start_recording' || operation == 'stop_recording') {
      // Show user-friendly error for recording issues
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording error: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                if (operation == 'start_recording') {
                  _startRecording();
                } else {
                  _stopRecording();
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _recordButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _initializeStatusBar();
    _initializePerformanceMonitoring();
    _checkPermissionsAndInitialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _previewController?.dispose();
    _pulseController.dispose();
    _recordButtonController.dispose();
    _focusAnimationController.dispose();
    _recordingTimer?.cancel();
    _statusBarTimer?.cancel();
    _performanceTimer?.cancel();
    _retryTimer?.cancel();
    _resetMenuDebounce();
    super.dispose();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      
      if (cameraStatus.isGranted && micStatus.isGranted) {
        // Permissions already granted, initialize camera immediately
        await _initializeCamera();
      } else {
        // Request permissions
        final cameraResult = await Permission.camera.request();
        final micResult = await Permission.microphone.request();
        
        if (cameraResult.isGranted && micResult.isGranted) {
          await _initializeCamera();
        } else {
          // Handle permission denied
          await _errorHandler.handleCameraError(
            operation: 'permission_check',
            error: 'Camera or microphone permission denied',
            context: {
              'camera_status': cameraStatus.toString(),
              'microphone_status': micStatus.toString(),
            },
          );
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'permission_check',
        error: e,
        context: {'step': 'check_permissions'},
      );
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        // Use quality-based resolution
        final resolution = _getResolutionPreset(_videoQuality);
        
        _cameraController = CameraController(
          _cameras![_isFrontCamera ? 1 : 0],
          resolution,
          enableAudio: true,
          imageFormatGroup: ImageFormatGroup.yuv420, // Optimized format
        );
        
        await _cameraController!.initialize();
        
        // Apply camera settings
        await _applyCameraSettings();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } else {
        await _errorHandler.handleCameraError(
          operation: 'camera_initialization',
          error: 'No cameras available on this device',
          context: {'cameras_found': _cameras?.length ?? 0},
        );
      }
    } catch (e) {
      await _handleCameraError('camera_initialization', e);
    }
  }
  
  ResolutionPreset _getResolutionPreset(VideoQuality quality) {
    // Force low resolution for performance
    switch (quality) {
      case VideoQuality.low:
      case VideoQuality.medium:
      case VideoQuality.high:
      case VideoQuality.ultra:
        return ResolutionPreset.low; // Force low resolution for all modes
    }
  }
  
  Future<void> _applyCameraSettings() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    try {
      // Apply stabilization if supported
      if (_isStabilizationEnabled) {
        await _cameraController!.setFocusMode(FocusMode.auto);
      }
      
      // Apply flash setting
      await _cameraController!.setFlashMode(
        _isFlashEnabled ? FlashMode.torch : FlashMode.off,
      );
      
      // Apply exposure
      await _cameraController!.setExposureOffset(_exposure);
      
      // Apply focus
      await _cameraController!.setFocusMode(FocusMode.auto);
      
    } catch (e) {
      debugPrint('Error applying camera settings: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        // _recordingProgress removed - now handled by CaptureButton
      });

      // Start recording timer
      _startRecordingTimer();
    } catch (e) {
      await _handleCameraError('start_recording', e);
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedClips.add(File(videoFile.path));
        _currentVideoFile = File(videoFile.path);
        _navigationState = NavigationState.recordingPreview;
      });

      // Initialize preview player
      _initializePreviewPlayer();
    } catch (e) {
      await _handleCameraError('stop_recording', e);
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && mounted) {
        setState(() {
          // _recordingProgress removed - now handled by CaptureButton
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _initializePreviewPlayer() async {
    if (_currentVideoFile != null) {
      _previewController = VideoPlayerController.file(_currentVideoFile!);
      await _previewController!.initialize();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _initializeCamera();
  }

  void _onBack() {
    setState(() {
      _navigationState = NavigationState.none;
      _currentVideoFile = null;
      _previewController?.dispose();
      _previewController = null;
    });
  }

  void _onNext() {
    // Navigate to video editing screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoEditView(
          videoFile: _currentVideoFile!,
          onCancel: () => Navigator.of(context).pop(),
          onNext: _onSaveVideo,
        ),
      ),
    );
  }

  void _onSaveVideo() {
    // This method is called after successful video processing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video processed successfully! 🎉'),
        backgroundColor: Color(0xFF9248d2),
        duration: Duration(seconds: 3),
      ),
    );
    
    // Reset camera state
    setState(() {
      _navigationState = NavigationState.none;
      _currentVideoFile = null;
      _recordedClips.clear();
    });
    
    // Navigate back to profile or home
    Navigator.of(context).pop();
  }

  // New UI methods
  // _toggleFlash method removed - flash button no longer available

  // _toggleFilters method removed - no longer needed

  void _toggleGrid() {
    if (mounted) {
      setState(() {
        _showGrid = !_showGrid;
      });
    }
  }

  void _toggleTimer() {
    if (mounted) {
      setState(() {
        _showTimer = !_showTimer;
        if (!_showTimer) _timerValue = 0;
      });
    }
  }

  void _setTimer(int seconds) {
    if (mounted) {
      setState(() {
        _timerValue = seconds;
      });
    }
  }
  
  // New camera settings methods
  void _toggleFlash() {
    if (mounted) {
      setState(() {
        _isFlashEnabled = !_isFlashEnabled;
      });
      _applyCameraSettings();
    }
  }
  
  void _toggleStabilization() {
    if (mounted) {
      setState(() {
        _isStabilizationEnabled = !_isStabilizationEnabled;
      });
      _applyCameraSettings();
    }
  }
  
  String _getQualityDisplayName(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.low:
        return 'Low (480p)';
      case VideoQuality.medium:
        return 'Medium (720p)';
      case VideoQuality.high:
        return 'High (1080p)';
      case VideoQuality.ultra:
        return 'Ultra (4K)';
    }
  }
  
  void _showQualityOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Video Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...VideoQuality.values.map((quality) => _buildQualityOption(quality)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQualityOption(VideoQuality quality) {
    final isSelected = _videoQuality == quality;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.7),
      ),
      title: Text(
        _getQualityDisplayName(quality),
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _videoQuality = quality;
        });
        // Reinitialize camera with new quality
        _initializeCamera();
      },
    );
  }

  // Focus and zoom methods
  void _onTapToFocus(TapDownDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset localPoint = renderBox.globalToLocal(details.globalPosition);
      
      // Calculate focus point relative to camera preview
      final double x = localPoint.dx / renderBox.size.width;
      final double y = localPoint.dy / renderBox.size.height;
      
      setState(() {
        _focusPoint = localPoint;
        _isFocusing = true;
      });

      // Start focus animation
      _focusAnimationController.forward().then((_) {
        _focusAnimationController.reverse();
      });

      // Set focus point on camera
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setFocusMode(FocusMode.auto);

      // Hide focus indicator after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isFocusing = false;
          });
        }
      });

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'tap_to_focus',
        error: e,
        context: {
          'camera_initialized': _cameraController?.value.isInitialized ?? false,
          'focus_point': details.globalPosition.toString(),
        },
      );
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final double newZoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
      
      setState(() {
        _currentZoom = newZoom;
      });

      await _cameraController!.setZoomLevel(newZoom);
    } catch (e) {
      await _errorHandler.handleCameraError(
        operation: 'zoom_update',
        error: e,
        context: {
          'camera_initialized': _cameraController?.value.isInitialized ?? false,
          'current_zoom': _currentZoom,
          'new_zoom': (_currentZoom * details.scale).clamp(_minZoom, _maxZoom),
        },
      );
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Optional: Add momentum or snap to zoom levels
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _lastCapturedImage = File(image.path);
        });
        // Navigate to gallery or show image
      }
    } catch (e) {
      debugPrint('Error opening gallery: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || !mounted) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _lastCapturedImage = File(photo.path);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      // Show error to user if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSettingsMenu() {
    // Prevent multiple rapid taps with a timeout
    if (_isMenuButtonPressed) {
      debugPrint('Menu button pressed but debounced - ignoring');
      return;
    }
    
    debugPrint('Opening settings menu');
    _isMenuButtonPressed = true;
    
    // Auto-reset debounce after 2 seconds as a safety measure
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      debugPrint('Auto-resetting menu debounce flag');
      _resetMenuDebounce();
    });
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingsItem(
              icon: Icons.grid_on,
              title: 'Grid Lines',
              subtitle: _showGrid ? 'Hide composition grid' : 'Show composition grid',
              onTap: () => _handleSettingTap(() => _toggleGrid()),
            ),
            _buildSettingsItem(
              icon: Icons.timer,
              title: 'Timer',
              subtitle: 'Set countdown timer',
              onTap: () => _handleSettingTap(() => _showTimerOptions()),
            ),
            _buildSettingsItem(
              icon: Icons.flash_on,
              title: 'Flash',
              subtitle: _isFlashEnabled ? 'Flash ON' : 'Flash OFF',
              onTap: () => _handleSettingTap(() => _toggleFlash()),
            ),
            _buildSettingsItem(
              icon: Icons.video_settings,
              title: 'Quality',
              subtitle: _getQualityDisplayName(_videoQuality),
              onTap: () => _handleSettingTap(() => _showQualityOptions()),
            ),
            _buildSettingsItem(
              icon: Icons.video_stable,
              title: 'Stabilization',
              subtitle: _isStabilizationEnabled ? 'ON' : 'OFF',
              onTap: () => _handleSettingTap(() => _toggleStabilization()),
            ),
            _buildSettingsItem(
              icon: Icons.photo_camera,
              title: 'Take Photo',
              subtitle: 'Capture a photo',
              onTap: () => _handleSettingTap(() => _capturePhoto()),
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleSettingTap(VoidCallback action) {
    Navigator.pop(context);
    _resetMenuDebounce();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        action();
      }
    });
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 14),
      ),
      onTap: onTap,
    );
  }

  void _showTimerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Timer Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimerOption(0, 'Off'),
                _buildTimerOption(3, '3s'),
                _buildTimerOption(5, '5s'),
                _buildTimerOption(10, '10s'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(int seconds, String label) {
    final isSelected = _timerValue == seconds;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _setTimer(seconds);
        if (seconds > 0) {
          _toggleTimer();
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Camera Access Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please enable camera and microphone access in Settings to use this feature.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle navigation states
    if (_navigationState == NavigationState.recordingPreview && _currentVideoFile != null) {
      return VideoRecordingPreview(
        videoFile: _currentVideoFile!,
        onRetake: _onBack,
        onUseVideo: _onNext,
      );
    }
    
    if (_navigationState == NavigationState.editDescription && _currentVideoFile != null) {
      return VideoEditView(
        videoFile: _currentVideoFile!,
        onCancel: _onBack,
        onNext: _onSaveVideo,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          _buildCameraPreview(),

          // Status Bar (Time, Signal, Battery)
          _buildStatusBar(),

          // Top Controls (Close, Flash)
          _buildTopControls(),

          // Right Side Controls (Filters, Settings)
          _buildRightControls(),

          // Bottom Controls (Gallery, Record, Switch Camera)
          _buildBottomControls(),

          // Recording Progress - Removed (now handled by CaptureButton)

          // Mode Selector

          // Grid Lines
          if (_showGrid) _buildGridLines(),

          // Filters Overlay - removed (no longer needed)

          // Timer Overlay
          if (_showTimer && _timerValue > 0) _buildTimerOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapToFocus,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          // Ultra-optimized camera preview for performance
          RepaintBoundary(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 320, // Fixed small size for performance
                  height: 240, // Fixed small size for performance
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
          // Focus indicator
          if (_focusPoint != null && _isFocusing)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: AnimatedBuilder(
                animation: _focusAnimationController,
                builder: (context, child) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha:0.8),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      margin: EdgeInsets.all(8 + (_focusAnimationController.value * 4)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha:0.6),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Zoom level indicator
          if (_currentZoom > 1.0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // Performance indicator (only show when performance is poor)
          if (!_isPerformanceGood)
            Positioned(
              top: MediaQuery.of(context).padding.top + 160,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_averageFPS.toStringAsFixed(1)} FPS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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


  Widget _buildStatusBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dynamic time display
          Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Dynamic status indicators
          Row(
            children: [
              // Connectivity icon
              Icon(
                _connectivityStatus == 'WiFi' ? Icons.wifi : Icons.signal_cellular_4_bar,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              // Battery icon with level
              Icon(
                _isLowBattery ? Icons.battery_alert : Icons.battery_full,
                color: _isLowBattery ? Colors.red : Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              // Battery percentage
              Text(
                _batteryLevel,
                style: TextStyle(
                  color: _isLowBattery ? Colors.red : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // Menu button - moved from right controls
          Semantics(
            label: 'Menu, button',
            child: GestureDetector(
              onTap: _showSettingsMenu,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightControls() {
    // Right controls removed - menu button moved to top controls
    return const SizedBox.shrink();
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery Thumbnail
          GestureDetector(
            onTap: _openGallery,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _lastCapturedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        _lastCapturedImage!,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                      ),
                    )
                  : const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          // Record Button - New CaptureButton Widget
          GestureDetector(
            onLongPress: _capturePhoto, // Long press for photo capture
            child: CaptureButton(
              size: 80,
              ringWidth: 8,
              duration: const Duration(seconds: 60), // 60 second max recording
              isRecording: _isRecording, // Pass recording state
              onStart: _startRecording,
              onFinish: _stopRecording,
            ),
          ),
          // Switch Camera
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // _buildRecordingProgress() method removed - recording progress now handled by CaptureButton


  Widget _buildGridLines() {
    return Positioned.fill(
      child: CustomPaint(
        painter: GridPainter(),
      ),
    );
  }

  // _buildFiltersOverlay method removed - no longer needed

  Widget _buildTimerOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha:0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Timer: ${_timerValue}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for grid lines
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha:0.3)
      ..strokeWidth = 1.0;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}